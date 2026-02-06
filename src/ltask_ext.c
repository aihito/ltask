#include "ltask_ext.h"
#include "service.h"
#include "message.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Global ltask pointer for extension layer (future-proofing).
// Set once during ltask_init.
static struct ltask *g_ltask = NULL;

// Cached pool pointer (used for message routing).
static struct service_pool *g_service_pool = NULL;

void
ltask_ext_init(struct ltask *task, struct service_pool *pool) {
	g_ltask = task;
	g_service_pool = pool;
}

// Moon compatibility functions for lrust
// These functions allow existing Rust code to work without modification

// send_integer_message: Moon-style function that Rust code calls
// Maps to MESSAGE_RESPONSE with pointer-sized payload.
__attribute__((visibility("default")))
void
send_integer_message(uint8_t type_, uint32_t receiver, int64_t session, intptr_t val) {
	// printf("########## send_integer_message %d %d %ld %p\n", type_, receiver, session, (void*)val);
	(void)type_;
	(void)g_ltask;	// reserved for future use
	if (g_service_pool == NULL || session == 0) {
		return;
	}

	service_id to = { receiver };
	session_t sess = (session_t)session;

	// Create message with pointer value (heap-allocated Rust object pointer)
	void *msg_buf = malloc(sizeof(intptr_t));
	if (msg_buf == NULL) {
		return;
	}
	memcpy(msg_buf, &val, sizeof(intptr_t));

	struct message msg = {
		.from = {0},
		.to = to,
		.session = sess,
		.type = type_,
		.msg = msg_buf,
		.sz = sizeof(intptr_t)
	};

	struct message *m = message_new(&msg);
	if (m == NULL) {
		free(msg_buf);
		return;
	}
	ltask_push_extension_message(g_ltask, m);
}

// send_message: Moon-style function for sending byte data
__attribute__((visibility("default")))
void
send_message(uint8_t type_, uint32_t receiver, int64_t session, const char *data, size_t len) {
	(void)type_;
	(void)g_ltask;	// reserved for future use
	if (g_service_pool == NULL || data == NULL || session == 0) {
		return;
	}

	service_id to = { receiver };
	session_t sess = (session_t)session;

	// Allocate and copy data
	void *msg_buf = malloc(len);
	if (msg_buf == NULL) {
		return;
	}
	memcpy(msg_buf, data, len);

	struct message msg = {
		.from = {0},
		.to = to,
		.session = sess,
		.type = MESSAGE_RESPONSE,
		.msg = msg_buf,
		.sz = len
	};

	struct message *m = message_new(&msg);
	if (m == NULL) {
		free(msg_buf);
		return;
	}
	ltask_push_extension_message(g_ltask, m);
}

__attribute__((visibility("default")))
void
ltask_push_log(uint32_t sender_id, const char *data, size_t len) {
	if (g_ltask == NULL || data == NULL || len == 0)
		return;
	void *buf = malloc(len);
	if (buf == NULL)
		return;
	memcpy(buf, data, len);
	if (ltask_extension_pushlog(g_ltask, sender_id, buf, (uint32_t)len) != 0)
		free(buf);
}
