/**
 * \file threading.h
 *
 * \brief Threading abstraction layer
 */
/*
 *  Copyright (C) 2006-2015, ARM Limited, All Rights Reserved
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
 *  This file is part of mbed TLS (https://tls.mbed.org)
 */
#ifndef ANTSSM_THREADING_H
#define ANTSSM_THREADING_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "antssm/config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ANTSSM_ERR_THREADING_FEATURE_UNAVAILABLE is deprecated and should not be
 * used. */
#define ANTSSM_ERR_THREADING_FEATURE_UNAVAILABLE         -0x001A  /**< The selected feature is not available. */

#define ANTSSM_ERR_THREADING_BAD_INPUT_DATA              -0x001C  /**< Bad input parameters to function. */
#define ANTSSM_ERR_THREADING_MUTEX_ERROR                 -0x001E  /**< Locking / unlocking / free failed with error code. */

#if defined(ANTSSM_THREADING_PTHREAD)
#include <pthread.h>
typedef struct mpaas_antssm_threading_mutex_t {
    pthread_mutex_t mutex;
    char is_valid;
} mpaas_antssm_threading_mutex_t;
#endif

#if defined(ANTSSM_THREADING_ALT)
/* You should define the mpaas_antssm_threading_mutex_t type in your header */
#include "threading_alt.h"

/**
 * \brief           Set your alternate threading implementation function
 *                  pointers and initialize global mutexes. If used, this
 *                  function must be called once in the main thread before any
 *                  other mbed TLS function is called, and
 *                  mpaas_antssm_threading_free_alt() must be called once in the main
 *                  thread after all other mbed TLS functions.
 *
 * \note            mutex_init() and mutex_free() don't return a status code.
 *                  If mutex_init() fails, it should leave its argument (the
 *                  mutex) in a state such that mutex_lock() will fail when
 *                  called with this argument.
 *
 * \param mutex_init    the init function implementation
 * \param mutex_free    the free function implementation
 * \param mutex_lock    the lock function implementation
 * \param mutex_unlock  the unlock function implementation
 */
void mpaas_antssm_threading_set_alt( void (*mutex_init)( mpaas_antssm_threading_mutex_t * ),
                       void (*mutex_free)( mpaas_antssm_threading_mutex_t * ),
                       int (*mutex_lock)( mpaas_antssm_threading_mutex_t * ),
                       int (*mutex_unlock)( mpaas_antssm_threading_mutex_t * ) );

/**
 * \brief               Free global mutexes.
 */
void mpaas_antssm_threading_free_alt( void );
#endif /* ANTSSM_THREADING_ALT */

#if defined(ANTSSM_THREADING_C)

/*
 * The function pointers for mutex_init, mutex_free, mutex_ and mutex_unlock
 *
 * All these functions are expected to work or the result will be undefined.
 */
extern void (*mpaas_antssm_mutex_init)(mpaas_antssm_threading_mutex_t *mutex);

extern void (*mpaas_antssm_mutex_free)(mpaas_antssm_threading_mutex_t *mutex);

extern int (*mpaas_antssm_mutex_lock)(mpaas_antssm_threading_mutex_t *mutex);

extern int (*mpaas_antssm_mutex_unlock)(mpaas_antssm_threading_mutex_t *mutex);

#if defined(ANTSSM_HAVE_TIME_DATE) && !defined(ANTSSM_PLATFORM_GMTIME_R_ALT)
/* This mutex may or may not be used in the default definition of
 * mpaas_antssm_platform_gmtime_r(), but in order to determine that,
 * we need to check POSIX features, hence modify _POSIX_C_SOURCE.
 * With the current approach, this declaration is orphaned, lacking
 * an accompanying definition, in case mpaas_antssm_platform_gmtime_r()
 * doesn't need it, but that's not a problem. */
extern mpaas_antssm_threading_mutex_t mpaas_antssm_threading_gmtime_mutex;
#endif /* ANTSSM_HAVE_TIME_DATE && !ANTSSM_PLATFORM_GMTIME_R_ALT */

#endif /* ANTSSM_THREADING_C */

#ifdef __cplusplus
}
#endif

#endif /* threading.h */
