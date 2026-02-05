#ifndef ltask_ext_h
#define ltask_ext_h

#include <stdint.h>
#include <stddef.h>

struct ltask;
struct service_pool;

void ltask_ext_init(struct ltask *task, struct service_pool *pool);

void send_integer_message(uint8_t type_, uint32_t receiver, int64_t session, intptr_t val);
void send_message(uint8_t type_, uint32_t receiver, int64_t session, const char *data, size_t len);

#endif
