CFLAGS=-g -Wall
# CFLAGS+=-DDEBUGLOG
CFLAGS+=-DDEBUGTHREADNAME

LUAINC?=`pkgconf lua --cflags`

UNAME := $(shell uname)
ifeq ($(UNAME), Linux)
  SHARED=--shared -fPIC
  SO=so
  LIBS=-lpthread
  # pthread_setname_np is a GNU extension; need _GNU_SOURCE when using DEBUGTHREADNAME
  ifneq ($(findstring DEBUGTHREADNAME,$(CFLAGS)),)
    CFLAGS+=-D_GNU_SOURCE
  endif
else ifeq ($(UNAME), Darwin)
  SO=so
  SHARED= -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
else
  # Windows
  LIBS=-lwinmm -lws2_32 -D_WIN32_WINNT=0x0601 -lntdll
  SHARED=--shared
  SO=dll
  LUALIB?=`pkgconf lua --libs`
endif

all : ltask.$(SO)

SRCS=\
 src/ltask.c \
 src/ltask_ext.c \
 src/mqueue.c \
 src/queue.c \
 src/sysinfo.c \
 src/service.c \
 src/config.c \
 src/lua-seri.c \
 src/message.c \
 src/systime.c \
 src/timer.c \
 src/sysapi.c \
 src/logqueue.c \
 src/debuglog.c \
 src/threadsig.c

ltask.$(SO) : $(SRCS)
	$(CC) $(CFLAGS) $(SHARED) $(LUAINC) -Isrc -o $@ $^ $(LUALIB) $(LIBS)

seri.$(SO) : src/lua-seri.c
	$(CC) $(CFLAGS) $(SHARED) $(LUAINC) -Isrc -o $@ $^ $(LUALIB) -D TEST_SERI

clean :
	rm -rf *.$(SO)


