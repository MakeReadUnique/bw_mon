/* Acceptance-only observer: no writes to product or stimulus at the cut. */
#include <string.h>
#include "svdpi.h"
#include "vpi_user.h"
#ifdef __cplusplus
extern "C" {
#endif
extern void bw_test_target_query_observed(void);
static svScope observer_scope;
static PLI_INT32 observe(p_cb_data data)
{
    svScope previous = svSetScope(observer_scope);
    (void)data;
    bw_test_target_query_observed();
    if (previous) svSetScope(previous);
    return 0;
}
int bw_test_observe_target_query(void)
{
    s_cb_data callback;
    s_vpi_time time;
    observer_scope = svGetScope();
    memset(&callback, 0, sizeof(callback)); memset(&time, 0, sizeof(time));
    time.type = vpiSimTime; callback.reason = cbReadOnlySynch;
    callback.cb_rtn = observe; callback.time = &time;
    return vpi_register_cb(&callback) != NULL;
}
#ifdef __cplusplus
}
#endif
