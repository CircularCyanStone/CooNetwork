/**
 * \file config.h
 *
 * \brief Configuration options (set of defines)
 *
 *  This set of compile-time options may be used to enable
 *  or disable features selectively, and reduce the global
 *  memory footprint.
 *
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

#ifndef ANTSSM_CONFIG_H
#define ANTSSM_CONFIG_H

#if defined(_MSC_VER) && !defined(_CRT_SECURE_NO_DEPRECATE)
#define _CRT_SECURE_NO_DEPRECATE 1
#endif

//#define ANTSSM_LOG_ENTER_EXIT
#define SGD_ECDSA_SECP256K1_ALG

#define ANTSSM_HASHMAP_SECRET_ALIVE_TIME  (3600)
#define ANTSSM_HASHMAP_SECRET_INSPECT_CYCLE  (10)
//#define ANTSSM_HASHMAP_SECRET_AUTO_DESTROY


#ifdef WASM
    #include <emscripten/emscripten.h>
    #define API_EXPORT EMSCRIPTEN_KEEPALIVE
#else
    #define API_EXPORT __attribute__ ((visibility("default")))
#endif

#ifndef NOGLIBC225
#ifdef __linux__
// 支持CentOS 5.x 平台,使用老版本memcpy
__asm__(".symver memcpy,memcpy@GLIBC_2.2.5");
#endif
#endif


/**
 * \name SECTION: System support
 *
 * This section sets system specific settings.
 * \{
 */
/**
 * \def ANTANTSSM_VERSION_FEATURES 
 *
 * Allow run-time checking of compile-time enabled features. Thus allowing users
 * to check at run-time if the library is for instance compiled with threading
 * support via mpaas_antssm_version_check_feature().
 *
 * Module: library/version_features.c
 * Caller: None
 *
 * Requires: ANTSSM_VERSION_C
 *
 * Comment this to disable run-time checking and save ROM space
 */
#define ANTANTSSM_VERSION_FEATURES



/**
 * \def ANTSSM_SESSION_C
 *
 */
#define ANTSSM_SESSION_C

/**
 * \def ANTSSM_SESSION_KEY_C
 *
 * This module supports session
 *
 * Comment to disable the feature of session key
 */
// #define ANTSSM_SESSION_KEY_C

/**
 * \def ANTSSM_VERSION_C
 *
 * This module supports runtime version
 *
 * Comment to disable the feature of version
 */
#define ANTSSM_VERSION_C

/**
 * \def ANTSSM_VERSION_FEATURES
 *
 * Allow run-time checking of compile-time enabled features. Thus allowing users
 * to check at run-time if the library is for instance compiled with threading
 * support via mpaas_antssm_version_check_feature().
 *
 * Requires: ANTSSM_VERSION_C
 *
 * Comment this to disable run-time checking and save ROM space
 */
#define ANTSSM_VERSION_FEATURES

/**
 * \def ANTSSM_GM_TEST_C
 *
 * This module supports gm test
 *
 * Comment to disable the feature of gm test support
 */
// #define ANTSSM_GM_TEST_C
//

/**
 ** \def ANTSSM_GCM
 **
 ** This module supports gcm-sm4 debug made by lunda
 **
 ** Comment to disable gcm feature
 **/
#define ANTSSM_GCM
#define ANTSSM_GCM_SM4_FAST

//#define ANTSSM_LOG_DIGEST_C

/**
 * \def ANTSSM_HASHMAP_C
 *
 * This module supports hashmap
 *
 * Comment to disable the feature of hashmap
 */
#define ANTSSM_HASHMAP_C

/**
 * \def ANTSSM_THRESHOLD_C
 *
 * This module supports threshold cryptographic algorithm
 *
 * Comment to disable the feature of threshold cryptographic algorithm
 */
#define ANTSSM_THRESHOLD_C

// #define ANTSSM_THRESHOLD_STORE_KEY_SHARE

/**
 * \def ANTSSM_HAVE_ASM
 *
 * The compiler has support for asm().
 *
 * Requires support for asm() in compiler.
 *
 * Used in:
 *      library/timing.c
 *      library/padlock.c
 *      include/antssm/bn_mul.h
 *
 * Comment to disable the use of assembly code.
 */
// #define ANTSSM_HAVE_ASM

#define ANTSSM_ANT_CRYPTO_C

/**
 * \def ANTSSM_NO_UDBL_DIVISION
 *
 * The platform lacks support for double-width integer division (64-bit
 * division on a 32-bit platform, 128-bit division on a 64-bit platform).
 *
 * Used in:
 *      include/antssm/mpi.h
 *      library/mpi.c
 *
 * The mpi code uses double-width division to speed up some operations.
 * Double-width division is often implemented in software that needs to
 * be linked with the program. The presence of a double-width integer
 * type is usually detected automatically through preprocessor macros,
 * but the automatic detection cannot know whether the code needs to
 * and can be linked with an implementation of division for that type.
 * By default division is assumed to be usable if the type is present.
 * Uncomment this option to prevent the use of double-width division.
 *
 * Note that division for the native integer type is always required.
 * Furthermore, a 64-bit type is always required even on a 32-bit
 * platform, but it need not support multiplication or division. In some
 * cases it is also desirable to disable some double-width operations. For
 * example, if double-width division is implemented in software, disabling
 * it can reduce code size in some embedded targets.
 */
//#define ANTSSM_NO_UDBL_DIVISION

/**
 * \def ANTSSM_HAVE_SSE2
 *
 * CPU supports SSE2 instruction set.
 *
 * Uncomment if the CPU supports SSE2 (IA-32 specific).
 */
//#define ANTSSM_HAVE_SSE2

/**
 * \def ANTSSM_PLATFORM_MEMORY
 *
 * Enable the memory allocation layer.
 *
 * By default mbed TLS uses the system-provided calloc() and free().
 * This allows different allocators (self-implemented or provided) to be
 * provided to the platform abstraction layer.
 *
 * Enabling ANTSSM_PLATFORM_MEMORY without the
 * ANTSSM_PLATFORM_{FREE,CALLOC}_MACROs will provide
 * "mpaas_antssm_platform_set_calloc_free()" allowing you to set an alternative calloc() and
 * free() function pointer at runtime.
 *
 * Enabling ANTSSM_PLATFORM_MEMORY and specifying
 * ANTSSM_PLATFORM_{CALLOC,FREE}_MACROs will allow you to specify the
 * alternate function at compile time.
 *
 * Requires: ANTSSM_PLATFORM_C
 *
 * Enable this layer to allow use of alternative memory allocators.
 */
// #define ANTSSM_PLATFORM_MEMORY

/**
 * \def ANTSSM_PLATFORM_NO_STD_FUNCTIONS
 *
 * Do not assign standard functions in the platform layer (e.g. calloc() to
 * ANTSSM_PLATFORM_STD_CALLOC and printf() to ANTSSM_PLATFORM_STD_PRINTF)
 *
 * This makes sure there are no linking errors on platforms that do not support
 * these functions. You will HAVE to provide alternatives, either at runtime
 * via the platform_set_xxx() functions or at compile time by setting
 * the ANTSSM_PLATFORM_STD_XXX defines, or enabling a
 * ANTSSM_PLATFORM_XXX_MACRO.
 *
 * Requires: ANTSSM_PLATFORM_C
 *
 * Uncomment to prevent default assignment of standard functions in the
 * platform layer.
 */
//#define ANTSSM_PLATFORM_NO_STD_FUNCTIONS

/**
 * \def ANTSSM_PLATFORM_EXIT_ALT
 *
 * ANTSSM_PLATFORM_XXX_ALT: Uncomment a macro to let mbed TLS support the
 * function in the platform abstraction layer.
 *
 * Example: In case you uncomment ANTSSM_PLATFORM_PRINTF_ALT, mbed TLS will
 * provide a function "mpaas_antssm_platform_set_printf()" that allows you to set an
 * alternative printf function pointer.
 *
 * All these define require ANTSSM_PLATFORM_C to be defined!
 *
 * \note ANTSSM_PLATFORM_SNPRINTF_ALT is required on Windows;
 * it will be enabled automatically by check_config.h
 *
 * \warning ANTSSM_PLATFORM_XXX_ALT cannot be defined at the same time as
 * ANTSSM_PLATFORM_XXX_MACRO!
 *
 * Requires: ANTSSM_PLATFORM_TIME_ALT requires ANTSSM_HAVE_TIME
 *
 * Uncomment a macro to enable alternate implementation of specific base
 * platform function
 */
