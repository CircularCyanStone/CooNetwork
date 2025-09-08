#ifndef ANTANTSSM_VERSION_H
#define ANTANTSSM_VERSION_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif
#include <string.h>
/**
 * The version number x.y.z is split into three parts.
 * Major, Minor, Patchlevel
 */
#define ANTSSM_VERSION_MAJOR  3
#define ANTSSM_VERSION_MINOR  0
#define ANTSSM_VERSION_PATCH  1

/**
 * The single version number has the following structure:
 *    MMNNPP00
 *    Major version | Minor version | Patch version
 */
#define ANTSSM_VERSION_NUMBER         0x03000100
#define ANTSSM_VERSION_STRING         "3.0.1"
#define ANTSSM_VERSION_STRING_FULL    "antssm 3.0.1"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(ANTSSM_VERSION_C)

/**
 * Get the version number.
 *
 * \return          The constructed version number in the format
 *                  MMNNPP00 (Major, Minor, Patch).
 */
int mpaas_antssm_version_get_number(unsigned int *version);

/**
 * Get the version string ("x.y.z").
 *
 * \param string    The string that will receive the value.
 *                  (Should be at least 9 bytes in size)
 */
int mpaas_antssm_version_get_string(char *buf, size_t *buflen);

/**
 * Get the full version string ("softsecuritymodule x.y.z").
 *
 * \param string    The string that will receive the value. The softsecuritymodule version
 *                  string will use 64 bytes AT MOST including a terminating
 *                  null byte.
 *                  (So the buffer should be at least 18 bytes to receive this
 *                  version string).
 */
int mpaas_antssm_version_get_string_full(char *buf, size_t *buflen);

/**
 * \brief           Check if support for a feature was compiled into this
 *                  softsecuritymodule binary. This allows you to see at runtime if the
 *                  library was for instance compiled with or without
 *                  Multi-threading support.
 *
 * \note            only checks against defines in the sections "System
 *                  support", "softsecuritymodule modules" and "softsecuritymodule feature
 *                  support" in config.h
 *
 * \param feature   The string for the define to check (e.g. "ANTSSM_AES_C")
 *
 * \return          0 if the feature is present,
 *                  -1 if the feature is not present and
 *                  -2 if support for feature checking as a whole was not
 *                  compiled in.
 */
int mpaas_antssm_version_check_feature(const char *feature);

/**
 * \brief          Get features compiled into this softsecuritymodule binary
 */
char **mpaas_antssm_version_get_features();

#endif /* ANTSSM_VERSION_C */

#ifdef __cplusplus
}
#endif

#endif /* ANTANTSSM_VERSION_H */
