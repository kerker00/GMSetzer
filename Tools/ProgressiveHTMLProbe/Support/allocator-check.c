// Verify the interposer's counters before collecting evidence. Compile without
// builtin allocation optimisations; each exercised request must stay observable.
#define _GNU_SOURCE
#include <assert.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <pthread.h>
#include <malloc.h>
static void *other_thread(void *unused) { void *p = malloc(777); assert(p); free(p); return unused; }
int main(void) {
    void (*begin)(void) = dlsym(RTLD_DEFAULT, "gm_alloc_begin");
    void (*end)(uint64_t *, uint64_t *) = dlsym(RTLD_DEFAULT, "gm_alloc_end");
    assert(begin && end);
    uint64_t c, b;
    pthread_t t;
    assert(pthread_create(&t, NULL, other_thread, NULL) == 0);
    assert(pthread_join(t, NULL) == 0);
    begin();
    void *p = malloc(13); assert(p);
    p = realloc(p, 29); assert(p);
    void *q = calloc(3, 7); assert(q);
    void *r = NULL; assert(posix_memalign(&r, 64, 64) == 0);
    void *s = aligned_alloc(64, 128); assert(s);
    void *u = memalign(64, 256); assert(u);
    free(p); free(q); free(r); free(s); free(u);
    end(&c, &b);
    assert(c == 6 && b == 511);
    p = malloc(50); free(p);
    end(&c, &b); assert(c == 6 && b == 511);
    begin(); end(&c, &b); assert(c == 0 && b == 0);
    puts("allocator calibration passed: 6 requests, 511 bytes; reset/disabled counters checked");
}
