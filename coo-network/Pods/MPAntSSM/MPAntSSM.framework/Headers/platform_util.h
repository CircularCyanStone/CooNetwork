/**
 * \file platform_util.h
 *
 * \brief Common and shared functions used by multiple modules in the Mbed TLS
 *        library.
 */
/*
 *  Copyright (C) 2018, Arm Limited, All Rights Reserved
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may
 *  not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 *  This file is part of Mbed TLS (https://tls.mbed.org)
 */
#ifndef ANTSSM_PLATFORM_UTIL_H
#define ANTSSM_PLATFORM_UTIL_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "antssm/config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stddef.h>
#if defined(ANTSSM_HAVE_TIME_DATE)
#include "antssm/platform_time.h"
#include <time.h>
#endif /* ANTSSM_HAVE_TIME_DATE */

#ifdef __cplusplus
extern "C" {
#endif

#if defined(ANTSSM_CHECK_PARAMS)

#if defined(ANTSSM_CHECK_PARAMS_ASSERT)
/* Allow the user to define ANTSSM_PARAM_FAILED to something like assert
 * (which is what our config.h suggests). */
#include <assert.h>
#endif /* ANTSSM_CHECK_PARAMS_ASSERT */

#if defined(ANTSSM_PARAM_FAILED)
/** An alternative definition of ANTSSM_PARAM_FAILED has been set in config.h.
 *
 * This flag can be used to check whether it is safe to assume that
 * ANTSSM_PARAM_FAILED() will expand to a call to mpaas_antssm_param_failed().
 */
#define ANTSSM_PARAM_FAILED_ALT

#elif defined(ANTSSM_CHECK_PARAMS_ASSERT)
#define ANTSSM_PARAM_FAILED( cond ) assert( cond )
#define ANTSSM_PARAM_FAILED_ALT

#else /* ANTSSM_PARAM_FAILED */
#define ANTSSM_PARAM_FAILED( cond ) \
    mpaas_antssm_param_failed( #cond, __FILE__, __LINE__ )

/**
 * \brief       User supplied callback function for parameter validation failure.
 *              See #ANTSSM_CHECK_PARAMS for context.
 *
 *              This function will be called unless an alternative treatement
 *              is defined through the #ANTSSM_PARAM_FAILED macro.
 *
 *              This function can return, and the operation will be aborted, or
 *              alternatively, through use of setjmp()/longjmp() can resume
 *              execution in the application code.
 *
 * \param failure_condition The assertion that didn't hold.
 * \param file  The file where the assertion failed.
 * \param line  The line in the file where the assertion failed.
 */
void mpaas_antssm_param_failed( const char *failure_condition,
                           const char *file,
                           int line );
#endif /* ANTSSM_PARAM_FAILED */

/* Internal macro meant to be called only from within the library. */
#define ANTSSM_INTERNAL_VALIDATE_RET( cond, ret )  \
    do {                                            \
        if( !(cond) )                               \
        {                                           \
            ANTSSM_PARAM_FAILED( cond );           \
            return( ret );                          \
        }                                           \
    } while( 0 )

/* Internal macro meant to be called only from within the library. */
#define ANTSSM_INTERNAL_VALIDATE( cond )           \
    do {                                            \
        if( !(cond) )                               \
        {                                           \
            ANTSSM_PARAM_FAILED( cond );           \
            return;                                 \
        }                                           \
    } while( 0 )

#else /* ANTSSM_CHECK_PARAMS */

/* Internal macros meant to be called only from within the library. */
#define ANTSSM_INTERNAL_VALIDATE_RET(cond, ret)  do { } while( 0 )
#define ANTSSM_INTERNAL_VALIDATE(cond)           do { } while( 0 )

#endif /* ANTSSM_CHECK_PARAMS */

/* Internal helper macros for deprecating API constants. */
#if !defined(ANTSSM_DEPRECATED_REMOVED)
#if defined(ANTSSM_DEPRECATED_WARNING)
/* Deliberately don't (yet) export ANTSSM_DEPRECATED here
 * to avoid conflict with other headers which define and use
 * it, too. We might want to move all these definitions here at
 * some point for uniformity. */
#define ANTSSM_DEPRECATED __attribute__((deprecated))
ANTSSM_DEPRECATED typedef char const * mpaas_antssm_deprecated_string_constant_t;
#define ANTSSM_DEPRECATED_STRING_CONSTANT( VAL )       \
    ( (mpaas_antssm_deprecated_string_constant_t) ( VAL ) )
ANTSSM_DEPRECATED typedef int mpaas_antssm_deprecated_numeric_constant_t;
#define ANTSSM_DEPRECATED_NUMERIC_CONSTANT( VAL )       \
    ( (mpaas_antssm_deprecated_numeric_constant_t) ( VAL ) )
#undef ANTSSM_DEPRECATED
#else /* ANTSSM_DEPRECATED_WARNING */
#define ANTSSM_DEPRECATED_STRING_CONSTANT(VAL) VAL
#define ANTSSM_DEPRECATED_NUMERIC_CONSTANT(VAL) VAL
#endif /* ANTSSM_DEPRECATED_WARNING */
#endif /* ANTSSM_DEPRECATED_REMOVED */

/**
 * \brief       Securely zeroize a buffer
 *
 *              The function is meant to wipe the data contained in a buffer so
 *              that it can no longer be recovered even if the program memory
 *              is later compromised. Call this function on sensitive data
 *              stored on the stack before returning from a function, and on
 *              sensitive data stored on the heap before freeing the heap
 *              object.
 *
 *              It is extremely difficult to guarantee that calls to
 *              mpaas_antssm_platform_zeroize() are not removed by aggressive
 *              compiler optimizations in a portable way. For this reason, Mbed
 *              TLS provides the configuration option
 *              ANTSSM_PLATFORM_ZEROIZE_ALT, which allows users to configure
 *              mpaas_antssm_platform_zeroize() to use a suitable implementation for
 *              their platform and needs
 *
 * \param buf   Buffer to be zeroized
 * \param len   Length of the buffer in bytes
 *
 */
void mpaas_antssm_platform_zeroize(void *buf, size_t len);

#if defined(ANTSSM_HAVE_TIME_DATE)
/**
 * \brief      Platform-specific implementation of gmtime_r()
 *
 *             The function is a thread-safe abstraction that behaves
 *             similarly to the gmtime_r() function from Unix/POSIX.
 *
 *             Mbed TLS will try to identify the underlying platform and
 *             make use of an appropriate underlying implementation (e.g.
 *             gmtime_r() for POSIX and gmtime_s() for Windows). If this is
 *             not possible, then gmtime() will be used. In this case, calls
 *             from the library to gmtime() will be guarded by the mutex
 *             mpaas_antssm_threading_gmtime_mutex if ANTSSM_THREADING_C is
 *             enabled. It is recommended that calls from outside the library
 *             are also guarded by this mutex.
 *
 *             If ANTSSM_PLATFORM_GMTIME_R_ALT is defined, then Mbed TLS will
 *             unconditionally use the alternative implementation for
 *             mpaas_antssm_platform_gmtime_r() supplied by the user at compile time.
 *
 * \param tt     Pointer to an object containing time (in seconds) since the
 *               epoch to be converted
 * \param tm_buf Pointer to an object where the results will be stored
 *
 * \return      Pointer to an object of type struct tm on success, otherwise
 *              NULL
 */
struct tm *mpaas_antssm_platform_gmtime_r( const mpaas_antssm_time_t *tt,
                                      struct tm *tm_buf );
#endif /* ANTSSM_HAVE_TIME_DATE */

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_PLATFORM_UTIL_H */
