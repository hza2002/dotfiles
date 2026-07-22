#pragma once

#include <bootstrap.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <string.h>
#include <sysexits.h>
#include <time.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/message.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

typedef char *env;

#define MACH_HANDLER(name) void name(env env)
typedef MACH_HANDLER(mach_handler);

struct mach_message {
  mach_msg_header_t header;
  mach_msg_size_t msgh_descriptor_count;
  mach_msg_ool_descriptor_t descriptor;
};

struct mach_buffer {
  struct mach_message message;
  mach_msg_trailer_t trailer;
};

struct mach_server {
  bool is_running;
  mach_port_name_t task;
  mach_port_t port;
  mach_port_t bs_port;

  pthread_t thread;
  mach_handler *handler;
};

static struct mach_server g_mach_server;
static mach_port_t g_mach_port = 0;

static inline const char *helper_log_path(void) {
  const char *path = getenv("SKETCHYBAR_HELPER_LOG");
  if (path && path[0] != '\0') return path;
  return "/tmp/sketchybar-helper.log";
}

static inline void helper_log(const char *fmt, ...) {
  FILE *file = fopen(helper_log_path(), "a");
  if (!file) return;

  time_t now = time(NULL);
  struct tm tm;
  localtime_r(&now, &tm);
  char stamp[32];
  strftime(stamp, sizeof(stamp), "%Y-%m-%d %H:%M:%S", &tm);

  fprintf(file, "[%s] pid=%d ", stamp, getpid());
  va_list args;
  va_start(args, fmt);
  vfprintf(file, fmt, args);
  va_end(args);
  fputc('\n', file);
  fclose(file);
}

static inline void helper_signal_ready(void) {
  const char *path = getenv("SKETCHYBAR_HELPER_READY_FIFO");
  if (!path || path[0] == '\0') return;

  int fd = open(path, O_WRONLY | O_NONBLOCK);
  if (fd < 0) {
    helper_log("helper ready signal open failed: %s: %s", path, strerror(errno));
    return;
  }

  const char msg[] = "ready\n";
  ssize_t written = write(fd, msg, sizeof(msg) - 1);
  if (written < 0) {
    helper_log("helper ready signal write failed: %s: %s", path, strerror(errno));
  } else if ((size_t)written != sizeof(msg) - 1) {
    helper_log("helper ready signal short write: %s: %zd", path, written);
  }
  close(fd);
}

static inline char *env_get_value_for_key(env env, char *key) {
  uint32_t caret = 0;
  for (;;) {
    if (!env[caret])
      break;
    if (strcmp(&env[caret], key) == 0)
      return &env[caret + strlen(&env[caret]) + 1];

    caret +=
        strlen(&env[caret]) + strlen(&env[caret + strlen(&env[caret]) + 1]) + 2;
  }
  return (char *)"";
}

static inline mach_port_t mach_get_bs_port(void) {
  mach_port_name_t task = mach_task_self();

  mach_port_t bs_port;
  kern_return_t kr = task_get_special_port(task, TASK_BOOTSTRAP_PORT, &bs_port);
  if (kr != KERN_SUCCESS) {
    helper_log("task_get_special_port(sketchybar) failed: %d", kr);
    return 0;
  }

  mach_port_t port;
  kr = bootstrap_look_up(bs_port, "git.felix.sketchybar", &port);
  if (kr != KERN_SUCCESS) {
    helper_log("bootstrap_look_up(git.felix.sketchybar) failed: %d", kr);
    return 0;
  }

  return port;
}

