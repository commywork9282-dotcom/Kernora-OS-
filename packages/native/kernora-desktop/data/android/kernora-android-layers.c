/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <stddef.h>

#define SLOTS 64
#define KEY_SIZE 192
#define TASK_SIZE 16
#define NAME_SIZE 320
#define LOAD_NOW 2
#define HAL_RGBX_8888 2
#define HAL_RGB_565 4
#define SPLIT_SYMBOL "_ZN24split_layer_names_helper16split_layer_nameERKNSt3__112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEE"
#define CREATE_SYMBOL "_Z20create_shm_wl_bufferP7displayRK15buffer_metadataPK13native_handle"
#define LOCK_SYMBOL "_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_"

struct library_info {
    const char *file;
    void *base;
    const char *symbol;
    void *address;
};

struct long_string {
    size_t capacity;
    size_t size;
    const char *data;
};

struct text {
    const char *data;
    size_t size;
};

struct known_window {
    char key[KEY_SIZE];
    char task[TASK_SIZE];
    size_t key_size;
};

struct buffer_metadata {
    unsigned int height;
    unsigned int width;
    unsigned int pixel_stride;
    unsigned int format;
};

struct wayland_buffer {
    void *wl_buffer;
    const void *handle;
    struct buffer_metadata metadata;
};

struct video_buffer {
    const void *handle;
    struct buffer_metadata metadata;
};

typedef void *(*split_function)(void *result, const void *name);
typedef void *(*create_function)(void **result, void *display, const struct buffer_metadata *metadata, const void *handle);
typedef int (*lock_function)(void *mapper, const void *handle, unsigned int usage, const void *bounds, void **address,
                             int *bytes_per_pixel, int *bytes_per_stride);

extern int dladdr(const void *address, struct library_info *info);
extern void *dlopen(const char *file, int flags);
extern void *dlsym(void *library, const char *symbol);
extern int __system_property_get(const char *name, char *value);
extern void *malloc(size_t size);
extern void free(void *memory);

static struct known_window known[SLOTS];
static unsigned int next_slot;
static split_function split;
static create_function create_buffer;
static lock_function lock_buffer;
static int active;
static struct video_buffer videos[SLOTS];
static unsigned int next_video;
static unsigned int *pixels;
static size_t pixels_size;

static struct text read_string(const void *value)
{
    const unsigned char *bytes = value;
    if (bytes[0] & 1) {
        const struct long_string *full = value;
        return (struct text){full->data, full->size};
    }
    return (struct text){(const char *)bytes + 1, bytes[0] >> 1};
}

static long find_first(struct text value, char wanted)
{
    for (size_t index = 0; index < value.size; index++) {
        if (value.data[index] == wanted) {
            return (long)index;
        }
    }
    return -1;
}

static long find_last(struct text value, char wanted)
{
    for (size_t index = value.size; index > 0; index--) {
        if (value.data[index - 1] == wanted) {
            return (long)index - 1;
        }
    }
    return -1;
}

static int same(const char *first, const char *second, size_t size)
{
    for (size_t index = 0; index < size; index++) {
        if (first[index] != second[index]) {
            return 0;
        }
    }
    return 1;
}

static void copy(char *target, const char *source, size_t size)
{
    for (size_t index = 0; index < size; index++) {
        target[index] = source[index];
    }
}

static int ends_with(struct text value, const char *tail, size_t size)
{
    return value.size >= size && same(value.data + value.size - size, tail, size);
}

static void remember(struct text name)
{
    long hash = find_first(name, '#');
    long end = find_last(name, '#');
    if (hash <= 4 || end <= hash || hash - 4 >= TASK_SIZE) {
        return;
    }
    struct text key = {name.data + hash + 1, (size_t)(end - hash - 1)};
    if (key.size == 0 || key.size > KEY_SIZE || find_first(key, '/') < 0) {
        return;
    }
    struct known_window *slot = NULL;
    for (unsigned int index = 0; index < SLOTS; index++) {
        if (known[index].key_size == key.size && same(known[index].key, key.data, key.size)) {
            slot = &known[index];
            break;
        }
    }
    if (slot == NULL) {
        slot = &known[next_slot++ % SLOTS];
        copy(slot->key, key.data, key.size);
        slot->key_size = key.size;
    }
    copy(slot->task, name.data + 4, (size_t)(hash - 4));
    slot->task[hash - 4] = 0;
}

static const char *task_of(struct text name)
{
    long end = find_last(name, '#');
    struct text key = {name.data, end > 0 ? (size_t)end : name.size};
    long slash = find_first(key, '/');
    if (slash <= 0) {
        return NULL;
    }
    if (ends_with(key, "(BLAST)", 7)) {
        key.size -= 7;
    } else if (ends_with(key, "$Background", 11)) {
        key.size -= 11;
    }
    const char *found = NULL;
    for (unsigned int index = 0; index < SLOTS; index++) {
        const struct known_window *slot = &known[index];
        if (slot->key_size == key.size && same(slot->key, key.data, key.size)) {
            return slot->task;
        }
        if (slot->key_size > (size_t)slash && slot->key[slash] == '/' && same(slot->key, key.data, (size_t)slash)) {
            found = slot->task;
        }
    }
    return found;
}

