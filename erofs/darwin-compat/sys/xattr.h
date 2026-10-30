/* The libSystem extended-attribute calls erofs-utils' __APPLE__ branches use,
 * declared here because the pinned zig's macOS headers carry no sys/xattr.h.
 * The signatures and the flag are the macOS ABI (xattr(2)). */
#ifndef TESTBIN_DARWIN_SYS_XATTR_H
#define TESTBIN_DARWIN_SYS_XATTR_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#define XATTR_NOFOLLOW 0x0001

ssize_t listxattr(const char *path, char *namebuf, size_t size, int options);
ssize_t getxattr(const char *path, const char *name, void *value, size_t size,
                 uint32_t position, int options);
int setxattr(const char *path, const char *name, const void *value, size_t size,
             uint32_t position, int options);

#endif
