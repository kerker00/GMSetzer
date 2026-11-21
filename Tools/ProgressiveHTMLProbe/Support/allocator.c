// Development-only, glibc-specific allocation interposer. No library dependency.
// Counts successful allocation calls/requested bytes on the calling thread only.
// __libc_* bypasses our wrappers, avoiding dynamic-loader recursion at startup.
#include <stdint.h>
#include <stddef.h>
#include <unistd.h>
#include <errno.h>
#include <limits.h>

extern void *__libc_malloc(size_t);
extern void *__libc_calloc(size_t, size_t);
extern void *__libc_realloc(void *, size_t);
extern void __libc_free(void *);
extern void *__libc_memalign(size_t, size_t);
static __thread uint64_t calls, bytes;
static __thread int enabled;
static void record(void *p, size_t n) { if (enabled && p) { ++calls; bytes += n; } }
void gm_alloc_begin(void) { calls = bytes = 0; enabled = 1; }
void gm_alloc_end(uint64_t *c, uint64_t *b) { enabled = 0; *c = calls; *b = bytes; }
void *malloc(size_t n) { void *p = __libc_malloc(n); record(p, n); return p; }
void *calloc(size_t n, size_t s) {
    void *p = __libc_calloc(n, s);
    size_t total;
    if (!__builtin_mul_overflow(n, s, &total)) record(p, total);
    return p;
}
void *realloc(void *old, size_t n) { void *p = __libc_realloc(old, n); record(p, n); return p; }
void free(void *p) { __libc_free(p); }
void *memalign(size_t a, size_t n) { void *p = __libc_memalign(a, n); record(p, n); return p; }
void *aligned_alloc(size_t a, size_t n) { return memalign(a, n); }
int posix_memalign(void **out, size_t a, size_t n) {
    if (a < sizeof(void *) || (a & (a - 1))) return EINVAL;
    void *p = __libc_memalign(a, n);
    if (!p) return ENOMEM;
    *out = p; record(p, n); return 0;
}
void *valloc(size_t n) { return memalign((size_t)sysconf(_SC_PAGESIZE), n); }
void *pvalloc(size_t n) {
    size_t a = (size_t)sysconf(_SC_PAGESIZE);
    if (n > SIZE_MAX - (a - 1)) { errno = ENOMEM; return NULL; }
    size_t rounded = n ? (n + a - 1) / a * a : a;
    return memalign(a, rounded);
}
