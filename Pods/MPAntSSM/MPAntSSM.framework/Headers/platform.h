/**
 * \file platform.h
 *
 * \brief This file contains the definitions and functions of the
 *        Mbed TLS platform abstraction layer.
 *
 *        The platform abstraction layer removes the need for the library
 *        to directly link to standard C library functions or operating
 *        system services, making the library easier to port and embed.
 *        Application developers and users of the library can provide their own
 *        implementations of these functions, or implementations specific to
 *        their platform, which can be statically linked to the library or
 *        dynamically configured at runtime.
 */
/*
 *  Copyright (C) 2006-2018, Arm Limited (or its affiliates), All Rights Reserved
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
#ifndef ANTSSM_PLATFORM_H
#define ANTSSM_PLATFORM_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "antssm/config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#if defined(ANTSSM_HAVE_TIME)
#include "antssm/platform_time.h"
#endif

#define ANTSSM_ERR_PLATFORM_HW_ACCEL_FAILED     -0x0070 /**< Hardware accelerator failed */
#define ANTSSM_ERR_PLATFORM_FEATURE_UNSUPPORTED -0x0072 /**< The requested feature is not supported by the platform */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \name SECTION: Module settings
 *
 * The configuration options you can set for this module are in this section.
 * Either change them in config.h or define them on the compiler command line.
 * \{
 */

/* The older Microsoft Windows common runtime provides non-conforming
 * implementations of some standard library functions, including snprintf
 * and vsnprintf. This affects MSVC and MinGW builds.
 */
#if defined(__MINGW32__) || (defined(_MSC_VER) && _MSC_VER <= 1900)
#define ANTSSM_PLATFORM_HAS_NON_CONFORMING_SNPRINTF
#define ANTSSM_PLATFORM_HAS_NON_CONFORMING_VSNPRINTF
#endif

#if !defined(ANTSSM_PLATFORM_NO_STD_FUNCTIONS)
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#if !defined(ANTSSM_PLATFORM_STD_SNPRINTF)
#if defined(ANTSSM_PLATFORM_HAS_NON_CONFORMING_SNPRINTF)
#define ANTSSM_PLATFORM_STD_SNPRINTF   mpaas_antssm_platform_win32_snprintf /**< The default \c snprintf function to use.  */
#else
#define ANTSSM_PLATFORM_STD_SNPRINTF   snprintf /**< The default \c snprintf function to use.  */
#endif
#endif
#if !defined(ANTSSM_PLATFORM_STD_VSNPRINTF)
#if defined(ANTSSM_PLATFORM_HAS_NON_CONFORMING_VSNPRINTF)
#define ANTSSM_PLATFORM_STD_VSNPRINTF   mpaas_antssm_platform_win32_vsnprintf /**< The default \c vsnprintf function to use.  */
#else
#define ANTSSM_PLATFORM_STD_VSNPRINTF   vsnprintf /**< The default \c vsnprintf function to use.  */
#endif
#endif
#if !defined(ANTSSM_PLATFORM_STD_PRINTF)
#define ANTSSM_PLATFORM_STD_PRINTF   printf /**< The default \c printf function to use. */
#endif
#if !defined(ANTSSM_PLATFORM_STD_FPRINTF)
#define ANTSSM_PLATFORM_STD_FPRINTF fprintf /**< The default \c fprintf function to use. */
#endif
#if !defined(ANTSSM_PLATFORM_STD_CALLOC)
#define ANTSSM_PLATFORM_STD_CALLOC   calloc /**< The default \c calloc function to use. */
#endif
#if !defined(ANTSSM_PLATFORM_STD_FREE)
#define ANTSSM_PLATFORM_STD_FREE       free /**< The default \c free function to use. */
#endif
#if !defined(ANTSSM_PLATFORM_STD_EXIT)
#define ANTSSM_PLATFORM_STD_EXIT      exit /**< The default \c exit function to use. */
#endif
#if !defined(ANTSSM_PLATFORM_STD_TIME)
#define ANTSSM_PLATFORM_STD_TIME       time    /**< The default \c time function to use. */
#endif
#if !defined(ANTSSM_PLATFORM_STD_EXIT_SUCCESS)
#define ANTSSM_PLATFORM_STD_EXIT_SUCCESS  EXIT_SUCCESS /**< The default exit value to use. */
#endif
#if !defined(ANTSSM_PLATFORM_STD_EXIT_FAILURE)
#define ANTSSM_PLATFORM_STD_EXIT_FAILURE  EXIT_FAILURE /**< The default exit value to use. */
#endif
#if defined(ANTSSM_FS_IO)
#if !defined(ANTSSM_PLATFORM_STD_NV_SEED_READ)
#define ANTSSM_PLATFORM_STD_NV_SEED_READ   mpaas_antssm_platform_std_nv_seed_read
#endif
#if !defined(ANTSSM_PLATFORM_STD_NV_SEED_WRITE)
#define ANTSSM_PLATFORM_STD_NV_SEED_WRITE  mpaas_antssm_platform_std_nv_seed_write
#endif
#if !defined(ANTSSM_PLATFORM_STD_NV_SEED_FILE)
#define ANTSSM_PLATFORM_STD_NV_SEED_FILE   "seedfile"
#endif
#endif /* ANTSSM_FS_IO */
#else /* ANTSSM_PLATFORM_NO_STD_FUNCTIONS */
#if defined(ANTSSM_PLATFORM_STD_MEM_HDR)
#include ANTSSM_PLATFORM_STD_MEM_HDR
#endif
#endif /* ANTSSM_PLATFORM_NO_STD_FUNCTIONS */


/* \} name SECTION: Module settings */

/*
 * The function pointers for calloc and free.
 */
#if defined(ANTSSM_PLATFORM_MEMORY)
#if defined(ANTSSM_PLATFORM_FREE_MACRO) && \
    defined(ANTSSM_PLATFORM_CALLOC_MACRO)
#define mpaas_antssm_free       ANTSSM_PLATFORM_FREE_MACRO
#define mpaas_antssm_calloc     ANTSSM_PLATFORM_CALLOC_MACRO
#else
/* For size_t */
#include <stddef.h>
extern void *mpaas_antssm_calloc( size_t n, size_t size );
extern void mpaas_antssm_free( void *ptr );

/**
 * \brief               This function dynamically sets the memory-management
 *                      functions used by the library, during runtime.
 *
 * \param calloc_func   The \c calloc function implementation.
 * \param free_func     The \c free function implementation.
 *
 * \return              \c 0.
 */
int mpaas_antssm_platform_set_calloc_free( void * (*calloc_func)( size_t, size_t ),
                              void (*free_func)( void * ) );
#endif /* ANTSSM_PLATFORM_FREE_MACRO && ANTSSM_PLATFORM_CALLOC_MACRO */
#else /* !ANTSSM_PLATFORM_MEMORY */
#define mpaas_antssm_free       free
#define mpaas_antssm_calloc     calloc
#endif /* ANTSSM_PLATFORM_MEMORY && !ANTSSM_PLATFORM_{FREE,CALLOC}_MACRO */

/*
 * The function pointers for fprintf
 */
#if defined(ANTSSM_PLATFORM_FPRINTF_ALT)
/* We need FILE * */
#include <stdio.h>
extern int (*mpaas_antssm_fprintf)( FILE *stream, const char *format, ... );

/**
 * \brief                This function dynamically configures the fprintf
 *                       function that is called when the
 *                       mpaas_antssm_fprintf() function is invoked by the library.
 *
 * \param fprintf_func   The \c fprintf function implementation.
 *
 * \return               \c 0.
 */
int mpaas_antssm_platform_set_fprintf( int (*fprintf_func)( FILE *stream, const char *,
                                               ... ) );
#else
#if defined(ANTSSM_PLATFORM_FPRINTF_MACRO)
#define mpaas_antssm_fprintf    ANTSSM_PLATFORM_FPRINTF_MACRO
#else
#define mpaas_antssm_fprintf    fprintf
#endif /* ANTSSM_PLATFORM_FPRINTF_MACRO */
#endif /* ANTSSM_PLATFORM_FPRINTF_ALT */

/*
 * The function pointers for printf
 */
#if defined(ANTSSM_PLATFORM_PRINTF_ALT)
extern int (*mpaas_antssm_printf)( const char *format, ... );

/**
 * \brief               This function dynamically configures the snprintf
 *                      function that is called when the mpaas_antssm_snprintf()
 *                      function is invoked by the library.
 *
 * \param printf_func   The \c printf function implementation.
 *
 * \return              \c 0 on success.
 */
int mpaas_antssm_platform_set_printf( int (*printf_func)( const char *, ... ) );
#else /* !ANTSSM_PLATFORM_PRINTF_ALT */
#if defined(ANTSSM_PLATFORM_PRINTF_MACRO)
#define mpaas_antssm_printf     ANTSSM_PLATFORM_PRINTF_MACRO
#else
#define mpaas_antssm_printf     printf
#endif /* ANTSSM_PLATFORM_PRINTF_MACRO */
#endif /* ANTSSM_PLATFORM_PRINTF_ALT */

/*
 * The function pointers for snprintf
 *
 * The snprintf implementation should conform to C99:
 * - it *must* always correctly zero-terminate the buffer
 *   (except when n == 0, then it must leave the buffer untouched)
 * - however it is acceptable to return -1 instead of the required length when
 *   the destination buffer is too short.
 */
#if defined(ANTSSM_PLATFORM_HAS_NON_CONFORMING_SNPRINTF)
/* For Windows (inc. MSYS2), we provide our own fixed implementation */
int mpaas_antssm_platform_win32_snprintf( char *s, size_t n, const char *fmt, ... );
#endif

#if defined(ANTSSM_PLATFORM_SNPRINTF_ALT)
extern int (*mpaas_antssm_snprintf)( char * s, size_t n, const char * format, ... );

/**
 * \brief                 This function allows configuring a custom
 *                        \c snprintf function pointer.
 *
 * \param snprintf_func   The \c snprintf function implementation.
 *
 * \return                \c 0 on success.
 */
int mpaas_antssm_platform_set_snprintf( int (*snprintf_func)( char * s, size_t n,
                                                 const char * format, ... ) );
#else /* ANTSSM_PLATFORM_SNPRINTF_ALT */
#if defined(ANTSSM_PLATFORM_SNPRINTF_MACRO)
#define mpaas_antssm_snprintf   ANTSSM_PLATFORM_SNPRINTF_MACRO
#else
#define mpaas_antssm_snprintf   ANTSSM_PLATFORM_STD_SNPRINTF
#endif /* ANTSSM_PLATFORM_SNPRINTF_MACRO */
#endif /* ANTSSM_PLATFORM_SNPRINTF_ALT */

/*
 * The function pointers for vsnprintf
 *
 * The vsnprintf implementation should conform to C99:
 * - it *must* always correctly zero-terminate the buffer
 *   (except when n == 0, then it must leave the buffer untouched)
 * - however it is acceptable to return -1 instead of the required length when
 *   the destination buffer is too short.
 */
#if defined(ANTSSM_PLATFORM_HAS_NON_CONFORMING_VSNPRINTF)
#include <stdarg.h>
/* For Older Windows (inc. MSYS2), we provide our own fixed implementation */
int mpaas_antssm_platform_win32_vsnprintf( char *s, size_t n, const char *fmt, va_list arg );
#endif

#if defined(ANTSSM_PLATFORM_VSNPRINTF_ALT)
#include <stdarg.h>
extern int (*mpaas_antssm_vsnprintf)( char * s, size_t n, const char * format, va_list arg );

/**
 * \brief   Set your own snprintf function pointer
 *
 * \param   vsnprintf_func   The \c vsnprintf function implementation
 *
 * \return  \c 0
 */
int mpaas_antssm_platform_set_vsnprintf( int (*vsnprintf_func)( char * s, size_t n,
                                                 const char * format, va_list arg ) );
#else /* ANTSSM_PLATFORM_VSNPRINTF_ALT */
#if defined(ANTSSM_PLATFORM_VSNPRINTF_MACRO)
#define mpaas_antssm_vsnprintf   ANTSSM_PLATFORM_VSNPRINTF_MACRO
#else
#define mpaas_antssm_vsnprintf   vsnprintf
#endif /* ANTSSM_PLATFORM_VSNPRINTF_MACRO */
#endif /* ANTSSM_PLATFORM_VSNPRINTF_ALT */

/*
 * The function pointers for exit
 */
#if defined(ANTSSM_PLATFORM_EXIT_ALT)
extern void (*mpaas_antssm_exit)( int status );

/**
 * \brief             This function dynamically configures the exit
 *                    function that is called when the mpaas_antssm_exit()
 *                    function is invoked by the library.
 *
 * \param exit_func   The \c exit function implementation.
 *
 * \return            \c 0 on success.PLATFORM_C
 */
int mpaas_antssm_platform_set_exit( void (*exit_func)( int status ) );
#else
#if defined(ANTSSM_PLATFORM_EXIT_MACRO)
#define mpaas_antssm_exit   ANTSSM_PLATFORM_EXIT_MACRO
#else
#define mpaas_antssm_exit   exit
#endif /* ANTSSM_PLATFORM_EXIT_MACRO */
#endif /* ANTSSM_PLATFORM_EXIT_ALT */

/*
 * The default exit values
 */
#if defined(ANTSSM_PLATFORM_STD_EXIT_SUCCESS)
#define ANTSSM_EXIT_SUCCESS ANTSSM_PLATFORM_STD_EXIT_SUCCESS
#else
#define ANTSSM_EXIT_SUCCESS 0
#endif
#if defined(ANTSSM_PLATFORM_STD_EXIT_FAILURE)
#define ANTSSM_EXIT_FAILURE ANTSSM_PLATFORM_STD_EXIT_FAILURE
#else
#define ANTSSM_EXIT_FAILURE 1
#endif

/*
 * The function pointers for reading from and writing a seed file to
 * Non-Volatile storage (NV) in a platform-independent way
 *
 * Only enabled when the NV seed entropy source is enabled
 */
#if defined(ANTSSM_ENTROPY_NV_SEED)
#if !defined(ANTSSM_PLATFORM_NO_STD_FUNCTIONS) && defined(ANTSSM_FS_IO)
/* Internal standard platform definitions */
int mpaas_antssm_platform_std_nv_seed_read( unsigned char *buf, size_t buf_len );
int mpaas_antssm_platform_std_nv_seed_write( unsigned char *buf, size_t buf_len );
#endif

#if defined(ANTSSM_PLATFORM_NV_SEED_ALT)
extern int (*mpaas_antssm_nv_seed_read)( unsigned char *buf, size_t buf_len );
extern int (*mpaas_antssm_nv_seed_write)( unsigned char *buf, size_t buf_len );

/**
 * \brief   This function allows configuring custom seed file writing and
 *          reading functions.
 *
 * \param   nv_seed_read_func   The seed reading function implementation.
 * \param   nv_seed_write_func  The seed writing function implementation.
 *
 * \return  \c 0 on success.
 */
int mpaas_antssm_platform_set_nv_seed(
            int (*nv_seed_read_func)( unsigned char *buf, size_t buf_len ),
            int (*nv_seed_write_func)( unsigned char *buf, size_t buf_len )
            );
#else
#if defined(ANTSSM_PLATFORM_NV_SEED_READ_MACRO) && \
    defined(ANTSSM_PLATFORM_NV_SEED_WRITE_MACRO)
#define mpaas_antssm_nv_seed_read    ANTSSM_PLATFORM_NV_SEED_READ_MACRO
#define mpaas_antssm_nv_seed_write   ANTSSM_PLATFORM_NV_SEED_WRITE_MACRO
#else
#define mpaas_antssm_nv_seed_read    mpaas_antssm_platform_std_nv_seed_read
#define mpaas_antssm_nv_seed_write   mpaas_antssm_platform_std_nv_seed_write
#endif
#endif /* ANTSSM_PLATFORM_NV_SEED_ALT */
#endif /* ANTSSM_ENTROPY_NV_SEED */

#if !defined(ANTSSM_PLATFORM_SETUP_TEARDOWN_ALT)

/**
 * \brief   The platform context structure.
 *
 * \note    This structure may be used to assist platform-specific
 *          setup or teardown operations.
 */
typedef struct mpaas_antssm_platform_context
{
    char dummy; /**< A placeholder member, as empty structs are not portable. */
}
        mpaas_antssm_platform_context;

#else
#include "platform_alt.h"
#endif /* !ANTSSM_PLATFORM_SETUP_TEARDOWN_ALT */

/**
 * \brief   This function performs any platform-specific initialization
 *          operations.
 *
 * \note    This function should be called before any other library functions.
 *
 *          Its implementation is platform-specific, and unless
 *          platform-specific code is provided, it does nothing.
 *
 * \note    The usage and necessity of this function is dependent on the platform.
 *
 * \param   ctx     The platform context.
 *
 * \return  \c 0 on success.
 */
int mpaas_antssm_platform_setup( mpaas_antssm_platform_context *ctx );
/**
 * \brief   This function performs any platform teardown operations.
 *
 * \note    This function should be called after every other Mbed TLS module
 *          has been correctly freed using the appropriate free function.
 *
 *          Its implementation is platform-specific, and unless
 *          platform-specific code is provided, it does nothing.
 *
 * \note    The usage and necessity of this function is dependent on the platform.
 *
 * \param   ctx     The platform context.
 *
 */
void mpaas_antssm_platform_teardown( mpaas_antssm_platform_context *ctx );

#ifdef __cplusplus
}
#endif

#endif /* platform.h */