//#define ANTSSM_PLATFORM_EXIT_ALT
//#define ANTSSM_PLATFORM_TIME_ALT
//#define ANTSSM_PLATFORM_FPRINTF_ALT
//#define ANTSSM_PLATFORM_PRINTF_ALT
//#define ANTSSM_PLATFORM_SNPRINTF_ALT
//#define ANTSSM_PLATFORM_NV_SEED_ALT
//#define ANTSSM_PLATFORM_SETUP_TEARDOWN_ALT

/**
 * \def ANTSSM_DEPRECATED_WARNING
 *
 * Mark deprecated functions so that they generate a warning if used.
 * Functions deprecated in one version will usually be removed in the next
 * version. You can enable this to help you prepare the transition to a new
 * major version by making sure your code is not using these functions.
 *
 * This only works with GCC and Clang. With other compilers, you may want to
 * use ANTSSM_DEPRECATED_REMOVED
 *
 * Uncomment to get warnings on using deprecated functions.
 */
// #define ANTSSM_DEPRECATED_WARNING

/**
 * \def ANTSSM_DEPRECATED_REMOVED
 *
 * Remove deprecated functions so that they generate an error if used.
 * Functions deprecated in one version will usually be removed in the next
 * version. You can enable this to help you prepare the transition to a new
 * major version by making sure your code is not using these functions.
 *
 * Uncomment to get errors on using deprecated functions.
 */
//#define ANTSSM_DEPRECATED_REMOVED

/* \} name SECTION: System support */

/**
 * \name SECTION: mbed TLS feature support
 *
 * This section sets support for features that are or are not needed
 * within the modules that are enabled.
 * \{
 */

/**
 * \def ANTSSM_TIMING_ALT
 *
 * Uncomment to provide your own alternate implementation for mpaas_antssm_timing_hardclock(),
 * mpaas_antssm_timing_get_timer(), mpaas_antssm_set_alarm(), mpaas_antssm_set/get_delay()
 *
 * Only works if you have ANTSSM_TIMING_C enabled.
 *
 * You will need to provide a header "timing_alt.h" and an implementation at
 * compile time.
 */
//#define ANTSSM_TIMING_ALT

/**
 * \def ANTSSM_AES_ALT
 *
 * ANTSSM__MODULE_NAME__ALT: Uncomment a macro to let mbed TLS use your
 * alternate core implementation of a symmetric crypto, an arithmetic or hash
 * module (e.g. platform specific assembly optimized implementations). Keep
 * in mind that the function prototypes should remain the same.
 *
 * This replaces the whole module. If you only want to replace one of the
 * functions, use one of the ANTSSM__FUNCTION_NAME__ALT flags.
 *
 * Example: In case you uncomment ANTSSM_AES_ALT, mbed TLS will no longer
 * provide the "struct mpaas_antssm_aes_context_t" definition and omit the base
 * function declarations and implementations. "aes_alt.h" will be included from
 * "aes.h" to include the new function definitions.
 *
 * Uncomment a macro to enable alternate implementation of the corresponding
 * module.
 */
//#define ANTSSM_AES_ALT
//#define ANTSSM_ARC4_ALT
//#define ANTSSM_BLOWFISH_ALT
//#define ANTSSM_CAMELLIA_ALT
//#define ANTSSM_DES_ALT
//#define ANTSSM_XTEA_ALT
//#define ANTSSM_MD2_ALT
//#define ANTSSM_MD4_ALT
//#define ANTSSM_MD5_ALT
//#define ANTSSM_RIPEMD160_ALT
//#define ANTSSM_SHA1_ALT
//#define ANTSSM_SHA256_ALT
//#define ANTSSM_SHA512_ALT
/*
 * When replacing the elliptic curve module, pleace consider, that it is
 * implemented with two .c files:
 *      - ecp.c
 *      - ecp_curves.c
 * You can replace them very much like all the other ANTSSM__MODULE_NAME__ALT
 * macros as described above. The only difference is that you have to make sure
 * that you provide functionality for both .c files.
 */
//#define ANTSSM_ECP_ALT

/**
 * \def ANTSSM_MD2_PROCESS_ALT
 *
 * ANTSSM__FUNCTION_NAME__ALT: Uncomment a macro to let mbed TLS use you
 * alternate core implementation of symmetric crypto or hash function. Keep in
 * mind that function prototypes should remain the same.
 *
 * This replaces only one function. The header file from mbed TLS is still
 * used, in contrast to the ANTSSM__MODULE_NAME__ALT flags.
 *
 * Example: In case you uncomment ANTSSM_SHA256_PROCESS_ALT, mbed TLS will
 * no longer provide the mpaas_antssm_sha1_process() function, but it will still provide
 * the other function (using your mpaas_antssm_sha1_process() function) and the definition
 * of mpaas_antssm_sha1_context, so your implementation of mpaas_antssm_sha1_process must be compatible
 * with this definition.
 *
 * \note Because of a signature change, the core AES encryption and decryption routines are
 *       currently named mpaas_antssm_aes_internal_encrypt and mpaas_antssm_aes_internal_decrypt,
 *       respectively. When setting up alternative implementations, these functions should
 *       be overriden, but the wrapper functions mpaas_antssm_aes_decrypt and mpaas_antssm_aes_encrypt
 *       must stay untouched.
 *
 * \note If you use the AES_xxx_ALT macros, then is is recommended to also set
 *       ANTSSM_AES_ROM_TABLES in order to help the linker garbage-collect the AES
 *       tables.
 *
 * Uncomment a macro to enable alternate implementation of the corresponding
 * function.
 */
//#define ANTSSM_MD2_PROCESS_ALT
//#define ANTSSM_MD4_PROCESS_ALT
//#define ANTSSM_MD5_PROCESS_ALT
//#define ANTSSM_RIPEMD160_PROCESS_ALT
//#define ANTSSM_SHA1_PROCESS_ALT
//#define ANTSSM_SHA256_PROCESS_ALT
//#define ANTSSM_SHA512_PROCESS_ALT
//#define ANTSSM_DES_SETKEY_ALT
//#define ANTSSM_DES_CRYPT_ECB_ALT
//#define ANTSSM_DES3_CRYPT_ECB_ALT
//#define ANTSSM_AES_SETKEY_ENC_ALT
//#define ANTSSM_AES_SETKEY_DEC_ALT
//#define ANTSSM_AES_ENCRYPT_ALT
//#define ANTSSM_AES_DECRYPT_ALT

/**
 * \def ANTSSM_ECP_INTERNAL_ALT
 *
 * Expose a part of the internal interface of the Elliptic Curve Point module.
 *
 * ANTSSM_ECP__FUNCTION_NAME__ALT: Uncomment a macro to let mbed TLS use your
 * alternative core implementation of elliptic curve arithmetic. Keep in mind
 * that function prototypes should remain the same.
 *
 * This partially replaces one function. The header file from mbed TLS is still
 * used, in contrast to the ANTSSM_ECP_ALT flag. The original implementation
 * is still present and it is used for group structures not supported by the
 * alternative.
 *
 * Any of these options become available by defining ANTSSM_ECP_INTERNAL_ALT
 * and implementing the following functions:
 *      unsigned char mpaas_antssm_internal_ecp_grp_capable(
 *          const mpaas_antssm_ecp_group_t *grp )
 *      int  mpaas_antssm_internal_ecp_init( const mpaas_antssm_ecp_group_t *grp )
 *      void mpaas_antssm_internal_ecp_deinit( const mpaas_antssm_ecp_group_t *grp )
 * The mpaas_antssm_internal_ecp_grp_capable function should return 1 if the
 * replacement functions implement arithmetic for the given group and 0
 * otherwise.
 * The functions mpaas_antssm_internal_ecp_init and mpaas_antssm_internal_ecp_deinit are
 * called before and after each point operation and provide an opportunity to
 * implement optimized set up and tear down instructions.
 *
 * Example: In case you uncomment ANTSSM_ECP_INTERNAL_ALT and
 * ANTSSM_ECP_DOUBLE_JAC_ALT, mbed TLS will still provide the ecp_double_jac
 * function, but will use your mpaas_antssm_internal_ecp_double_jac if the group is
 * supported (your mpaas_antssm_internal_ecp_grp_capable function returns 1 when
 * receives it as an argument). If the group is not supported then the original
 * implementation is used. The other functions and the definition of
 * mpaas_antssm_ecp_group_t and mpaas_antssm_ecp_point_t will not change, so your
 * implementation of mpaas_antssm_internal_ecp_double_jac and
 * mpaas_antssm_internal_ecp_grp_capable must be compatible with this definition.
 *
 * Uncomment a macro to enable alternate implementation of the corresponding
 * function.
 */
