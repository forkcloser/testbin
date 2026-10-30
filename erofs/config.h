/* erofs-utils' config.h for the zig builds: the keys configure.ac defines, with
 * the values its checks find on each target, chosen from the compiler's own
 * macros so one file serves every target and a cross build probes nothing.
 * PACKAGE_VERSION comes from build.sh, which reads it from pins.yaml.
 *
 * The build is configured as forkcloser/erofs's was: lz4 and lz4hc on, the
 * built-in deflate compressor (kite_deflate), every optional library off
 * (zlib, liblzma, libdeflate, libzstd, libuuid, libselinux, xxhash, curl,
 * openssl, libxml2, json-c, liburing, fuse), the block size up to 16 KiB on
 * every target. */

#define LZ4_ENABLED 1
#define LZ4HC_ENABLED 1

/* configure pins it from the build host's page size; forkcloser/erofs sets
 * MAX_BLOCK_SIZE=16384 so every platform's mkfs writes the same images. */
#define EROFS_MAX_BLOCK_SIZE 16384

#define HAVE_FCNTL_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIMITS_H 1
#define HAVE_STDDEF_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_UNISTD_H 1
#define HAVE_GETOPT_H 1
#define HAVE_DIRENT_H 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_MEMSET 1
#define HAVE_STRDUP 1
#define HAVE_STRERROR 1
#define HAVE_STRRCHR 1
#define HAVE_STRTOULL 1

#if !defined(_WIN32)
#define HAVE_SYS_IOCTL_H 1
#define HAVE_SYS_MMAN_H 1
#define HAVE_SYS_RESOURCE_H 1
#define HAVE_SYS_UIO_H 1
#define HAVE_SYS_XATTR_H 1
#define HAVE_SYS_RANDOM_H 1
#define HAVE_PTHREAD_H 1
#define EROFS_MT_ENABLED 1
#define HAVE_GETRLIMIT 1
#define HAVE_REALPATH 1
#define HAVE_SYSCONF 1
#define HAVE_PWRITEV 1
#else
/* MinGW: the compat headers stand in for sys/ioctl.h, sys/mman.h, sys/uio.h
 * and sys/xattr.h (configure found them in the sysroot), and posix_compat.h,
 * force-included, supplies what they declare. */
#define HAVE_SYS_IOCTL_H 1
#define HAVE_SYS_MMAN_H 1
#define HAVE_SYS_UIO_H 1
#define HAVE_SYS_XATTR_H 1
#endif

#if defined(__linux__)
#define HAVE_ENDIAN_H 1
#define HAVE_LINUX_FALLOC_H 1
#define HAVE_LINUX_FS_H 1
#define HAVE_LINUX_LOOP_H 1
#define HAVE_LINUX_TYPES_H 1
#define HAVE_LINUX_XATTR_H 1
#define HAVE_SYS_SENDFILE_H 1
#define HAVE_SYS_STATFS_H 1
#define HAVE_SYS_SYSMACROS_H 1
#define HAVE_STRUCT_STAT_ST_ATIM 1
#define HAVE_STRUCT_STAT_ST_RDEV 1
#define HAVE_MEMRCHR 1
#define HAVE_COPY_FILE_RANGE 1
#define HAVE_FALLOCATE 1
#define HAVE_GETRANDOM 1
#define HAVE_GETTID 1
#define HAVE_LGETXATTR 1
#define HAVE_LLISTXATTR 1
#define HAVE_LSETXATTR 1
#define HAVE_POSIX_FADVISE 1
#define HAVE_FSTATFS 1
#define HAVE_SENDFILE 1
#define HAVE_UTIMENSAT 1
#endif

#if defined(__APPLE__)
#define HAVE_STRUCT_STAT_ST_RDEV 1
#define HAVE_UTIMENSAT 1
#endif
