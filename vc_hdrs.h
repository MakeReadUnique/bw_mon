#ifndef _VC_HDRS_H
#define _VC_HDRS_H

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <dlfcn.h>
#include "svdpi.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _VC_TYPES_
#define _VC_TYPES_
/* common definitions shared with DirectC.h */

typedef unsigned int U;
typedef unsigned char UB;
typedef unsigned char scalar;
typedef struct { U c; U d;} vec32;

#define scalar_0 0
#define scalar_1 1
#define scalar_z 2
#define scalar_x 3

extern long long int ConvUP2LLI(U* a);
extern void ConvLLI2UP(long long int a1, U* a2);
extern long long int GetLLIresult();
extern void StoreLLIresult(const unsigned int* data);
typedef struct VeriC_Descriptor *vc_handle;

#ifndef SV_3_COMPATIBILITY
#define SV_STRING const char*
#else
#define SV_STRING char*
#endif

#endif /* _VC_TYPES_ */


 extern int bw_native_request_slot_settlement();

 extern void bw_native_mark_settlement_watch(/* INPUT */void* handle);

 extern void bw_native_note_generation(/* INPUT */unsigned long long generation);

 extern void bw_native_note_settlement_grant(/* INPUT */void* handle, /* INPUT */unsigned long long grant);

 extern int bw_native_settlement_activity_request(/* INPUT */void* handle, /* INPUT */unsigned long long grant);

 extern void bw_native_reset_seen(/* INPUT */unsigned char prepare, /* INPUT */unsigned char previous, /* INPUT */unsigned char current);

 extern void bw_native_point_edge();

 extern int bw_native_point_audit();

 extern void bw_native_fail_reset_allocation();

 extern void bw_native_fail_slot_registration();

 extern void bw_native_scheduler_failed();

 extern void bw_slot_settlement_arrived();

 extern void bw_end_coordinate_init();

 extern void bw_end_coordinate_verify();

 extern void* bw_native_watch_reset(/* INPUT */const char* scope_path, /* INPUT */const char* signal_name);

 extern void bw_native_reset_snapshot(/* INPUT */void* handle);

 extern int bw_native_reset_watch_error();

 extern unsigned long long bw_native_reset_watch_count();

 extern void bw_native_reset_seen(/* INPUT */unsigned char prepare, /* INPUT */unsigned char previous, /* INPUT */unsigned char current);

 extern void* bw_native_watch_point_clock(/* INPUT */const char* scope_path);

 extern void bw_native_point_edge();

 extern int bw_native_point_audit();

 extern void* bw_native_watch_reset(/* INPUT */const char* scope_path, /* INPUT */const char* signal_name);

 extern void bw_native_reset_snapshot(/* INPUT */void* handle);

 extern int bw_native_reset_watch_error();

 extern unsigned long long bw_native_reset_watch_count();

 extern void bw_native_reset_seen(/* INPUT */unsigned char prepare, /* INPUT */unsigned char previous, /* INPUT */unsigned char current);

 extern void* bw_native_watch_point_clock(/* INPUT */const char* scope_path);

 extern void bw_native_point_edge();

 extern int bw_native_point_audit();

 extern void* bw_native_watch_reset(/* INPUT */const char* scope_path, /* INPUT */const char* signal_name);

 extern void bw_native_reset_snapshot(/* INPUT */void* handle);

 extern int bw_native_reset_watch_error();

 extern unsigned long long bw_native_reset_watch_count();

 extern void bw_native_reset_seen(/* INPUT */unsigned char prepare, /* INPUT */unsigned char previous, /* INPUT */unsigned char current);

 extern void* bw_native_watch_reset(/* INPUT */const char* scope_path, /* INPUT */const char* signal_name);

 extern void bw_native_reset_snapshot(/* INPUT */void* handle);

 extern int bw_native_reset_watch_error();

 extern unsigned long long bw_native_reset_watch_count();

 extern void bw_native_reset_seen(/* INPUT */unsigned char prepare, /* INPUT */unsigned char previous, /* INPUT */unsigned char current);

 extern int bw_test_observe_group_completion();

 extern void bw_test_group_completion_observed();

 extern void* svapfGetAttempt(/* INPUT */unsigned int assertHandle);

 extern void svapfReportResult(/* INPUT */unsigned int assertHandle, /* INPUT */void* ptrAttempt, /* INPUT */int result);

 extern int svapfGetAssertEnabled(/* INPUT */unsigned int assertHandle);

 extern void* bw_native_watch_reset(/* INPUT */const char* scope_path, /* INPUT */const char* signal_name);

 extern void bw_native_reset_snapshot(/* INPUT */void* handle);

 extern int bw_native_reset_watch_error();

 extern unsigned long long bw_native_reset_watch_count();

 extern void bw_native_reset_seen(/* INPUT */unsigned char prepare, /* INPUT */unsigned char previous, /* INPUT */unsigned char current);
void SdisableFork();

#ifdef __cplusplus
}
#endif


#endif //#ifndef _VC_HDRS_H