/* Required for all the functions in this section */
//#define ANTSSM_ECP_INTERNAL_ALT
/* Support for Weierstrass curves with Jacobi representation */
//#define ANTSSM_ECP_RANDOMIZE_JAC_ALT
//#define ANTSSM_ECP_ADD_MIXED_ALT
//#define ANTSSM_ECP_DOUBLE_JAC_ALT
//#define ANTSSM_ECP_NORMALIZE_JAC_MANY_ALT
//#define ANTSSM_ECP_NORMALIZE_JAC_ALT
/* Support for curves with Montgomery arithmetic */
//#define ANTSSM_ECP_DOUBLE_ADD_MXZ_ALT
//#define ANTSSM_ECP_RANDOMIZE_MXZ_ALT
//#define ANTSSM_ECP_NORMALIZE_MXZ_ALT

/**
 * \def ANTSSM_TEST_NULL_ENTROPY
 *
 * Enables testing and use of mbed TLS without any configured entropy sources.
 * This permits use of the library on platforms before an entropy source has
 * been integrated (see for example the ANTSSM_ENTROPY_HARDWARE_ALT or the
 * ANTSSM_ENTROPY_NV_SEED switches).
 *
 * WARNING! This switch MUST be disabled in production builds, and is suitable
 * only for development.
 * Enabling the switch negates any security provided by the library.
 *
 * Requires ANTSSM_ENTROPY_C, ANTSSM_NO_DEFAULT_ENTROPY_SOURCES
 *
 */
//#define ANTSSM_TEST_NULL_ENTROPY

/**
 * \def ANTSSM_ENTROPY_HARDWARE_ALT
 *
 * Uncomment this macro to let mbed TLS use your own implementation of a
 * hardware entropy collector.
 *
 * Your function must be called \c mpaas_antssm_hardware_poll(), have the same
 * prototype as declared in entropy_poll.h, and accept NULL as first argument.
 *
 * Uncomment to use your own hardware entropy collector.
 */
//#define ANTSSM_ENTROPY_HARDWARE_ALT

/**
 * \def ANTSSM_AES_ROM_TABLES
 *
 * Store the AES tables in ROM.
 *
 * Uncomment this macro to store the AES tables in ROM.
 */
// #define ANTSSM_AES_ROM_TABLES

/**
 * \def ANTSSM_CAMELLIA_SMALL_MEMORY
 *
 * Use less ROM for the Camellia implementation (saves about 768 bytes).
 *
 * Uncomment this macro to use less memory for Camellia.
 */
// #define ANTSSM_CAMELLIA_SMALL_MEMORY

/**
 * \def ANTSSM_CIPHER_MODE_CBC
 *
 * Enable Cipher Block Chaining mode (CBC) for symmetric ciphers.
 */
#define ANTSSM_CIPHER_MODE_CBC

/**
 * \def ANTSSM_CIPHER_MODE_CFB
 *
 * Enable Cipher Feedback mode (CFB) for symmetric ciphers.
 */
#define ANTSSM_CIPHER_MODE_CFB

/**
 * \def ANTSSM_CIPHER_MODE_OFB
 *
 * Enable Output Feedback mode (OFB) for symmetric ciphers.
 */
//#define ANTSSM_CIPHER_MODE_OFB

/**
 * \def ANTSSM_CIPHER_MODE_CTR
 *
 * Enable Counter Block Cipher mode (CTR) for symmetric ciphers.
 */
#define ANTSSM_CIPHER_MODE_CTR

/**
 * \def ANTSSM_CIPHER_MODE_XTS
 *
 * Enable XEX encryption mode with tweak and ciphertext stealing (XTS) for symmetric ciphers.
 */
#define ANTSSM_CIPHER_MODE_XTS

/**
 * not support aes_xts yet, only sm4_xts
 */
//#define ATSSM_CIPHER_MODE_XTS_AES

/**
 * \def ANTSSM_CIPHER_NULL_CIPHER
 *
 * Enable NULL cipher.
 * Warning: Only do so when you know what you are doing. This allows for
 * encryption or channels without any security!
 *
 * Requires ANTSSM_ENABLE_WEmpaas_AK_CIPHERSUITES as well to enable
 * the following ciphersuites:
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_NULL_SHA
 *      ANTSSM_TLS_ECDH_RSA_WITH_NULL_SHA
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_NULL_SHA
 *      ANTSSM_TLS_ECDHE_RSA_WITH_NULL_SHA
 *      ANTSSM_TLS_ECDHE_PSK_WITH_NULL_SHA384
 *      ANTSSM_TLS_ECDHE_PSK_WITH_NULL_SHA256
 *      ANTSSM_TLS_ECDHE_PSK_WITH_NULL_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_NULL_SHA384
 *      ANTSSM_TLS_DHE_PSK_WITH_NULL_SHA256
 *      ANTSSM_TLS_DHE_PSK_WITH_NULL_SHA
 *      ANTSSM_TLS_RSA_WITH_NULL_SHA256
 *      ANTSSM_TLS_RSA_WITH_NULL_SHA
 *      ANTSSM_TLS_RSA_WITH_NULL_MD5
 *      ANTSSM_TLS_RSA_PSK_WITH_NULL_SHA384
 *      ANTSSM_TLS_RSA_PSK_WITH_NULL_SHA256
 *      ANTSSM_TLS_RSA_PSK_WITH_NULL_SHA
 *      ANTSSM_TLS_PSK_WITH_NULL_SHA384
 *      ANTSSM_TLS_PSK_WITH_NULL_SHA256
 *      ANTSSM_TLS_PSK_WITH_NULL_SHA
 *
 * Uncomment this macro to enable the NULL cipher and ciphersuites
 */
// #define ANTSSM_CIPHER_NULL_CIPHER

/**
 * \def ANTSSM_CIPHER_PADDING_PKCS7
 *
 * ANTSSM_CIPHER_PADDING_XXX: Uncomment or comment macros to add support for
 * specific padding modes in the cipher layer with cipher modes that support
 * padding (e.g. CBC)
 *
 * If you disable all padding modes, only full blocks can be used with CBC.
 *
 * Enable padding modes in the cipher layer.
 */
#define ANTSSM_CIPHER_PADDING_PKCS7
#define ANTSSM_CIPHER_PADDING_ONE_AND_ZEROS
#define ANTSSM_CIPHER_PADDING_ZEROS_AND_LEN
#define ANTSSM_CIPHER_PADDING_ZEROS

/**
 * \def ANTSSM_ECP_DP_SECP192R1_ENABLED
 *
 * ANTSSM_ECP_XXXX_ENABLED: Enables specific curves within the Elliptic Curve
 * module.  By default all supported curves are enabled.
 *
 * Comment macros to disable the curve and functions for it
 */
#define ANTSSM_ECP_DP_SECP192R1_ENABLED
// #define ANTSSM_ECP_DP_SECP224R1_ENABLED
#define ANTSSM_ECP_DP_SECP256R1_ENABLED
// #define ANTSSM_ECP_DP_SECP384R1_ENABLED
// #define ANTSSM_ECP_DP_SECP521R1_ENABLED
// #define ANTSSM_ECP_DP_SECP192K1_ENABLED
// #define ANTSSM_ECP_DP_SECP224K1_ENABLED
#define ANTSSM_ECP_DP_SECP256K1_ENABLED
#define ANTSSM_ECP_DP_BP256R1_ENABLED
// #define ANTSSM_ECP_DP_BP384R1_ENABLED
// #define ANTSSM_ECP_DP_BP512R1_ENABLED
// #define ANTSSM_ECP_DP_CURVE25519_ENABLED
#define ANTSSM_ECP_DP_SM2_ENABLED

/**
 * \def ANTSSM_ECP_NIST_OPTIM
 *
 * Enable specific 'modulo p' routines for each NIST prime.
 * Depending on the prime and architecture, makes operations 4 to 8 times
 * faster on the corresponding curve.
 *
 * Comment this macro to disable NIST curves optimisation.
 */
#define ANTSSM_ECP_NIST_OPTIM

/**
 * \def ANTSSM_KEY_EXCHANGE_PSK_ENABLED
 *
 * Enable the PSK based ciphersuite modes in SSL / TLS.
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_PSK_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_PSK_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_PSK_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_PSK_WITH_CAMELLIA_256_GCM_SHA384
 *      ANTSSM_TLS_PSK_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_PSK_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_PSK_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_PSK_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_PSK_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_PSK_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_PSK_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_PSK_WITH_RC4_128_SHA
 */