static int software_buffers(void)
{
    char value[92] = {0};
    __system_property_get("ro.hardware.gralloc", value);
    return same(value, "default", 8);
}

static void *caller_library(const void *address)
{
    struct library_info info = {0};
    return dladdr(address, &info) ? dlopen(info.file, LOAD_NOW) : NULL;
}

static struct video_buffer *video_of(const void *handle)
{
    for (unsigned int index = 0; index < SLOTS; index++) {
        if (videos[index].handle == handle) {
            return &videos[index];
        }
    }
    return NULL;
}

static int expand(const struct video_buffer *video, const void *source)
{
    const struct buffer_metadata *metadata = &video->metadata;
    size_t stride = metadata->pixel_stride ? metadata->pixel_stride : metadata->width;
    size_t size = stride * metadata->height * sizeof(unsigned int);
    if (size > pixels_size) {
        free(pixels);
        pixels = malloc(size);
        pixels_size = pixels ? size : 0;
    }
    if (pixels == NULL) {
        return 0;
    }
    for (size_t row = 0; row < metadata->height; row++) {
        const unsigned short *from = (const unsigned short *)source + row * stride;
        unsigned int *to = pixels + row * stride;
        for (size_t column = 0; column < metadata->width; column++) {
            unsigned int pixel = from[column];
            unsigned int red = pixel >> 11 & 31;
            unsigned int green = pixel >> 5 & 63;
            unsigned int blue = pixel & 31;
            to[column] = 0xff000000u | (blue << 3 | blue >> 2) << 16 | (green << 2 | green >> 4) << 8 | (red << 3 | red >> 2);
        }
    }
    return 1;
}

void *_Z20create_shm_wl_bufferP7displayRK15buffer_metadataPK13native_handle(void **result, void *display,
                                                                            const struct buffer_metadata *metadata,
                                                                            const void *handle)
{
    if (create_buffer == NULL) {
        create_buffer = (create_function)dlsym(caller_library(__builtin_return_address(0)), CREATE_SYMBOL);
    }
    struct video_buffer *known_video = video_of(handle);
    if (metadata->format != HAL_RGB_565) {
        if (known_video != NULL) {
            known_video->handle = NULL;
        }
        return create_buffer(result, display, metadata, handle);
    }
    struct buffer_metadata wide = *metadata;
    wide.format = HAL_RGBX_8888;
    create_buffer(result, display, &wide, handle);
    struct wayland_buffer *buffer = *result;
    if (buffer != NULL) {
        buffer->metadata.format = HAL_RGB_565;
        struct video_buffer *video = known_video ? known_video : &videos[next_video++ % SLOTS];
        video->handle = handle;
        video->metadata = *metadata;
    }
    return result;
}

int _ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_(void *mapper, const void *handle, unsigned int usage,
                                                                                const void *bounds, void **address,
                                                                                int *bytes_per_pixel, int *bytes_per_stride)
{
    if (lock_buffer == NULL) {
        lock_buffer = (lock_function)dlsym(dlopen("libui.so", LOAD_NOW), LOCK_SYMBOL);
    }
    int status = lock_buffer(mapper, handle, usage, bounds, address, bytes_per_pixel, bytes_per_stride);
    const struct video_buffer *video = video_of(handle);
    if (status == 0 && video != NULL && expand(video, *address)) {
        *address = pixels;
    }
    return status;
}

void *_ZN24split_layer_names_helper16split_layer_nameERKNSt3__112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEE(void *result, const void *name)
{
    if (split == NULL) {
        void *library = caller_library(__builtin_return_address(0));
        split = (split_function)dlsym(library, SPLIT_SYMBOL);
        active = !software_buffers() || dlsym(library, CREATE_SYMBOL) != NULL;
    }
    struct text text = read_string(name);
    if (!active) {
        return split(result, name);
    }
    if (text.size > 4 && same(text.data, "TID:", 4)) {
        remember(text);
        return split(result, name);
    }
    const char *task = task_of(text);
    size_t task_size = 0;
    while (task != NULL && task[task_size] != 0) {
        task_size++;
    }
    if (task == NULL || task_size + text.size + 6 > NAME_SIZE) {
        return split(result, name);
    }
    char buffer[NAME_SIZE];
    copy(buffer, "TID:", 4);
    copy(buffer + 4, task, task_size);
    buffer[4 + task_size] = '#';
    copy(buffer + 5 + task_size, text.data, text.size);
    buffer[5 + task_size + text.size] = 0;
    struct long_string renamed = {NAME_SIZE | 1, 5 + task_size + text.size, buffer};
    return split(result, &renamed);
}
