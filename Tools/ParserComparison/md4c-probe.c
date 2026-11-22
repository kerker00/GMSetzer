/* Original GMSetzer development adapter for MD4C's public callback/HTML APIs.
 * MD4C: https://github.com/mity/md4c (MIT); sources are downloaded separately
 * at the revision recorded in sources.json, never linked into GMSetzer. */
#define _POSIX_C_SOURCE 200809L
#include "md4c.h"
#include "md4c-html.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct { char *data; size_t length, capacity; uint64_t observed; } Output;
static void fail(const char *message) { fprintf(stderr, "%s\n", message); exit(1); }
static uint64_t now(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC, &value)) fail("clock_gettime failed");
    return (uint64_t)value.tv_sec * UINT64_C(1000000000) + (uint64_t)value.tv_nsec;
}
static int block(MD_BLOCKTYPE type, void *detail, void *user) {
    (void)detail; ((Output *)user)->observed += (unsigned)type + 1; return 0;
}
static int span(MD_SPANTYPE type, void *detail, void *user) {
    (void)detail; ((Output *)user)->observed += (unsigned)type + 1; return 0;
}
static int text(MD_TEXTTYPE type, const MD_CHAR *data, MD_SIZE size, void *user) {
    (void)data; ((Output *)user)->observed += (unsigned)type + size + 1; return 0;
}
static void html(const MD_CHAR *data, MD_SIZE size, void *user) {
    Output *out = user;
    if (out->length + size > out->capacity) {
        size_t capacity = out->capacity ? out->capacity : 256;
        while (capacity < out->length + size) capacity *= 2;
        char *next = realloc(out->data, capacity);
        if (!next) fail("output allocation failed");
        out->data = next; out->capacity = capacity;
    }
    memcpy(out->data + out->length, data, size); out->length += size;
}
static uint64_t operation(const char *source, MD_SIZE size, int parse, int emit) {
    Output out = {0}; int result;
    if (parse) {
        MD_PARSER parser = {0};
        parser.enter_block = block; parser.leave_block = block;
        parser.enter_span = span; parser.leave_span = span; parser.text = text;
        result = md_parse(source, size, &parser, &out);
    } else {
        /* CommonMark, default raw HTML and URLs, no extra extensions. */
        result = md_html(source, size, html, &out, 0, MD_HTML_FLAG_XHTML);
        if (emit && fwrite(out.data, 1, out.length, stdout) != out.length) fail("output write failed");
        out.observed = out.length;
    }
    if (result) fail("MD4C failed");
    uint64_t observed = out.observed; free(out.data); return observed;
}
int main(int argc, char **argv) {
    if (argc != 6 || strcmp(argv[4], "commonmark")) fail("usage: md4c-probe mode file commonmark iterations");
    int parse = !strcmp(argv[2], "parse"), emit = !strcmp(argv[2], "emit");
    if (!parse && !emit && strcmp(argv[2], "html")) fail("unknown mode");
    char *end; unsigned long iterations = strtoul(argv[5], &end, 10);
    if (*end || !iterations || iterations > 100000) fail("invalid iteration count");
    FILE *file = fopen(argv[3], "rb"); if (!file) fail("input open failed");
    if (fseek(file, 0, SEEK_END)) fail("input seek failed");
    long length = ftell(file); if (length < 0 || (unsigned long)length > UINT32_MAX) fail("input too large");
    rewind(file); char *source = malloc((size_t)length + 1); if (!source) fail("input allocation failed");
    if (fread(source, 1, (size_t)length, file) != (size_t)length) fail("input read failed");
    fclose(file); source[length] = 0;
    if (emit) operation(source, (MD_SIZE)length, 0, 1);
    else {
        for (int warm = 0; warm < 3; warm++) operation(source, (MD_SIZE)length, parse, 0);
        uint64_t observed = 0, start = now();
        for (unsigned long i = 0; i < iterations; i++) observed += operation(source, (MD_SIZE)length, parse, 0);
        uint64_t elapsed = now() - start;
        printf("{\"elapsed_ns\":%llu,\"iterations\":%lu,\"observed\":%llu}\n",
            (unsigned long long)elapsed, iterations, (unsigned long long)observed);
    }
    free(source); return 0;
}