// #define ANTSSM_KEY_EXCHANGE_PSK_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_DHE_PSK_ENABLED
 *
 * Enable the DHE-PSK based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_DHM_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_CAMELLIA_256_GCM_SHA384
 *      ANTSSM_TLS_DHE_PSK_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_DHE_PSK_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_RC4_128_SHA
 */
// #define ANTSSM_KEY_EXCHANGE_DHE_PSK_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_ECDHE_PSK_ENABLED
 *
 * Enable the ECDHE-PSK based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_ECDH_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDHE_PSK_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDHE_PSK_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_PSK_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDHE_PSK_WITH_RC4_128_SHA
 */
// #define ANTSSM_KEY_EXCHANGE_ECDHE_PSK_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_RSA_PSK_ENABLED
 *
 * Enable the RSA-PSK based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_RSA_C, ANTSSM_PKCS1_V15,
 *           ANTSSM_X509_CRT_PARSE_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_RSA_PSK_WITH_CAMELLIA_256_GCM_SHA384
 *      ANTSSM_TLS_RSA_PSK_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_RSA_PSK_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_RSA_PSK_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_RSA_PSK_WITH_RC4_128_SHA
 */
// #define ANTSSM_KEY_EXCHANGE_RSA_PSK_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_RSA_ENABLED
 *
 * Enable the RSA-only based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_RSA_C, ANTSSM_PKCS1_V15,
 *           ANTSSM_X509_CRT_PARSE_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_RSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_RSA_WITH_AES_256_CBC_SHA256
 *      ANTSSM_TLS_RSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_RSA_WITH_CAMELLIA_256_GCM_SHA384
 *      ANTSSM_TLS_RSA_WITH_CAMELLIA_256_CBC_SHA256
 *      ANTSSM_TLS_RSA_WITH_CAMELLIA_256_CBC_SHA
 *      ANTSSM_TLS_RSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_RSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_RSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_RSA_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_RSA_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_RSA_WITH_CAMELLIA_128_CBC_SHA
 *      ANTSSM_TLS_RSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_RSA_WITH_RC4_128_SHA
 *      ANTSSM_TLS_RSA_WITH_RC4_128_MD5
 */
// #define ANTSSM_KEY_EXCHANGE_RSA_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_DHE_RSA_ENABLED
 *
 * Enable the DHE-RSA based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_DHM_C, ANTSSM_RSA_C, ANTSSM_PKCS1_V15,
 *           ANTSSM_X509_CRT_PARSE_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_256_CBC_SHA256
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_DHE_RSA_WITH_CAMELLIA_256_GCM_SHA384
 *      ANTSSM_TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA256
 *      ANTSSM_TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_DHE_RSA_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA
 *      ANTSSM_TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA
 */
// #define ANTSSM_KEY_EXCHANGE_DHE_RSA_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_ECDHE_RSA_ENABLED
 *
 * Enable the ECDHE-RSA based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_ECDH_C, ANTSSM_RSA_C, ANTSSM_PKCS1_V15,
 *           ANTSSM_X509_CRT_PARSE_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDHE_RSA_WITH_CAMELLIA_256_GCM_SHA384
 *      ANTSSM_TLS_ECDHE_RSA_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDHE_RSA_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_ECDHE_RSA_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDHE_RSA_WITH_RC4_128_SHA
 */
// #define ANTSSM_KEY_EXCHANGE_ECDHE_RSA_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_ECDHE_ECDSA_ENABLED
 *
 * Enable the ECDHE-ECDSA based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_ECDH_C, ANTSSM_ECDSA_C, ANTSSM_X509_CRT_PARSE_C,
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_CAMELLIA_256_GCM_SHA384
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_RC4_128_SHA
 */
// #define ANTSSM_KEY_EXCHANGE_ECDHE_ECDSA_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_ECDH_ECDSA_ENABLED
 *
 * Enable the ECDH-ECDSA based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_ECDH_C, ANTSSM_X509_CRT_PARSE_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_RC4_128_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_256_GCM_SHA384
 */
// #define ANTSSM_KEY_EXCHANGE_ECDH_ECDSA_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_ECC_SM2DSA_ENABLED
 *
 * Enable the SM2-ECDSA based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_ECDH_C, ANTSSM_X509_CRT_PARSE_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_RC4_128_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_256_GCM_SHA384
 */
#define ANTSSM_KEY_EXCHANGE_ECC_SM2DSA_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_SM2DH_SM2DSA_ENABLED
 *
 * Enable the SM2-ECDSA based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_ECDH_C, ANTSSM_X509_CRT_PARSE_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_RC4_128_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_CAMELLIA_256_GCM_SHA384
 */
#define ANTSSM_KEY_EXCHANGE_SM2DH_SM2DSA_ENABLED


/**
 * \def ANTSSM_KEY_EXCHANGE_ECDH_RSA_ENABLED
 *
 * Enable the ECDH-RSA based ciphersuite modes in SSL / TLS.
 *
 * Requires: ANTSSM_ECDH_C, ANTSSM_X509_CRT_PARSE_C
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDH_RSA_WITH_RC4_128_SHA
 *      ANTSSM_TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDH_RSA_WITH_CAMELLIA_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_RSA_WITH_CAMELLIA_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_RSA_WITH_CAMELLIA_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_RSA_WITH_CAMELLIA_256_GCM_SHA384
 */
// #define ANTSSM_KEY_EXCHANGE_ECDH_RSA_ENABLED

/**
 * \def ANTSSM_KEY_EXCHANGE_ECJPAKE_ENABLED
 *
 * Enable the ECJPAKE based ciphersuite modes in SSL / TLS.
 *
 * \warning This is currently experimental. EC J-PAKE support is based on the
 * Thread v1.0.0 specification; incompatible changes to the specification
 * might still happen. For this reason, this is disabled by default.
 *
 * Requires: ANTSSM_ECJPAKE_C
 *           ANTSSM_SHA256_C
 *           ANTSSM_ECP_DP_SECP256R1_ENABLED
 *
 * This enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECJPAKE_WITH_AES_128_CCM_8
 */
// #define ANTSSM_KEY_EXCHANGE_ECJPAKE_ENABLED

/**
 * \def ANTSSM_PK_PARSE_EC_EXTENDED
 *
 * Enhance support for reading EC keys using variants of SEC1 not allowed by
 * RFC 5915 and RFC 5480.
 *
 * Currently this means parsing the SpecifiedECDomain choice of EC
 * parameters (only known groups are supported, not arbitrary domains, to
 * avoid validation issues).
 *
 * Disable if you only need to support RFC 5915 + 5480 key formats.
 */
#define ANTSSM_PK_PARSE_EC_EXTENDED

/**
 * \def ANTSSM_ERROR_STRERROR_DUMMY
 *
 * Enable a dummy error function to make use of mpaas_antssm_strerror() in
 * third party libraries easier when ANTSSM_ERROR_C is disabled
 * (no effect when ANTSSM_ERROR_C is enabled).
 *
 * You can safely disable this if ANTSSM_ERROR_C is enabled, or if you're
 * not using mpaas_antssm_strerror() or error_strerror() in your application.
 *
 * Disable if you run into name conflicts and want to really remove the
 * mpaas_antssm_strerror()
 */
#define ANTSSM_ERROR_STRERROR_DUMMY

/**
 * \def ANTSSM_GENPRIME
 *
 * Enable the prime-number generation code.
 *
 * Requires: ANTSSM_MPI_C
 */
#define ANTSSM_GENPRIME

/**
 * \def ANTSSM_FS_IO
 *
 * Enable functions that use the filesystem.
 */
// #define ANTSSM_FS_IO

/**
 * \def ANTSSM_NO_DEFAULT_ENTROPY_SOURCES
 *
 * Do not add default entropy sources. These are the platform specific,
 * mpaas_antssm_timing_hardclock and HAVEGE based poll functions.
 *
 * This is useful to have more control over the added entropy sources in an
 * application.
 *
 * Uncomment this macro to prevent loading of default entropy functions.
 */
//#define ANTSSM_NO_DEFAULT_ENTROPY_SOURCES

/**
 * \def ANTSSM_NO_PLATFORM_ENTROPY
 *
 * Do not use built-in platform entropy functions.
 * This is useful if your platform does not support
 * standards like the /dev/urandom or Windows CryptoAPI.
 *
 * Uncomment this macro to disable the built-in platform entropy functions.
 */
//#define ANTSSM_NO_PLATFORM_ENTROPY

