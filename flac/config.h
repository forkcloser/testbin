/* flac's config.h for the zig builds: the keys of upstream's config.cmake.h.in
 * with the values its CMake would probe, chosen per target from the compiler's
 * own macros, so one file serves every target and a cross build probes nothing.
 * PACKAGE_VERSION comes from build.sh, which reads it from pins.yaml.
 * Ogg FLAC needs libogg and is left out: the tools handle native FLAC only. */

#define CPU_IS_BIG_ENDIAN 0
#define WORDS_BIGENDIAN CPU_IS_BIG_ENDIAN
#define ENABLE_64_BIT_WORDS 1

#define OGG_FOUND 0
#define FLAC__HAS_OGG OGG_FOUND

#if defined(__x86_64__)
#define FLAC__ALIGN_MALLOC_DATA
#define FLAC__HAS_X86INTRIN 1
#define HAVE_CPUID_H 1
#define HAVE_X86INTRIN_H 1
#define FLAC__USE_AVX
#else
#define FLAC__HAS_X86INTRIN 0
#endif

#if defined(__aarch64__)
#define FLAC__CPU_ARM64
#define FLAC__HAS_NEONINTRIN 1
#define FLAC__HAS_A64NEONINTRIN 1
#else
#define FLAC__HAS_NEONINTRIN 0
#define FLAC__HAS_A64NEONINTRIN 0
#endif

#if defined(__APPLE__)
#define FLAC__SYS_DARWIN
#endif

#if defined(__linux__)
#define FLAC__SYS_LINUX
#define HAVE_BYTESWAP_H 1
#endif

#if !defined(_WIN32)
#define HAVE_CLOCK_GETTIME 1
#define HAVE_FSEEKO 1
#define HAVE_LANGINFO_CODESET 1
#define HAVE_PTHREAD 1
#define HAVE_SYS_IOCTL_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_TERMIOS_H 1
#define HAVE_UNISTD_H 1
#endif

#define HAVE_BSWAP16 1
#define HAVE_BSWAP32 1
#define HAVE_INTTYPES_H 1
#define HAVE_LROUND 1
#define HAVE_MEMORY_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_TYPEOF 1

#ifndef NDEBUG
#define NDEBUG 1
#endif

#ifndef _ALL_SOURCE
#define _ALL_SOURCE
#endif
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#ifndef _DARWIN_USE_64_BIT_INODE
#define _DARWIN_USE_64_BIT_INODE 1
#endif
#ifndef _FILE_OFFSET_BITS
#define _FILE_OFFSET_BITS 64
#endif
#ifndef _LARGEFILE_SOURCE
#define _LARGEFILE_SOURCE
#endif

/* mingw's UCRT stdio.h defines fseeko (a 32-bit offset) and fseeko64 inline.
 * compat.h then #defines fseeko as fseeko64 and includes stdio.h; seen after
 * that macro, the fseeko definition becomes a second, conflicting fseeko64.
 * Every source includes config.h before compat.h, so stdio.h is read here,
 * before the macro exists. */
#if defined(_WIN32)
#include <stdio.h>
#endif
