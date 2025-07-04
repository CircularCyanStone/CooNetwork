/*
 * Generic mpaas_antssm_hashmap_t manipulation functions
 *
 * Originally by Elliot C Back - http://elliottback.com/wp/hashmap-implementation-in-c/
 *
 * Modified by Pete Warden to fix a serious performance problem, support strings as keys
 * and removed thread synchronization - http://petewarden.typepad.com
 */
#ifndef ANTSSM_HASHMAP_H
#define ANTSSM_HASHMAP_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "platform_specific.h"

#define MAP_MISSING -3  /* No such element */
#define MAP_FULL -2    /* Hashmap is full */
#define MAP_OMEM -1    /* Out of Memory */
#define MAP_OK 0    /* OK */

#ifdef __cplusplus
extern "C" {
#endif

/*
 * mpaas_antssm_any is a pointer.  This allows you to put arbitrary structures in
 * the mpaas_antssm_hashmap.
 */
typedef void *mpaas_antssm_any;

/*
 * PFany is a pointer to a function that can take two mpaas_antssm_any arguments
 * and return an integer. Returns status code..
 */
typedef int (*PFany)(mpaas_antssm_any, mpaas_antssm_any);

/*
 * mpaas_antssm_hashmap_t is a pointer to an internally maintained data structure.
 * Clients of this package do not need to know how mpaas_antssm_hashmaps are
 * represented.  They see and manipulate only mpaas_antssm_hashmap's.
 */
typedef mpaas_antssm_any mpaas_antssm_hashmap_t;

/*
 * Return an empty mpaas_antssm_hashmap. Returns NULL if empty.
*/
mpaas_antssm_hashmap_t mpaas_antssm_hashmap_new();

/*
 * Free the mpaas_antssm_hashmap
 */
void mpaas_antssm_hashmap_free(mpaas_antssm_hashmap_t map);

/*
 * Iteratively call f with argument (item, data) for
 * each element data in the mpaas_antssm_hashmap. The function must
 * return a map status code. If it returns anything other
 * than MAP_OK the traversal is terminated. f must
 * not reenter any mpaas_antssm_hashmap_t functions, or deadlock may arise.
 */
int mpaas_antssm_hashmap_iterate(mpaas_antssm_hashmap_t map, PFany f, mpaas_antssm_any item);

/*
 * Add an element to the mpaas_antssm_hashmap. Return MAP_OK or MAP_OMEM.
 */
int mpaas_antssm_hashmap_put(mpaas_antssm_hashmap_t map, char *key, mpaas_antssm_any value);

/*
 * Get an element from the mpaas_antssm_hashmap. Return MAP_OK or MAP_MISSING.
 */
int mpaas_antssm_hashmap_get(mpaas_antssm_hashmap_t map, char *key, mpaas_antssm_any *arg);

/*
 * Remove an element from the mpaas_antssm_hashmap. Return MAP_OK or MAP_MISSING.
 */
int mpaas_antssm_hashmap_remove(mpaas_antssm_hashmap_t map, char *key);

/*
 * Get any element. Return MAP_OK or MAP_MISSING.
 * remove - should the element be removed from the mpaas_antssm_hashmap
 */
int mpaas_antssm_hashmap_get_one(mpaas_antssm_hashmap_t map, mpaas_antssm_any *arg, int remove);

/*
 * Get the current size of a mpaas_antssm_hashmap
 */
int mpaas_antssm_hashmap_length(mpaas_antssm_hashmap_t map);

#ifdef ANTSSM_HASHMAP_SECRET_AUTO_DESTROY
typedef struct {
    mpaas_antssm_pthread_t thread;
    mpaas_antssm_pthread_cond_t cond;
    mpaas_antssm_pthread_mutex_t mutex;
} mpaas_antssm_hashmap_secret_context;

int mpaas_antssm_hashmap_secret_init(mpaas_antssm_hashmap_secret_context *ctx);

int mpaas_antssm_hashmap_secret_free(mpaas_antssm_hashmap_secret_context *ctx);

int mpaas_antssm_hashmap_session_set_alive_time(size_t seconds);
#endif /* ANTSSM_HASHMAP_SECRET_AUTO_DESTROY */

#ifdef __cplusplus
}
#endif

#endif