/**
 * \def ANTSSM_ENTROPY_FORCE_SHA256
 *
 * Force the entropy accumulator to use a SHA-256 accumulator instead of the
 * default SHA-512 based one (if both are available).
 *
 * Requires: ANTSSM_SHA256_C
 *
 * On 32-bit systems SHA-256 can be much faster than SHA-512. Use this option
 * if you have performance concerns.
 *
 * This option is only useful if both ANTSSM_SHA256_C and
 * ANTSSM_SHA512_C are defined. Otherwise the available hash module is used.
 */
// #define ANTSSM_ENTROPY_FORCE_SHA256

/**
 * \def ANTSSM_MEMORY_DEBUG
 *
 * Enable debugging of buffer allocator memory issues. Automatically prints
 * (to stderr) all (fatal) messages on memory allocation issues. Enables
 * function for 'debug output' of allocated memory.
 *
 * Requires: ANTSSM_MEMORY_BUFFER_ALLOC_C
 *
 * Uncomment this macro to let the buffer allocator print out error messages.
 */
//#define ANTSSM_MEMORY_DEBUG

/**
 * \def ANTSSM_MEMORY_BACKTRACE
 *
 * Include backtrace information with each allocated block.
 *
 * Requires: ANTSSM_MEMORY_BUFFER_ALLOC_C
 *           GLIBC-compatible backtrace() an backtrace_symbols() support
 *
 * Uncomment this macro to include backtrace information
 */
//#define ANTSSM_MEMORY_BACKTRACE

/**
 * \def ANTSSM_MEMORY_BUFFER_ALLOC_C
 *
 * Enable the buffer allocator implementation that makes use of a (stack)
 * based buffer to 'allocate' dynamic memory. (replaces calloc() and free()
 * calls)
 *
 * Module:  library/memory_buffer_alloc.c
 *
 * Requires: ANTSSM_PLATFORM_C
 *           ANTSSM_PLATFORM_MEMORY (to use it within mbed TLS)
 *
 * Enable this module to enable the buffer memory allocator.
 */
//#define ANTSSM_MEMORY_BUFFER_ALLOC_C

/**
 * \def ANTSSM_OID_C
 *
 * Enable the OID database.
 *
 * Module:  library/oid.c
 * Caller:  library/pkcs5.c
 *          library/pkparse.c
 *          library/pkwrite.c
 *          library/rsa.c
 *
 * This modules translates between OIDs and internal values.
 */
#define ANTSSM_OID_C

#define ANTSSM_FORMAT_C

/**
 * \def ANTSSM_PEM_PARSE_C
 *
 * Enable PEM decoding / parsing.
 *
 * Module:  library/pem.c
 * Caller:  library/dhm.c
 *          library/pkparse.c
 *
 * Requires: ANTSSM_BASE64_C
 *
 * This modules adds support for decoding / parsing PEM files.
 */
#define ANTSSM_PEM_PARSE_C

/**
 * \def ANTSSM_PEM_WRITE_C
 *
 * Enable PEM encoding / writing.
 *
 * Module:  library/pem.c
 * Caller:  library/pkwrite.c
 *
 * Requires: ANTSSM_BASE64_C
 *
 * This modules adds support for encoding / writing PEM files.
 */
#define ANTSSM_PEM_WRITE_C

/**
 * \def ANTSSM_PK_RSA_ALT_SUPPORT
 *
 * Support external private RSA keys (eg from a HSM) in the PK layer.
 *
 * Comment this macro to disable support for external private RSA keys.
 */
#define ANTSSM_PK_RSA_ALT_SUPPORT

/**
 * \def ANTSSM_PKCS1_V15
 *
 * Enable support for PKCS#1 v1.5 encoding.
 *
 * Requires: ANTSSM_RSA_C
 *
 * This enables support for PKCS#1 v1.5 operations.
 */
#define ANTSSM_PKCS1_V15

/**
 * \def ANTSSM_PKCS1_V21
 *
 * Enable support for PKCS#1 v2.1 encoding.
 *
 * Requires: ANTSSM_MD_C, ANTSSM_RSA_C
 *
 * This enables support for RSAES-OAEP and RSASSA-PSS operations.
 */
// #define ANTSSM_PKCS1_V21

/**
 * \def ANTSSM_RSA_NO_CRT
 *
 * Do not use the Chinese Remainder Theorem for the RSA private operation.
 *
 * Uncomment this macro to disable the use of CRT in RSA.
 *
 */
//#define ANTSSM_RSA_NO_CRT

/**
 * \def ANTSSM_SELF_TEST
 *
 * Enable the checkup functions (*_self_test).
 */
// #define ANTSSM_SELF_TEST

/**
 * \def ANTSSM_SHA256_SMALLER
 *
 * Enable an implementation of SHA-256 that has lower ROM footprint but also
 * lower performance.
 *
 * The default implementation is meant to be a reasonnable compromise between
 * performance and size. This version optimizes more aggressively for size at
 * the expense of performance. Eg on Cortex-M4 it reduces the size of
 * mpaas_antssm_sha256_process() from ~2KB to ~0.5KB for a performance hit of about
 * 30%.
 *
 * Uncomment to enable the smaller implementation of SHA256.
 */
// #define ANTSSM_SHA256_SMALLER

/**
 * \def ANTSSM_THREADING_ALT
 *
 * Provide your own alternate threading implementation.
 *
 * Requires: ANTSSM_THREADING_C
 *
 * Uncomment this to allow your own alternate threading implementation.
 */
//#define ANTSSM_THREADING_ALT

/**
 * \def ANTSSM_THREADING_PTHREAD
 *
 * Enable the pthread wrapper layer for the threading layer.
 *
 * Requires: ANTSSM_THREADING_C
 *
 * Uncomment this to enable pthread mutexes.
 */
// #define ANTSSM_THREADING_PTHREAD

/**
 * \def ANTANTSSM_VERSION_FEATURES
 *
 * Allow run-time checking of compile-time enabled features. Thus allowing users
 * to check at run-time if the library is for instance compiled with threading
 * support via mpaas_antssm_version_check_feature().
 *
 * Requires: ANTSSM_VERSION_C
 *
 * Comment this to disable run-time checking and save ROM space
 */
#define ANTANTSSM_VERSION_FEATURES
/* \} name SECTION: mbed TLS feature support */

/**
 * \name SECTION: mbed TLS modules
 *
 * This section enables or disables entire modules in mbed TLS
 * \{
 */

/**
 * \def ANTSSM_AESNI_C
 *
 * Enable AES-NI support on x86-64.
 *
 * Module:  library/aesni.c
 * Caller:  library/aes.c
 *
 * Requires: ANTSSM_HAVE_ASM
 *
 * This modules adds support for the AES-NI instructions on x86-64
 */
// #define ANTSSM_AESNI_C

/**
 * \def ANTSSM_AES_C
 *
 * Enable the AES block cipher.
 *
 * Module:  library/aes.c
 * Caller:  library/ssl_tls.c
 *          library/pem.c
 *          library/ctr_drbg.c
 *
 * This module enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_256_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_DHE_RSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_RSA_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_RSA_WITH_AES_256_CBC_SHA256
 *      ANTSSM_TLS_RSA_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_RSA_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_RSA_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_RSA_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_RSA_PSK_WITH_AES_128_CBC_SHA
 *      ANTSSM_TLS_PSK_WITH_AES_256_GCM_SHA384
 *      ANTSSM_TLS_PSK_WITH_AES_256_CBC_SHA384
 *      ANTSSM_TLS_PSK_WITH_AES_256_CBC_SHA
 *      ANTSSM_TLS_PSK_WITH_AES_128_GCM_SHA256
 *      ANTSSM_TLS_PSK_WITH_AES_128_CBC_SHA256
 *      ANTSSM_TLS_PSK_WITH_AES_128_CBC_SHA
 *
 * PEM_PARSE uses AES for decrypting encrypted keys.
 */
#define ANTSSM_AES_C

/**
 * \def ANTSSM_ASN1_PARSE_C
 *
 * Enable the generic ASN1 parser.
 *
 * Module:  library/asn1parse.c
 * Caller:  library/pkcs5.c
 *          library/pkparse.c
 */
#define ANTSSM_ASN1_PARSE_C

/**
 * \def ANTSSM_ASN1_WRITE_C
 *
 * Enable the generic ASN1 writer.
 *
 * Module:  library/asn1write.c
 * Caller:  library/ecdsa.c
 *          library/pkwrite.c
 */
#define ANTSSM_ASN1_WRITE_C

