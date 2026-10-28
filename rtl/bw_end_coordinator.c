/* Ticket 56 native end coordinator. Registration is idempotent: the first
 * role registration saves the package scope and installs one
 * cbEndOfSimulation callback. The callback runs strictly after all SV final
 * blocks (order proven by the completion probe on this VCS), selects the
 * package scope and calls the exported verifier, which only reads frozen
 * evidence and prints the unique report verdict. */
#include <string.h>
#include "svdpi.h"
#include "vpi_user.h"
#ifdef __cplusplus
extern "C" {
#endif
extern void bw_end_coordinate_verify(void);
static svScope end_package_scope;
static int end_callback_installed;
static PLI_INT32 end_callback(p_cb_data cb)
{
    svScope previous = svSetScope(end_package_scope);
    (void)cb;
    bw_end_coordinate_verify();
    if (previous) svSetScope(previous);
    return 0;
}
void bw_end_coordinate_init(void)
{
    s_cb_data callback;
    s_vpi_time time;
    if (end_callback_installed) return;
    end_callback_installed = 1;
    end_package_scope = svGetScope();
    memset(&callback, 0, sizeof(callback));
    memset(&time, 0, sizeof(time));
    time.type = vpiSimTime;
    callback.reason = cbEndOfSimulation;
    callback.cb_rtn = end_callback;
    callback.time = &time;
    if (!vpi_register_cb(&callback))
        vpi_printf("BW_END_REGISTER_FAIL reason=callback\n");
}
#ifdef __cplusplus
}
#endif