static inline mach_msg_return_t mach_receive_message(mach_port_t port,
                                                     struct mach_buffer *buffer,
                                                     bool timeout) {
  *buffer = (struct mach_buffer){0};
  mach_msg_return_t msg_return;
  if (timeout)
    msg_return =
        mach_msg(&buffer->message.header, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0,
                 sizeof(struct mach_buffer), port, 100, MACH_PORT_NULL);
  else
    msg_return = mach_msg(&buffer->message.header, MACH_RCV_MSG, 0,
                          sizeof(struct mach_buffer), port,
                          MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

  if (msg_return != MACH_MSG_SUCCESS) {
    if (msg_return != MACH_RCV_TIMED_OUT) {
      helper_log("mach_receive_message failed: port=%u timeout=%d return=%d",
                 port, timeout, msg_return);
    }
    buffer->message.descriptor.address = NULL;
  }

  return msg_return;
}

static inline bool mach_send_message(mach_port_t port, const char *message,
                                     uint32_t len) {
  if (!message || !port) {
    return false;
  }

  bool success = false;
  mach_port_t response_port = MACH_PORT_NULL;
  mach_port_name_t task = mach_task_self();
  kern_return_t kr = mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE,
                                        &response_port);
  if (kr != KERN_SUCCESS) {
    helper_log("mach_port_allocate(response) failed: %d", kr);
    return false;
  }

  struct mach_message msg = {0};
  msg.header.msgh_remote_port = port;
  msg.header.msgh_local_port = response_port;
  msg.header.msgh_id = response_port;
  msg.header.msgh_bits =
      MACH_MSGH_BITS_SET(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND, 0,
                         MACH_MSGH_BITS_COMPLEX);

  msg.header.msgh_size = sizeof(struct mach_message);
  msg.msgh_descriptor_count = 1;
  msg.descriptor.address = (void *)message;
  msg.descriptor.size = len * sizeof(char);
  msg.descriptor.copy = MACH_MSG_VIRTUAL_COPY;
  msg.descriptor.deallocate = false;
  msg.descriptor.type = MACH_MSG_OOL_DESCRIPTOR;

  kr = mach_msg(&msg.header, MACH_SEND_MSG, sizeof(struct mach_message), 0,
                MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
  if (kr != MACH_MSG_SUCCESS) {
    helper_log("mach_send_message failed: port=%u return=%d", port, kr);
    goto cleanup_port;
  }

  struct mach_buffer buffer = {0};
  mach_msg_return_t receive_result =
      mach_receive_message(response_port, &buffer, true);
  if (receive_result == MACH_MSG_SUCCESS) {
    mach_msg_destroy(&buffer.message.header);
    success = true;
  }

cleanup_port:
  kr = mach_port_mod_refs(task, response_port, MACH_PORT_RIGHT_RECEIVE, -1);
  if (kr != KERN_SUCCESS) {
    helper_log("mach_port_mod_refs(response) failed: port=%u return=%d",
               response_port, kr);
    return false;
  }

  return success;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline bool mach_server_begin(struct mach_server *mach_server,
                                     mach_handler handler,
                                     char *bootstrap_name) {
  mach_server->task = mach_task_self();

  kern_return_t kr = mach_port_allocate(mach_server->task,
                                        MACH_PORT_RIGHT_RECEIVE,
                                        &mach_server->port);
  if (kr != KERN_SUCCESS) {
    helper_log("mach_port_allocate(server) failed: %d", kr);
    return false;
  }

  kr = mach_port_insert_right(mach_server->task, mach_server->port,
                              mach_server->port, MACH_MSG_TYPE_MAKE_SEND);
  if (kr != KERN_SUCCESS) {
    helper_log("mach_port_insert_right(server) failed: %d", kr);
    return false;
  }

  kr = task_get_special_port(mach_server->task, TASK_BOOTSTRAP_PORT,
                             &mach_server->bs_port);
  if (kr != KERN_SUCCESS) {
    helper_log("task_get_special_port(server) failed: %d", kr);
    return false;
  }

  kr = bootstrap_register(mach_server->bs_port, bootstrap_name,
                          mach_server->port);
  if (kr != KERN_SUCCESS) {
    helper_log("bootstrap_register(%s) failed: %d", bootstrap_name, kr);
    return false;
  }
  helper_log("bootstrap_register(%s) ok", bootstrap_name);

  mach_server->handler = handler;
  mach_server->is_running = true;
  helper_signal_ready();

  struct mach_buffer buffer;
  unsigned int receive_failures = 0;
  while (mach_server->is_running) {
    mach_msg_return_t receive_result =
        mach_receive_message(mach_server->port, &buffer, false);

    if (receive_result != MACH_MSG_SUCCESS) {
      receive_failures++;
      if (receive_failures >= 5) {
        helper_log("mach receive failed %u consecutive times; exiting",
                   receive_failures);
        _exit(EX_TEMPFAIL);
      }

      struct timespec retry_delay = {
          .tv_sec = 0,
          .tv_nsec = 100000000L << (receive_failures - 1),
      };
      nanosleep(&retry_delay, NULL);
      continue;
    }

    receive_failures = 0;
    if (!buffer.message.descriptor.address) {
      helper_log("received mach message without descriptor");
      mach_msg_destroy(&buffer.message.header);
      continue;
    }

    mach_server->handler((env)buffer.message.descriptor.address);
    mach_msg_destroy(&buffer.message.header);
  }

  return true;
}
#pragma clang diagnostic pop

static inline bool sketchybar(const char *message) {
  uint32_t message_length = strlen(message) + 1;
  char formatted_message[message_length + 1];

  char quote = '\0';
  uint32_t caret = 0;
  for (uint32_t i = 0; i < message_length; ++i) {
    if (message[i] == '"' || message[i] == '\'') {
      if (quote == message[i])
        quote = '\0';
      else
        quote = message[i];
      continue;
    }
    formatted_message[caret] = message[i];
    if (message[i] == ' ' && !quote)
      formatted_message[caret] = '\0';
    caret++;
  }

  // Collapse a trailing double NUL produced by a trailing space + source NUL.
  if (caret >= 2 && formatted_message[caret - 1] == '\0' &&
      formatted_message[caret - 2] == '\0') {
    caret--;
  }

  formatted_message[caret] = '\0';
  if (!g_mach_port)
    g_mach_port = mach_get_bs_port();
  return mach_send_message(g_mach_port, formatted_message, caret + 1);
}

static inline void event_server_begin(mach_handler event_handler,
                                      char *bootstrap_name) {
  if (!mach_server_begin(&g_mach_server, event_handler, bootstrap_name))
    exit(2);
}