/**
 * \def ANTSSM_BASE64_C
 *
 * Enable the Base64 module.
 *
 * Module:  library/base64.c
 * Caller:  library/pem.c
 *
 * This module is required for PEM support (required by X.509).
 */
#define ANTSSM_BASE64_C

/**
 * \def ANTSSM_MPI_C
 *
 * Enable the multi-precision integer library.
 *
 * Module:  library/mpi.c
 * Caller:  library/dhm.c
 *          library/ecp.c
 *          library/ecdsa.c
 *          library/rsa.c
 *          library/ssl_tls.c
 *
 * This module is required for RSA, DHM and ECC (ECDH, ECDSA) support.
 */
#define ANTSSM_MPI_C

/**
 * \def ANTSSM_CERTS_C
 *
 * Enable the test certificates.
 *
 * Module:  library/certs.c
 * Caller:
 *
 * This module is used for testing (ssl_client/server).
 */
// #define ANTSSM_CERTS_C

/**
 * \def ANTSSM_CIPHER_C
 *
 * Enable the generic cipher layer.
 *
 * Module:  library/cipher.c
 * Caller:  library/ssl_tls.c
 *
 * Uncomment to enable generic cipher wrappers.
 */
#define ANTSSM_CIPHER_C

/**
 * \def ANTSSM_CMAC_C
 *
 * Enable the CMAC (Cipher-based Message Authentication Code) mode for block
 * ciphers.
 *
 * Module:  library/cmac.c
 *
 * Requires: ANTSSM_AES_C or ANTSSM_DES_C
 *
 */
// #define ANTSSM_CMAC_C

/**
 * \def ANTSSM_DEBUG_C
 *
 * Enable the debug functions.
 *
 * Module:  library/debug.c
 * Caller:  library/ssl_cli.c
 *          library/ssl_srv.c
 *          library/ssl_tls.c
 *
 * This module provides debugging functions.
 */
// #define ANTSSM_DEBUG_C

/**
 * \def ANTSSM_DES_C
 *
 * Enable the DES block cipher.
 *
 * Module:  library/3des.c
 * Caller:  library/pem.c
 *          library/ssl_tls.c
 *
 * This module enables the following ciphersuites (if other requisites are
 * enabled as well):
 *      ANTSSM_TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_ECDHE_PSK_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_RSA_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA
 *      ANTSSM_TLS_PSK_WITH_3DES_EDE_CBC_SHA
 *
 * PEM_PARSE uses DES/3DES for decrypting encrypted keys.
 */
#define ANTSSM_DES_C

/**
 * \def ANTSSM_ECDH_C
 *
 * Enable the elliptic curve Diffie-Hellman library.
 *
 * Module:  library/ecdh.c
 * Caller:  library/ssl_cli.c
 *          library/ssl_srv.c
 *
 * This module is used by the following key exchanges:
 *      ECDHE-ECDSA, ECDHE-RSA, DHE-PSK
 *
 * Requires: ANTSSM_ECP_C
 */
#define ANTSSM_ECDH_C

/**
 * \def ANTSSM_ECDSA_C
 *
 * Enable the elliptic curve DSA library.
 *
 * Module:  library/ecdsa.c
 * Caller:
 *
 * This module is used by the following key exchanges:
 *      ECDHE-ECDSA
 *
 * Requires: ANTSSM_ECP_C
 */
#define ANTSSM_ECDSA_C

/**
 * \def ANTSSM_ECJPAKE_C
 *
 * Enable the elliptic curve J-PAKE library.
 *
 * \warning This is currently experimental. EC J-PAKE support is based on the
 * Thread v1.0.0 specification; incompatible changes to the specification
 * might still happen. For this reason, this is disabled by default.
 *
 * Module:  library/ecjpake.c
 * Caller:
 *
 * This module is used by the following key exchanges:
 *      ECJPAKE
 *
 * Requires: ANTSSM_ECP_C, ANTSSM_MD_C
 */
// #define ANTSSM_ECJPAKE_C

/**
 * \def ANTSSM_ECP_C
 *
 * Enable the elliptic curve over GF(p) library.
 *
 * Module:  library/ecp.c
 * Caller:  library/ecdh.c
 *          library/ecdsa.c
 *          library/ecjpake.c
 *
 * Requires: ANTSSM_MPI_C and at least one ANTSSM_ECP_DP_XXX_ENABLED
 */
#define ANTSSM_ECP_C

/**
 * \def ANTSSM_ERROR_C
 *
 * Enable error code to error string conversion.
 *
 * Module:  library/error.c
 * Caller:
 *
 * This module enables mpaas_antssm_strerror().
 */
#define ANTSSM_ERROR_C

/**
 * \def ANTSSM_HAVEGE_C
 *
 * Enable the HAVEGE random generator.
 *
 * Warning: the HAVEGE random generator is not suitable for virtualized
 *          environments
 *
 * Warning: the HAVEGE random generator is dependent on timing and specific
 *          processor traits. It is therefore not advised to use HAVEGE as
 *          your applications primary random generator or primary entropy pool
 *          input. As a secondary input to your entropy pool, it IS able add
 *          the (limited) extra entropy it provides.
 *
 * Module:  library/havege.c
 * Caller:
 *
 * Requires: ANTSSM_TIMING_C
 *
 * Uncomment to enable the HAVEGE random generator.
 */
// #define ANTSSM_HAVEGE_C

/**
 * \def ANTSSM_MD_C
 *
 * Enable the generic message digest layer.
 *
 * Module:  library/md.c
 * Caller:
 *
 * Uncomment to enable generic message digest wrappers.
 */
#define ANTSSM_MD_C

/**
 * \def ANTSSM_MEMORY_BUFFER_ALLOC_C
 *
 * Enable the buffer allocator implementation that makes use of a (stack)
 * based buffer to 'allocate' dynamic memory. (replaces calloc() and free()
 * calls)
 *
 * Module:  library/memory_buffer_alloc.c
 *
 * Requires: ANTSSM_PLATFORM_C
 *           ANTSSM_PLATFORM_MEMORY (to use it within mbed TLS)
 *
 * Enable this module to enable the buffer memory allocator.
 */
//#define ANTSSM_MEMORY_BUFFER_ALLOC_C

/**
 * \def ANTSSM_PK_C
 *
 * Enable the generic public (asymetric) key layer.
 *
 * Module:  library/pk.c
 * Caller:  library/ssl_tls.c
 *          library/ssl_cli.c
 *          library/ssl_srv.c
 *
 * Requires: ANTSSM_RSA_C or ANTSSM_ECP_C
 *
 * Uncomment to enable generic public key wrappers.
 */
#define ANTSSM_PK_C

#define ANTSSM_PK_CODEC_C

/**
 * \def ANTSSM_PK_PARSE_C
 *
 * Enable the generic public (asymetric) key parser.
 *
 * Module:  library/pkparse.c
 *
 * Requires: ANTSSM_PK_C
 *
 * Uncomment to enable generic public key parse functions.
 */
#define ANTSSM_PK_PARSE_C

/**
 * \def ANTSSM_PK_WRITE_C
 *
 * Enable the generic public (asymetric) key writer.
 *
 * Module:  library/pkwrite.c
 *
 * Requires: ANTSSM_PK_C
 *
 * Uncomment to enable generic public key write functions.
 */
#define ANTSSM_PK_WRITE_C

/**
 * \def ANTSSM_PKCS5_C
 *
 * Enable PKCS#5 functions.
 *
 * Module:  library/pkcs5.c
 *
 * Requires: ANTSSM_MD_C
 *
 * This module adds support for the PKCS#5 functions.
 */
#define ANTSSM_PKCS5_C

/**
 * \def ANTSSM_PKCS11_C
 *
 * Enable wrapper for PKCS#11 smartcard support.
 *
 * Module:  library/pkcs11.c
 * Caller:  library/pk.c
 *
 * Requires: ANTSSM_PK_C
 *
 * This module enables SSL/TLS PKCS #11 smartcard support.
 * Requires the presence of the PKCS#11 helper library (libpkcs11-helper)
 */
// #define ANTSSM_PKCS11_C

/**
 * \def ANTSSM_PLATFORM_C
 *
 * Enable the platform abstraction layer that allows you to re-assign
 * functions like calloc(), free(), snprintf(), printf(), fprintf(), exit().
 *
 * Enabling ANTSSM_PLATFORM_C enables to use of ANTSSM_PLATFORM_XXX_ALT
 * or ANTSSM_PLATFORM_XXX_MACRO directives, allowing the functions mentioned
 * above to be specified at runtime or compile time respectively.
 *
 * \note This abstraction layer must be enabled on Windows (including MSYS2)
 * as other module rely on it for a fixed snprintf implementation.
 *
 * Module:  library/platform.c
 * Caller:  Most other .c files
 *
 * This module enables abstraction of common (libc) functions.
 */
