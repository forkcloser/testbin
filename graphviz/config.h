/* Graphviz's configuration for the dot this repository builds, in place of
 * the config.h configure writes: the same file for every target, so the
 * build does not depend on the host that ran configure. The layout engines
 * and the core renderers, expat for HTML-like labels, and nothing else: no
 * zlib, no pango or cairo, no gd, no ltdl. build.sh gives GRAPHVIZ_VERSION. */
#ifndef TESTBIN_GRAPHVIZ_CONFIG_H
#define TESTBIN_GRAPHVIZ_CONFIG_H

#define PACKAGE_NAME "graphviz"
#define PACKAGE_TARNAME "graphviz"
#define PACKAGE_VERSION GRAPHVIZ_VERSION
#define PACKAGE_STRING "graphviz " GRAPHVIZ_VERSION
#define PACKAGE_BUGREPORT "https://gitlab.com/graphviz/graphviz/-/issues"
#define PACKAGE_URL ""
#define VERSION GRAPHVIZ_VERSION

#define DEFAULT_DPI 96
#define GVPLUGIN_VERSION 8
#define GVPLUGIN_CONFIG_FILE "config8"
#define WITH_CGRAPH 1
#define DIGCOLA 1
#define ORTHO 1
#define SFDP 1
#define HAVE_EXPAT 1

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
#define YYTEXT_POINTER 1

/* What the C library has, by target. Without drand48 and srand48 Graphviz
 * falls back to rand, so a seeded layout (neato, fdp) differs on windows. */
#ifdef _WIN32
#define HAVE_SETMODE 1
#else
#define HAVE_DRAND48 1
#define HAVE_SRAND48 1
#define HAVE_SETENV 1
#define HAVE_SYS_MMAN_H 1
#define HAVE_SYS_TIME_H 1
#endif
#ifdef __linux__
#define HAVE_MEMRCHR 1
#endif

#endif
