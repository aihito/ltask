#ifndef ltask_ext_h
#define ltask_ext_h

#include <stdint.h>
#include <stddef.h>

struct ltask;
struct service_pool;
struct message;

void ltask_ext_init(struct ltask *task, struct service_pool *pool);

/** Push message to task's extension queue; ltask thread will dispatch to service (keeps SPSC per service). Implemented in ltask.c. */
int ltask_push_extension_message(struct ltask *task, struct message *msg);

void send_integer_message(uint8_t type_, uint32_t receiver, int64_t session, intptr_t val);
void send_message(uint8_t type_, uint32_t receiver, int64_t session, const char *data, size_t len);

/** Implemented in ltask.c: push log into task log queue (same as pushlog). For use by ltask_push_log. */
int ltask_extension_pushlog(struct ltask *task, uint32_t sender_id, void *owned_buf, uint32_t sz);

/** For extensions (e.g. Rust): copy data and push to log queue. Implemented in ltask_ext.c. */
void ltask_push_log(uint32_t sender_id, const char *data, size_t len);

#endif