#define ANTSSM_PLATFORM_C

/**
 * \def ANTSSM_RSA_C
 *
 * Enable the RSA public-key cryptosystem.
 *
 * Module:  library/rsa.c
 * Caller:  library/ssl_cli.c
 *          library/ssl_srv.c
 *          library/ssl_tls.c
 *          library/x509.c
 *
 * This module is used by the following key exchanges:
 *      RSA, DHE-RSA, ECDHE-RSA, RSA-PSK
 *
 * Requires: ANTSSM_MPI_C, ANTSSM_OID_C
 */
#define ANTSSM_RSA_C

/**
 * \def ANTSSM_SYMMETRIC_C
 *
 * Enable the persistent symmetric-key cryptosystem.
 * Requires: ANTSSM_MPI_C, ANTSSM_OID_C
 */
#define ANTSSM_SYMMETRIC_C

/**
 * \def ANTSSM_SSL_SM
 *
 * Enable the SM2 cryptosystem.
 *
 * Module:  library/sm2.c
 * Caller:
 *
 * This module is used by the following key exchanges:
 *      ECC, ECDHE
 *
 * Requires: ANTSSM_MPI_C, ANTSSM_OID_C
 */
// s#define ANTSSM_SSL_SM

/**
 * \def ANTSSM_SM2_C
 *
 * Enable the SM2 cryptosystem.
 *
 * Module:  library/sm2.c
 * Caller:
 *
 * This module is used by the following key exchanges:
 *      ECC, ECDHE
 *
 * Requires: ANTSSM_MPI_C, ANTSSM_OID_C
 */
#define ANTSSM_SM2_C

/**
 * \def ANTSSM_SM3_C
 *
 * Enable the SM3 cryptosystem.
 *
 * Module:  library/sm3.c
 * Caller:
 *
 * This module is used by the following key exchanges:
 *      ECC, ECDHE
 *
 * Requires: ANTSSM_MPI_C, ANTSSM_OID_C
 */
#define ANTSSM_SM3_C

/**
 * \def ANTSSM_SM4_C
 *
 * Enable the SM4 cryptosystem.
 *
 * Module:  library/sm4.c
 * Caller:
 *
 * This module is used by the following key exchanges:
 *      ECC, ECDHE
 *
 * Requires: ANTSSM_MPI_C, ANTSSM_OID_C
 */
#define ANTSSM_SM4_C

/**
 * @brief
 */
#define ANTSSM_CIPHER_MODE_SM4_CTR

/**
 * @brief
 * arm platform cpu don't have the avx usually
 */
#ifndef ARM
#define ANTSSM_SM4_AVX_C

/**
 * @brief
 */
#define ANTSSM_SM4_AVX2_C

/**
 * @brief
 */
#define ANTSSM_SM4_AVX512_C
#endif


/**
 * @brief
 * if complie in SGX RAND environment 
 */
#ifdef SGXRAND
#define ANTSSM_SGX_RAND_C
#endif


/**
 * @brief
 * if complie in SGX TEE environment 
 */
#ifdef SGXTEE
#define ANTSSM_SGX_TEE_C

/**
 * \def ANTSSM_WHITE_BOX_ROM_TABLES
 *
 * Store white box tables in ROM.
 *
 * Module: library/white_box_rom_tables
 * Caller: library/white_box.c
 *
 * Requires: None
 *
 * Uncomment this macro to store the white box tables in ROM.
 */
#define ANTSSM_WHITE_BOX_ROM_TABLES

#else



/**
 * \def ANTSSM_LOG_C
 *
 * This module supports runtime log
 *
 * Comment to disable the feature of log
 */
#define ANTSSM_LOG_C

/**
 * \def ANTSSM_KEY_REP_C
 *
 * This module supports key repository
 *
 * Comment to disable the feature of key repository
 */
#define ANTSSM_KEY_REP_C


#endif


#define ANTSSM_KEY_REP_ATTR_C

/**
 * \def ANTSSM_SHA1_C
 *
 * Enable the SHA1 cryptographic hash algorithm.
 *
 * Module:  library/sha1.c
 * Caller:  library/md.c
 *
 * This module is required for SSL/TLS up to version 1.1, for TLS 1.2
 * depending on the handshake parameters, and for SHA1-signed certificates.
 *
 * \warning   SHA-1 is considered a weak message digest and its use constitutes
 *            a security risk. If possible, we recommend avoiding dependencies
 *            on it, and considering stronger message digests instead.
 *
 */
#define ANTSSM_SHA1_C

/**
 * \def ANTSSM_SHA256_C
 *
 * Enable the SHA-224 and SHA-256 cryptographic hash algorithms.
 *
 * Module:  library/sha256.c
 * Caller:  library/entropy.c
 *          library/md.c
 *          library/ssl_cli.c
 *          library/ssl_srv.c
 *          library/ssl_tls.c
 *
 * This module adds support for SHA-224 and SHA-256.
 * This module is required for the SSL/TLS 1.2 PRF function.
 */
#define ANTSSM_SHA256_C

/**
 * \def ANTSSM_THREADING_C
 *
 * Enable the threading abstraction layer.
 * By default mbed TLS assumes it is used in a non-threaded environment or that
 * contexts are not shared between threads. If you do intend to use contexts
 * between threads, you will need to enable this layer to prevent race
 * conditions. See also our Knowledge Base article about threading:
 * https://tls.mbed.org/kb/development/thread-safety-and-multi-threading
 *
 * Module:  library/threading.c
 *
 * This allows different threading implementations (self-implemented or
 * provided).
 *
 * You will have to enable either ANTSSM_THREADING_ALT or
 * ANTSSM_THREADING_PTHREAD.
 *
 * Enable this layer to allow use of mutexes within mbed TLS
 */
// #define ANTSSM_THREADING_C

/**
 * \def ANTSSM_TIMING_C
 *
 * Enable the semi-portable timing interface.
 *
 * \note The provided implementation only works on POSIX/Unix (including Linux,
 * BSD and OS X) and Windows. On other platforms, you can either disable that
 * module and provide your own implementations of the callbacks needed by
 * \c mpaas_antssm_ssl_set_timer_cb() for DTLS, or leave it enabled and provide
 * your own implementation of the whole module by setting
 * \c ANTSSM_TIMING_ALT in the current file.
 *
 * \note See also our Knowledge Base article about porting to a new
 * environment:
 * https://tls.mbed.org/kb/how-to/how-do-i-port-mbed-tls-to-a-new-environment-OS
 *
 * Module:  library/timing.c
 * Caller:  library/havege.c
 *
 * This module is used by the HAVEGE random number generator.
 */
#define ANTSSM_TIMING_C

/**
 * \def ANTSSM_VERSION_C
 *
 * Enable run-time version information.
 *
 * Module:  library/version.c
 *
 * This module provides run-time version information.
 */
// #define ANTSSM_VERSION_C

/* \} name SECTION: mbed TLS modules */

/**
 * \name SECTION: Module configuration options
 *
 * This section allows for the setting of module specific sizes and
 * configuration options. The default values are already present in the
 * relevant header files and should suffice for the regular use cases.
 *
 * Our advice is to enable options and change their values here
 * only if you have a good reason and know the consequences.
 *
 * Please check the respective header file for documentation on these
 * parameters (to prevent duplicate documentation).
 * \{
 */

/* MPI / BIGNUM options */
//#define ANTSSM_MPI_WINDOW_SIZE            6 /**< Maximum windows size used. */
//#define ANTSSM_MPI_MAX_SIZE            1024 /**< Maximum number of bytes for usable MPIs. */

/* CTR_DRBG options */
//#define ANTSSM_CTR_DRBG_ENTROPY_LEN               48 /**< Amount of entropy used per seed by default (48 with SHA-512, 32 with SHA-256) */
//#define ANTSSM_CTR_DRBG_RESEED_INTERVAL        10000 /**< Interval before reseed is performed by default */
//#define ANTSSM_CTR_DRBG_MAX_INPUT                256 /**< Maximum number of additional input bytes */
//#define ANTSSM_CTR_DRBG_MAX_REQUEST             1024 /**< Maximum number of requested bytes per call */
//#define ANTSSM_CTR_DRBG_MAX_SEED_INPUT           384 /**< Maximum size of (re)seed buffer */

