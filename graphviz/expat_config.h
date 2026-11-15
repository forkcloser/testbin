/* expat's configuration for the dot this repository builds, in place of the
 * expat_config.h configure writes: the same file for every target. build.sh
 * gives EXPAT_VERSION and compiles the one entropy source named here. */
#ifndef EXPAT_CONFIG_H
#define EXPAT_CONFIG_H 1
#define BYTEORDER 1234
#define HAVE_INTTYPES_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define STDC_HEADERS 1
#define PACKAGE "expat"
#define PACKAGE_NAME "expat"
#define PACKAGE_TARNAME "expat"
#define PACKAGE_VERSION EXPAT_VERSION
#define PACKAGE_STRING "expat " EXPAT_VERSION
#define PACKAGE_BUGREPORT "https://github.com/libexpat/libexpat/issues"
#define PACKAGE_URL ""
#define VERSION EXPAT_VERSION
#define XML_CONTEXT_BYTES 1024
#define XML_DTD 1
#define XML_GE 1
#define XML_NS 1

/* Where the hash salt comes from, by target; windows takes rand_s on its
 * own. */
#if defined(__linux__)
#define HAVE_GETRANDOM 1
#elif defined(__APPLE__)
#define HAVE_ARC4RANDOM_BUF 1
#endif
#endif
