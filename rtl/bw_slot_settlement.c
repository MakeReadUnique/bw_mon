/* Kernel scheduling only: all monitor state and arithmetic remain in SV. */
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include "svdpi.h"
#include "vpi_user.h"

#ifdef __cplusplus
extern "C" {
#endif
extern void bw_slot_settlement_arrived(void);
extern void bw_native_reset_seen(svBit prepare, svLogic previous, svLogic current);
extern void bw_native_point_edge(void);
extern int bw_native_point_audit(void);
extern void bw_native_scheduler_failed(void);

typedef struct point_watch {
    svScope scope;
    vpiHandle object, callback;
    s_vpi_time time;
    s_vpi_value value;
    svLogic previous;
    struct point_watch *next;
} point_watch;
static point_watch *point_watches;

static PLI_INT32 point_clock_changed(p_cb_data callback)
{
    point_watch *watch = (point_watch *)callback->user_data;
    svLogic old = watch->previous;
    int raw = callback->value->value.scalar;
    svLogic value = raw == vpi0 ? sv_0 : raw == vpi1 ? sv_1 : raw == vpiZ ? sv_z : sv_x;
    svScope previous;
    watch->previous = value;
    /* IEEE four-state posedge: 0->1/X/Z, X/Z->1. */
    if ((old == sv_0 && value != sv_0) ||
        ((old == sv_x || old == sv_z) && value == sv_1)) {
        previous = svSetScope(watch->scope);
        bw_native_point_edge();
        if (previous) svSetScope(previous);
    }
    return 0;
}

void *bw_native_watch_point_clock(const char *scope_path)
{
    point_watch *watch;
    s_cb_data callback;
    s_vpi_value value;
    size_t length = strlen(scope_path);
    char *path;
    if (length > SIZE_MAX - 5) return NULL;
    watch = (point_watch *)calloc(1, sizeof(*watch));
    path = (char *)malloc(length + 5);
    if (!watch || !path) { free(watch); free(path); return NULL; }
    memcpy(path, scope_path, length); memcpy(path + length, ".clk", 5);
    watch->scope = svGetScopeFromName(scope_path);
    watch->object = vpi_handle_by_name((PLI_BYTE8 *)path, NULL);
    free(path);
    if (!watch->scope || !watch->object) { free(watch); return NULL; }
    memset(&value, 0, sizeof(value)); value.format = vpiScalarVal;
    vpi_get_value(watch->object, &value);
    watch->previous = value.value.scalar == vpi0 ? sv_0 : value.value.scalar == vpi1 ? sv_1 :
                      value.value.scalar == vpiZ ? sv_z : sv_x;
    watch->time.type = vpiSimTime; watch->value.format = vpiScalarVal;
    memset(&callback, 0, sizeof(callback));
    callback.reason = cbValueChange; callback.cb_rtn = point_clock_changed;
    callback.obj = watch->object; callback.time = &watch->time; callback.value = &watch->value;
    callback.user_data = (PLI_BYTE8 *)watch;
    watch->callback = vpi_register_cb(&callback);
    if (!watch->callback) { free(watch); return NULL; }
    watch->next = point_watches; point_watches = watch;
    return watch;
}

typedef struct reset_watch {
    svScope scope;
    vpiHandle object, callback;
    s_vpi_value value;
    s_vpi_time time;
    svLogic previous;
    int dirty;
    struct reset_watch *next, *next_dirty;
} reset_watch;
static reset_watch *reset_watches, *dirty_resets;
static unsigned long long reset_watch_count;
static int reset_watch_error;
#ifdef BW_MON_TEST_FAULTS
static int fail_next_reset_allocation;
static int fail_next_slot_registration;
void bw_native_fail_reset_allocation(void) { fail_next_reset_allocation = 1; }
void bw_native_fail_slot_registration(void) { fail_next_slot_registration = 1; }
#endif

static svLogic scalar_logic(int value)
{
    return value == vpi0 ? sv_0 : value == vpi1 ? sv_1 : value == vpiZ ? sv_z : sv_x;
}

static void mark_reset_dirty(reset_watch *watch)
{
    if (!watch->dirty) {
        watch->dirty = 1;
        watch->next_dirty = dirty_resets;
        dirty_resets = watch;
    }
}

static PLI_INT32 reset_changed(p_cb_data callback)
{
    reset_watch *watch = (reset_watch *)callback->user_data;
    svLogic previous = watch->previous;
    svLogic current = scalar_logic(callback->value->value.scalar);
    svScope previous_scope;
    watch->previous = current;
    mark_reset_dirty(watch);
    previous_scope = svSetScope(watch->scope);
    bw_native_reset_seen(0, previous, current);
    if (previous_scope) svSetScope(previous_scope);
    return 0;
}

static PLI_INT32 release_reset_watches(p_cb_data callback)
{
    reset_watch *watch;
    point_watch *point;
    (void)callback;
    dirty_resets = NULL;
    while (reset_watches) {
        watch = reset_watches;
        reset_watches = watch->next;
        vpi_remove_cb(watch->callback);
        free(watch);
    }
    reset_watch_count = 0;
    while (point_watches) {
        point = point_watches; point_watches = point->next;
        vpi_remove_cb(point->callback); free(point);
    }
    return 0;
}

void *bw_native_watch_reset(const char *scope_path, const char *signal_name)
{
    reset_watch *watch;
    s_cb_data callback;
    s_vpi_value value;
    size_t scope_length = strlen(scope_path), signal_length = strlen(signal_name);
    char *path;
    reset_watch_error = 0;
#ifdef BW_MON_TEST_FAULTS
    if (fail_next_reset_allocation) {
        fail_next_reset_allocation = 0; reset_watch_error = 1; return NULL;
    }
#endif
    if (signal_length > SIZE_MAX - 2 || scope_length > SIZE_MAX - signal_length - 2 ||
        reset_watch_count == UINT64_MAX) {
        reset_watch_error = 1;
        return NULL;
    }
    path = (char *)malloc(scope_length + signal_length + 2);
    watch = (reset_watch *)calloc(1, sizeof(reset_watch));
    if (!path || !watch) {
        free(path); free(watch); reset_watch_error = 1; return NULL;
    }
    memcpy(path, scope_path, scope_length);
    path[scope_length] = '.';
    memcpy(path + scope_length + 1, signal_name, signal_length + 1);
    watch->scope = svGetScopeFromName(scope_path);
    watch->object = vpi_handle_by_name((PLI_BYTE8 *)path, NULL);
    free(path);
    if (!watch->scope || !watch->object) { free(watch); return NULL; }
    memset(&value, 0, sizeof(value));
    value.format = vpiScalarVal;
    vpi_get_value(watch->object, &value);
    watch->previous = scalar_logic(value.value.scalar);
    watch->value.format = vpiScalarVal;
    watch->time.type = vpiSimTime;
    memset(&callback, 0, sizeof(callback));
    callback.reason = cbValueChange;
    callback.cb_rtn = reset_changed;
    callback.obj = watch->object;
    callback.time = &watch->time;
    callback.value = &watch->value;
    callback.user_data = (PLI_BYTE8 *)watch;
    watch->callback = vpi_register_cb(&callback);
    if (!watch->callback) { free(watch); return NULL; }
    if (reset_watch_count == 0) {
        memset(&callback, 0, sizeof(callback));
        callback.reason = cbEndOfSimulation;
        callback.cb_rtn = release_reset_watches;
        if (!vpi_register_cb(&callback)) {
            vpi_remove_cb(watch->callback); free(watch); return NULL;
        }
    }
    watch->next = reset_watches;
    reset_watches = watch;
    reset_watch_count++;
    return watch;
}

int bw_native_reset_watch_error(void) { return reset_watch_error; }
unsigned long long bw_native_reset_watch_count(void) { return reset_watch_count; }

void bw_native_reset_snapshot(void *handle)
{
    reset_watch *watch = (reset_watch *)handle;
    svScope previous;
    s_vpi_value value;
    if (!watch) return;
    memset(&value, 0, sizeof(value)); value.format = vpiScalarVal;
    vpi_get_value(watch->object, &value);
    watch->previous = scalar_logic(value.value.scalar);
    mark_reset_dirty(watch);
    previous = svSetScope(watch->scope);
    bw_native_reset_seen(0, watch->previous, watch->previous);
    if (previous) svSetScope(previous);
}

static int callback_pending = 0;
static svScope package_scope;
int bw_native_request_slot_settlement(void);

static PLI_INT32 settle_slot(p_cb_data callback)
{
    svScope previous;
    reset_watch *watch;
    point_watch *point;
    int reaudit = 0;
    (void)callback;
    // Capture is ordered at value change; dispatch waits until all raw input
    // and combinational-condition updates have settled, before granting work.
    while (dirty_resets) {
        watch = dirty_resets; dirty_resets = watch->next_dirty;
        watch->dirty = 0; watch->next_dirty = NULL;
        previous = svSetScope(watch->scope);
        bw_native_reset_seen(1, sv_x, sv_x);
        if (previous) svSetScope(previous);
    }
    callback_pending = 0;
    /* Audit the PREVIOUS grant only after its SV continuations. A callback is
       not a completion receipt and callback registration order is irrelevant. */
    for (point = point_watches; point; point = point->next) {
        previous = svSetScope(point->scope);
        if (bw_native_point_audit()) reaudit = 1;
        if (previous) svSetScope(previous);
    }
    previous = svSetScope(package_scope);
    bw_slot_settlement_arrived();
    if (reaudit && !bw_native_request_slot_settlement()) bw_native_scheduler_failed();
    if (previous) svSetScope(previous);
    return 0;
}

int bw_native_request_slot_settlement(void)
{
    s_cb_data callback;
    s_vpi_time delay;
    vpiHandle handle;
    if (callback_pending) return 1;
#ifdef BW_MON_TEST_FAULTS
    if (fail_next_slot_registration) { fail_next_slot_registration = 0; return 0; }
#endif
    package_scope = svGetScope();
    if (!package_scope) return 0;
    memset(&callback, 0, sizeof(callback));
    memset(&delay, 0, sizeof(delay));
    delay.type = vpiSimTime;
    callback.reason = cbAtEndOfSimTime;
    callback.cb_rtn = settle_slot;
    callback.time = &delay;
    handle = vpi_register_cb(&callback);
    if (!handle) return 0;
    callback_pending = 1;
    return 1;
}
#ifdef __cplusplus
}
#endif