/* HMAC_DRBG options */
//#define ANTSSM_HMAC_DRBG_RESEED_INTERVAL   10000 /**< Interval before reseed is performed by default */
//#define ANTSSM_HMAC_DRBG_MAX_INPUT           256 /**< Maximum number of additional input bytes */
//#define ANTSSM_HMAC_DRBG_MAX_REQUEST        1024 /**< Maximum number of requested bytes per call */
//#define ANTSSM_HMAC_DRBG_MAX_SEED_INPUT      384 /**< Maximum size of (re)seed buffer */

/* ECP options */
//#define ANTSSM_ECP_MAX_BITS             521 /**< Maximum bit size of groups */
//#define ANTSSM_ECP_WINDOW_SIZE            6 /**< Maximum window size used */
//#define ANTSSM_ECP_FIXED_POINT_OPTIM      1 /**< Enable fixed-point speed-up */

/* Entropy options */
//#define ANTSSM_ENTROPY_MAX_SOURCES                20 /**< Maximum number of sources supported */
//#define ANTSSM_ENTROPY_MAX_GATHER                128 /**< Maximum amount requested from entropy sources */
//#define ANTSSM_ENTROPY_MIN_HARDWARE               32 /**< Default minimum number of bytes required for the hardware entropy source mpaas_antssm_hardware_poll() before entropy is released */

/* Memory buffer allocator options */
//#define ANTSSM_MEMORY_ALIGN_MULTIPLE      4 /**< Align on multiples of this value */

/* Platform options */
//#define ANTSSM_PLATFORM_STD_MEM_HDR   <stdlib.h> /**< Header to include if ANTSSM_PLATFORM_NO_STD_FUNCTIONS is defined. Don't define if no header is needed. */
//#define ANTSSM_PLATFORM_STD_CALLOC        calloc /**< Default allocator to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_FREE            free /**< Default free to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_EXIT            exit /**< Default exit to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_TIME            time /**< Default time to use, can be undefined. ANTSSM_HAVE_TIME must be enabled */
//#define ANTSSM_PLATFORM_STD_FPRINTF      fprintf /**< Default fprintf to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_PRINTF        printf /**< Default printf to use, can be undefined */
/* Note: your snprintf must correclty zero-terminate the buffer! */
//#define ANTSSM_PLATFORM_STD_SNPRINTF    snprintf /**< Default snprintf to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_EXIT_SUCCESS       0 /**< Default exit value to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_EXIT_FAILURE       1 /**< Default exit value to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_NV_SEED_READ   mpaas_antssm_platform_std_nv_seed_read /**< Default nv_seed_read function to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_NV_SEED_WRITE  mpaas_antssm_platform_std_nv_seed_write /**< Default nv_seed_write function to use, can be undefined */
//#define ANTSSM_PLATFORM_STD_NV_SEED_FILE  "seedfile" /**< Seed file to read/write with default implementation */

/* To Use Function Macros ANTSSM_PLATFORM_C must be enabled */
/* ANTSSM_PLATFORM_XXX_MACRO and ANTSSM_PLATFORM_XXX_ALT cannot both be defined */
//#define ANTSSM_PLATFORM_CALLOC_MACRO        calloc /**< Default allocator macro to use, can be undefined */
//#define ANTSSM_PLATFORM_FREE_MACRO            free /**< Default free macro to use, can be undefined */
//#define ANTSSM_PLATFORM_EXIT_MACRO            exit /**< Default exit macro to use, can be undefined */
//#define ANTSSM_PLATFORM_TIME_MACRO            time /**< Default time macro to use, can be undefined. ANTSSM_HAVE_TIME must be enabled */
//#define ANTSSM_PLATFORM_TIME_TYPE_MACRO       time_t /**< Default time macro to use, can be undefined. ANTSSM_HAVE_TIME must be enabled */
//#define ANTSSM_PLATFORM_FPRINTF_MACRO      fprintf /**< Default fprintf macro to use, can be undefined */
//#define ANTSSM_PLATFORM_PRINTF_MACRO        printf /**< Default printf macro to use, can be undefined */
/* Note: your snprintf must correclty zero-terminate the buffer! */
//#define ANTSSM_PLATFORM_SNPRINTF_MACRO    snprintf /**< Default snprintf macro to use, can be undefined */
//#define ANTSSM_PLATFORM_NV_SEED_READ_MACRO   mpaas_antssm_platform_std_nv_seed_read /**< Default nv_seed_read function to use, can be undefined */
//#define ANTSSM_PLATFORM_NV_SEED_WRITE_MACRO  mpaas_antssm_platform_std_nv_seed_write /**< Default nv_seed_write function to use, can be undefined */

/* SSL Cache options */
//#define ANTSSM_SSL_CACHE_DEFAULT_TIMEOUT       86400 /**< 1 day  */
//#define ANTSSM_SSL_CACHE_DEFAULT_MAX_ENTRIES      50 /**< Maximum entries in cache */

/* SSL options */
//#define ANTSSM_SSL_MAX_CONTENT_LEN             16384 /**< Maxium fragment length in bytes, determines the size of each of the two internal I/O buffers */
//#define ANTSSM_SSL_DEFAULT_TICKET_LIFETIME     86400 /**< Lifetime of session tickets (if enabled) */
//#define ANTSSM_PSK_MAX_LEN               32 /**< Max size of TLS pre-shared keys, in bytes (default 256 bits) */
//#define ANTSSM_SSL_COOKIE_TIMEOUT        60 /**< Default expiration delay of DTLS cookies, in seconds if HAVE_TIME, or in number of cookies issued */

/**
 * Complete list of ciphersuites to use, in order of preference.
 *
 * \warning No dependency checking is done on that field! This option can only
 * be used to restrict the set of available ciphersuites. It is your
 * responsibility to make sure the needed modules are active.
 *
 * Use this to save a few hundred bytes of ROM (default ordering of all
 * available ciphersuites) and a few to a few hundred bytes of RAM.
 *
 * The value below is only an example, not the default.
 */
//#define ANTSSM_SSL_CIPHERSUITES ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,ANTSSM_TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256

/* X509 options */
//#define ANTSSM_X509_MAX_INTERMEDIATE_CA   8   /**< Maximum number of intermediate CAs in a verification chain. */
//#define ANTSSM_X509_MAX_FILE_PATH_LEN     512 /**< Maximum length of a path/filename string in bytes including the null terminator character ('\0'). */

/**
 * Allow SHA-1 in the default TLS configuration for certificate signing.
 * Without this build-time option, SHA-1 support must be activated explicitly
 * through mpaas_antssm_ssl_conf_cert_profile. Turning on this option is not
 * recommended because of it is possible to generte SHA-1 collisions, however
 * this may be safe for legacy infrastructure where additional controls apply.
 */
//#define ANTSSM_TLS_DEFAULT_ALLOW_SHA1_IN_CERTIFICATES

/**
 * Allow SHA-1 in the default TLS configuration for TLS 1.2 handshake
 * signature and ciphersuite selection. Without this build-time option, SHA-1
 * support must be activated explicitly through mpaas_antssm_ssl_conf_sig_hashes.
 * The use of SHA-1 in TLS <= 1.1 and in HMAC-SHA-1 is always allowed by
 * default. At the time of writing, there is no practical attack on the use
 * of SHA-1 in handshake signatures, hence this option is turned on by default
 * for compatibility with existing peers.
 */
//#define ANTSSM_TLS_DEFAULT_ALLOW_SHA1_IN_KEY_EXCHANGE

/* \} name SECTION: Customisation configuration options */

/* Target and application specific configurations */
//#define YOTTA_CFG_ANTSSM_TARGET_CONFIG_FILE "antssm/target_config.h"

#if defined(TARGET_LIKE_MBED) && defined(YOTTA_CFG_ANTSSM_TARGET_CONFIG_FILE)
#include YOTTA_CFG_ANTSSM_TARGET_CONFIG_FILE
#endif

/*
 * Allow user to override any previous default.
 *
 * Use two macro names for that, as:
 * - with yotta the prefix YOTTA_CFG_ is forced
 * - without yotta is looks weird to have a YOTTA prefix.
 */
#if defined(YOTTA_CFG_ANTSSM_USER_CONFIG_FILE)
#include YOTTA_CFG_ANTSSM_USER_CONFIG_FILE
#elif defined(ANTSSM_USER_CONFIG_FILE)
#include ANTSSM_USER_CONFIG_FILE
#endif

#include "check_config.h"

#endif /* ANTSSM_CONFIG_H */
