/* Reference-host qualification helper, compiled only by the revised scale
 * harness. Advise large anonymous mappings before their first page faults so
 * fragmented hosts can use the same transparent huge pages as clean hosts. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <errno.h>
#include <stddef.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>

#if !defined(__linux__) || !defined(__x86_64__)
#error "The qualified VCS memory advice adapter requires Linux x86-64"
#endif

void *mmap(void *address, size_t length, int protection, int flags, int fd, off_t offset)
{
    void *result = (void *)syscall(SYS_mmap, address, length, (long)protection,
                                  (long)flags, (long)fd, offset);
    if (result != MAP_FAILED && length >= 2UL * 1024 * 1024 &&
        (flags & MAP_ANONYMOUS) && (flags & MAP_TYPE) == MAP_PRIVATE && !(flags & MAP_HUGETLB)) {
        int saved_errno = errno;
        madvise(result, length, MADV_HUGEPAGE);
        errno = saved_errno;
    }
    return result;
}

void *mmap64(void *address, size_t length, int protection, int flags, int fd, off64_t offset)
{
    return mmap(address, length, protection, flags, fd, (off_t)offset);
}
