/* The values upstream's configure and CMake probe for, fixed per target from
 * the compiler's own macros, so a cross build asks the host nothing. Keys are
 * config.h.in's; the thread, CPU-count, memory-size and file-time methods are
 * the ones each platform's libc has. PACKAGE_VERSION comes from the build. */
#ifndef TESTBIN_XZ_CONFIG_H
#define TESTBIN_XZ_CONFIG_H

#define PACKAGE "xz"
#define PACKAGE_NAME "XZ Utils"
#define PACKAGE_TARNAME "xz"
#define PACKAGE_BUGREPORT "xz@tukaani.org"
#define PACKAGE_URL "https://tukaani.org/xz/"
#define PACKAGE_STRING PACKAGE_NAME " " PACKAGE_VERSION
#define VERSION PACKAGE_VERSION
#define NDEBUG 1

/* The C library: C99 headers everywhere, POSIX ones MinGW-w64 also has. */
#define STDC_HEADERS 1
#define HAVE_STDBOOL_H 1
#define HAVE__BOOL 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_UNISTD_H 1
#define HAVE_WCHAR_H 1
#define HAVE_UINTPTR_T 1
#define HAVE_MBRTOWC 1
#define HAVE_VASPRINTF 1
#define HAVE_GETOPT_H 1
#define HAVE_GETOPT_LONG 1
#define HAVE_FUNC_ATTRIBUTE_CONSTRUCTOR 1
#define HAVE___BUILTIN_BSWAPXX 1
#define HAVE___BUILTIN_ASSUME_ALIGNED 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_CLOCK_MONOTONIC 1
#define SIZEOF_SIZE_T __SIZEOF_SIZE_T__
#define HAVE_VISIBILITY 0
#define ASSUME_RAM 128

/* liblzma: every coder, match finder and check; no shared-library symbol
 * versions (it is linked into xz). */
#define HAVE_ENCODERS 1
#define HAVE_ENCODER_LZMA1 1
#define HAVE_ENCODER_LZMA2 1
#define HAVE_ENCODER_X86 1
#define HAVE_ENCODER_POWERPC 1
#define HAVE_ENCODER_IA64 1
#define HAVE_ENCODER_ARM 1
#define HAVE_ENCODER_ARMTHUMB 1
#define HAVE_ENCODER_ARM64 1
#define HAVE_ENCODER_SPARC 1
#define HAVE_ENCODER_RISCV 1
#define HAVE_ENCODER_DELTA 1
#define HAVE_DECODERS 1
#define HAVE_DECODER_LZMA1 1
#define HAVE_DECODER_LZMA2 1
#define HAVE_DECODER_X86 1
#define HAVE_DECODER_POWERPC 1
#define HAVE_DECODER_IA64 1
#define HAVE_DECODER_ARM 1
#define HAVE_DECODER_ARMTHUMB 1
#define HAVE_DECODER_ARM64 1
#define HAVE_DECODER_SPARC 1
#define HAVE_DECODER_RISCV 1
#define HAVE_DECODER_DELTA 1
#define HAVE_LZIP_DECODER 1
#define HAVE_MF_HC3 1
#define HAVE_MF_HC4 1
#define HAVE_MF_BT2 1
#define HAVE_MF_BT3 1
#define HAVE_MF_BT4 1
#define HAVE_CHECK_CRC32 1
#define HAVE_CHECK_CRC64 1
#define HAVE_CHECK_SHA256 1

/* The CPU: unaligned loads are cheap on both, and each has a CRC unit the
 * code probes at run time (CLMUL through cpuid; the ARM64 CRC extension
 * through the auxiliary vector, sysctl or IsProcessorFeaturePresent). */
#if defined(__x86_64__) || defined(__aarch64__)
#define TUKLIB_FAST_UNALIGNED_ACCESS 1
#endif
#if defined(__x86_64__)
#define HAVE_IMMINTRIN_H 1
#define HAVE_CPUID_H 1
#define HAVE_USABLE_CLMUL 1
#define HAVE__MM_MOVEMASK_EPI8 1
#endif
#if defined(__aarch64__)
#define HAVE_ARM64_CRC32 1
#endif

/* The operating system. Memory is read as configure would pick it, sysconf
 * before sysctl: macOS's HW_PHYSMEM is a 32-bit value, zero on a 64 GiB host. */
#if defined(_WIN32)
#define MYTHREAD_VISTA 1
#define HAVE__FUTIME 1
#elif defined(__APPLE__)
#define MYTHREAD_POSIX 1
#define TUKLIB_CPUCORES_SYSCTL 1
#define TUKLIB_PHYSMEM_SYSCONF 1
#define HAVE_SYSCTLBYNAME 1
#define HAVE_WCWIDTH 1
#define HAVE_OPTRESET 1
#define HAVE_GETRLIMIT 1
#define HAVE_FUTIMENS 1
#define HAVE_STRUCT_STAT_ST_ATIMESPEC_TV_NSEC 1
#else /* linux, musl */
#define MYTHREAD_POSIX 1
#define HAVE_PTHREAD_CONDATTR_SETCLOCK 1
#define TUKLIB_CPUCORES_SCHED_GETAFFINITY 1
#define TUKLIB_PHYSMEM_SYSCONF 1
#define HAVE_GETAUXVAL 1
#define HAVE_HWCAP_CRC32 1
#define HAVE_BYTESWAP_H 1
#define HAVE_WCWIDTH 1
#define HAVE_OPTRESET 1
#define HAVE_GETRLIMIT 1
#define HAVE_POSIX_FADVISE 1
#define HAVE_FUTIMENS 1
#define HAVE_STRUCT_STAT_ST_ATIM_TV_NSEC 1
#endif

#endif
