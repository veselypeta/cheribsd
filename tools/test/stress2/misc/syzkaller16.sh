#!/bin/sh

# Fatal trap 9: general protection fault while in kernel mode
# cpuid = 10; apic id = 0a
# instruction pointer     = 0x20:0xffffffff80db1fd9
# stack pointer           = 0x0:0xfffffe00e2240660
# frame pointer           = 0x0:0xfffffe00e2240830
# code segment            = base 0x0, limit 0xfffff, type 0x1b
#                         = DPL 0, pres 1, long 1, def32 0, gran 1
# processor eflags        = interrupt enabled, resume, IOPL = 0
# current process         = 29524 (syzkaller16)
# trap number             = 9
# panic: general protection fault
# cpuid = 10
# time = 1592652215
# KDB: stack backtrace:
# db_trace_self_wrapper() at db_trace_self_wrapper+0x2b/frame 0xfffffe00e2240370
# vpanic() at vpanic+0x182/frame 0xfffffe00e22403c0
# panic() at panic+0x43/frame 0xfffffe00e2240420
# trap_fatal() at trap_fatal+0x387/frame 0xfffffe00e2240480
# trap() at trap+0x80/frame 0xfffffe00e2240590
# calltrap() at calltrap+0x8/frame 0xfffffe00e2240590
# --- trap 0x9, rip = 0xffffffff80db1fd9, rsp = 0xfffffe00e2240660, rbp = 0xfffffe00e2240830 ---
# sctp_lower_sosend() at sctp_lower_sosend+0x21b9/frame 0xfffffe00e2240830
# sctp_sosend() at sctp_sosend+0x346/frame 0xfffffe00e2240950
# sosend() at sosend+0x66/frame 0xfffffe00e2240980
# kern_sendit() at kern_sendit+0x246/frame 0xfffffe00e2240a20
# sendit() at sendit+0x1d8/frame 0xfffffe00e2240a70
# sys_sendto() at sys_sendto+0x4d/frame 0xfffffe00e2240ac0
# ia32_syscall() at ia32_syscall+0x150/frame 0xfffffe00e2240bf0
# int0x80_syscall_common() at int0x80_syscall_common+0x9c/frame 0xfbffcf8c
# db> x/s version
# version: FreeBSD 13.0-CURRENT #0 r362431: Sat Jun 20 09:52:53 CEST 2020
# pho@mercat1.netperf.freebsd.org:/usr/src/sys/amd64/compile/PHO
# db> 

[ `uname -p` != "amd64" ] && exit 0

. ../default.cfg
kldstat -v | grep -q sctp || kldload sctp.ko
cat > /tmp/syzkaller16.c <<EOF
// https://syzkaller.appspot.com/bug?id=4b11a1abc41d0a67736ef9a7506ab3ec7e378102
// autogenerated by syzkaller (https://github.com/google/syzkaller)
// Reported-by: syzbot+bc02585076c3cc977f9b@syzkaller.appspotmail.com

#define _GNU_SOURCE

#include <sys/types.h>

#include <errno.h>
#include <pthread.h>
#include <pwd.h>
#include <setjmp.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/endian.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static unsigned long long procid;

static __thread int skip_segv;
static __thread jmp_buf segv_env;

static void segv_handler(int sig, siginfo_t* info, void* ctx __unused)
{
  uintptr_t addr = (uintptr_t)info->si_addr;
  const uintptr_t prog_start = 1 << 20;
  const uintptr_t prog_end = 100 << 20;
  if (__atomic_load_n(&skip_segv, __ATOMIC_RELAXED) &&
      (addr < prog_start || addr > prog_end)) {
    _longjmp(segv_env, 1);
  }
  exit(sig);
}

static void install_segv_handler(void)
{
  struct sigaction sa;
  memset(&sa, 0, sizeof(sa));
  sa.sa_sigaction = segv_handler;
  sa.sa_flags = SA_NODEFER | SA_SIGINFO;
  sigaction(SIGSEGV, &sa, NULL);
  sigaction(SIGBUS, &sa, NULL);
}

#define NONFAILING(...)                                                        \
  {                                                                            \
    __atomic_fetch_add(&skip_segv, 1, __ATOMIC_SEQ_CST);                       \
    if (_setjmp(segv_env) == 0) {                                              \
      __VA_ARGS__;                                                             \
    }                                                                          \
    __atomic_fetch_sub(&skip_segv, 1, __ATOMIC_SEQ_CST);                       \
  }

static void kill_and_wait(int pid, int* status)
{
  kill(pid, SIGKILL);
  while (waitpid(-1, status, 0) != pid) {
  }
}

static void sleep_ms(uint64_t ms)
{
  usleep(ms * 1000);
}

static uint64_t current_time_ms(void)
{
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts))
    exit(1);
  return (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;
}

static void thread_start(void* (*fn)(void*), void* arg)
{
  pthread_t th;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, 128 << 10);
  int i;
  for (i = 0; i < 100; i++) {
    if (pthread_create(&th, &attr, fn, arg) == 0) {
      pthread_attr_destroy(&attr);
      return;
    }
    if (errno == EAGAIN) {
      usleep(50);
      continue;
    }
    break;
  }
  exit(1);
}

typedef struct {
  pthread_mutex_t mu;
  pthread_cond_t cv;
  int state;
} event_t;

static void event_init(event_t* ev)
{
  if (pthread_mutex_init(&ev->mu, 0))
    exit(1);
  if (pthread_cond_init(&ev->cv, 0))
    exit(1);
  ev->state = 0;
}

static void event_reset(event_t* ev)
{
  ev->state = 0;
}

static void event_set(event_t* ev)
{
  pthread_mutex_lock(&ev->mu);
  if (ev->state)
    exit(1);
  ev->state = 1;
  pthread_mutex_unlock(&ev->mu);
  pthread_cond_broadcast(&ev->cv);
}

static void event_wait(event_t* ev)
{
  pthread_mutex_lock(&ev->mu);
  while (!ev->state)
    pthread_cond_wait(&ev->cv, &ev->mu);
  pthread_mutex_unlock(&ev->mu);
}

static int event_isset(event_t* ev)
{
  pthread_mutex_lock(&ev->mu);
  int res = ev->state;
  pthread_mutex_unlock(&ev->mu);
  return res;
}

static int event_timedwait(event_t* ev, uint64_t timeout)
{
  uint64_t start = current_time_ms();
  uint64_t now = start;
  pthread_mutex_lock(&ev->mu);
  for (;;) {
    if (ev->state)
      break;
    uint64_t remain = timeout - (now - start);
    struct timespec ts;
    ts.tv_sec = remain / 1000;
    ts.tv_nsec = (remain % 1000) * 1000 * 1000;
    pthread_cond_timedwait(&ev->cv, &ev->mu, &ts);
    now = current_time_ms();
    if (now - start > timeout)
      break;
  }
  int res = ev->state;
  pthread_mutex_unlock(&ev->mu);
  return res;
}

struct thread_t {
  int created, call;
  event_t ready, done;
};

static struct thread_t threads[16];
static void execute_call(int call);
static int running;

static void* thr(void* arg)
{
  struct thread_t* th = (struct thread_t*)arg;
  for (;;) {
    event_wait(&th->ready);
    event_reset(&th->ready);
    execute_call(th->call);
    __atomic_fetch_sub(&running, 1, __ATOMIC_RELAXED);
    event_set(&th->done);
  }
  return 0;
}

static void execute_one(void)
{
  int i, call, thread;
  int collide = 0;
again:
  for (call = 0; call < 6; call++) {
    for (thread = 0; thread < (int)(sizeof(threads) / sizeof(threads[0]));
         thread++) {
      struct thread_t* th = &threads[thread];
      if (!th->created) {
        th->created = 1;
        event_init(&th->ready);
        event_init(&th->done);
        event_set(&th->done);
        thread_start(thr, th);
      }
      if (!event_isset(&th->done))
        continue;
      event_reset(&th->done);
      th->call = call;
      __atomic_fetch_add(&running, 1, __ATOMIC_RELAXED);
      event_set(&th->ready);
      if (collide && (call % 2) == 0)
        break;
      event_timedwait(&th->done, 45);
      break;
    }
  }
  for (i = 0; i < 100 && __atomic_load_n(&running, __ATOMIC_RELAXED); i++)
    sleep_ms(1);
  if (!collide) {
    collide = 1;
    goto again;
  }
}

static void execute_one(void);

#define WAIT_FLAGS 0

static void loop(void)
{
  int iter;
  for (iter = 0;; iter++) {
    int pid = fork();
    if (pid < 0)
      exit(1);
    if (pid == 0) {
      execute_one();
      exit(0);
    }
    int status = 0;
    uint64_t start = current_time_ms();
    for (;;) {
      if (waitpid(-1, &status, WNOHANG | WAIT_FLAGS) == pid)
        break;
      sleep_ms(1);
      if (current_time_ms() - start < 5 * 1000)
        continue;
      kill_and_wait(pid, &status);
      break;
    }
  }
}

uint64_t r[1] = {0xffffffffffffffff};

void execute_call(int call)
{
  intptr_t res = 0;
  switch (call) {
  case 0:
    res = syscall(SYS_socket, 0x1c, 1, 0x84);
    if (res != -1)
      r[0] = res;
    break;
  case 1:
    NONFAILING(*(uint8_t*)0x10000000 = 0x1c);
    NONFAILING(*(uint8_t*)0x10000001 = 0x1c);
    NONFAILING(*(uint16_t*)0x10000002 = htobe16(0x4e22 + procid * 4));
    NONFAILING(*(uint32_t*)0x10000004 = 0);
    NONFAILING(*(uint8_t*)0x10000008 = 0);
    NONFAILING(*(uint8_t*)0x10000009 = 0);
    NONFAILING(*(uint8_t*)0x1000000a = 0);
    NONFAILING(*(uint8_t*)0x1000000b = 0);
    NONFAILING(*(uint8_t*)0x1000000c = 0);
    NONFAILING(*(uint8_t*)0x1000000d = 0);
    NONFAILING(*(uint8_t*)0x1000000e = 0);
    NONFAILING(*(uint8_t*)0x1000000f = 0);
    NONFAILING(*(uint8_t*)0x10000010 = 0);
    NONFAILING(*(uint8_t*)0x10000011 = 0);
    NONFAILING(*(uint8_t*)0x10000012 = 0);
    NONFAILING(*(uint8_t*)0x10000013 = 0);
    NONFAILING(*(uint8_t*)0x10000014 = 0);
    NONFAILING(*(uint8_t*)0x10000015 = 0);
    NONFAILING(*(uint8_t*)0x10000016 = 0);
    NONFAILING(*(uint8_t*)0x10000017 = 0);
    NONFAILING(*(uint32_t*)0x10000018 = 0);
    syscall(SYS_bind, (intptr_t)r[0], 0x10000000, 0x1c);
    break;
  case 2:
    NONFAILING(*(uint8_t*)0x10000180 = 0x5f);
    NONFAILING(*(uint8_t*)0x10000181 = 0x1c);
    NONFAILING(*(uint16_t*)0x10000182 = htobe16(0x4e22 + procid * 4));
    NONFAILING(*(uint32_t*)0x10000184 = 0);
    NONFAILING(*(uint64_t*)0x10000188 = htobe64(0));
    NONFAILING(*(uint64_t*)0x10000190 = htobe64(1));
    NONFAILING(*(uint32_t*)0x10000198 = 0);
    syscall(SYS_connect, (intptr_t)r[0], 0x10000180, 0x1c);
    break;
  case 3:
    NONFAILING(*(uint32_t*)0x100001c0 = 0x401);
    syscall(SYS_setsockopt, (intptr_t)r[0], 0x84, 0x1b, 0x100001c0, 4);
    break;
  case 4:
    NONFAILING(memcpy(
        (void*)0x10000380,
        "\xa3\x1b\xe1\x78\x8e\x58\x9b\x38\x59\xf3\xbb\xdd\x7e\xf7\x51\x23\x97"
        "\x31\xb2\x90\x4a\xd0\x4e\xb7\xdc\x37\xc6\x95\xf6\x05\x5c\xa8\x36\x54"
        "\x7e\x7b\x6c\xc3\x7d\xae\x2a\xe4\x77\x08\x94\x67\x3c\x89\x65\x93\x24"
        "\x1c\x56\x3e\x08\x69\x05\x35\xeb\x3b\x7f\x19\x7d\xda\x44\x54\xb4\x42"
        "\x4f\x7f\xf9\xf9\xfe\x4e\xac\xef\xa6\xd4\xb1\x61\x9d\xd9\x0b\x97\x7c"
        "\xd9\x82\x16\xc9\x7b\x2e\xb3\x9f\x02\xde\x0f\xae\xe7\x0b\xec\xa3\x66"
        "\x3c\x2e\x6c\xc5\x1d\xa2\xb4\x8b\x4b\x39\x49\xcc\x14\x5a\x50\x62\x0f"
        "\xd5\x65\xb9\x7c\x5c\xa0\xea\xfc\xa4\xc9\x13\x73\x14\x16\xba\xcc\xae"
        "\x89\xe2\x68\x01\x06\x94\x78\xa3\xee\xa8\x45\xf7\xc2\xcb\x48\x93\xe5"
        "\x83\x52\x45\x26\xe3\xeb\x73\xa2\xe4\xf1\x11\xcf\x40\x5f\xef\x99\xc2"
        "\xa1\xeb\x2c\x96\x70\x56\x88\xc8\xc7\x6b\xa1\x66\xd2\x23\x20\x07\x62"
        "\x69\xd2\x1c\x52\xbb\x5e\x86\x43\x7d\x6c\x65\x44\x42\xf6\xd8\x45\xe2"
        "\x00\x24\x00\x00\xf0\x1d\x29\xf6\xd3\x74\x83\x25\x40\x56\x50\x17\x7f"
        "\xc3\x60\xd7\xed\xb1\xfb\x7a\x74\x38\x2b\x47\x34\x93\x9c\xee\xc9\xb0"
        "\xbf\x7d\xc4\x19\xe2\x77\x4c\xa2\x71\x9c\x30",
        249));
    NONFAILING(*(uint8_t*)0x10000140 = 0x10);
    NONFAILING(*(uint8_t*)0x10000141 = 2);
    NONFAILING(*(uint16_t*)0x10000142 = htobe16(0x4e22 + procid * 4));
    NONFAILING(*(uint32_t*)0x10000144 = htobe32(-1));
    NONFAILING(*(uint8_t*)0x10000148 = 0);
    NONFAILING(*(uint8_t*)0x10000149 = 0);
    NONFAILING(*(uint8_t*)0x1000014a = 0);
    NONFAILING(*(uint8_t*)0x1000014b = 0);
    NONFAILING(*(uint8_t*)0x1000014c = 0);
    NONFAILING(*(uint8_t*)0x1000014d = 0);
    NONFAILING(*(uint8_t*)0x1000014e = 0);
    NONFAILING(*(uint8_t*)0x1000014f = 0);
    syscall(SYS_sendto, (intptr_t)r[0], 0x10000380, 0xfffffcaa, 0x20000,
            0x10000140, 0x10);
    break;
  case 5:
    NONFAILING(*(uint32_t*)0x10000540 = 0);
    NONFAILING(*(uint32_t*)0x10000544 = 0);
    NONFAILING(*(uint32_t*)0x10000548 = 0);
    NONFAILING(*(uint32_t*)0x1000054c = 0);
    NONFAILING(*(uint32_t*)0x10000550 = 0);
    NONFAILING(*(uint32_t*)0x10000554 = 0);
    NONFAILING(*(uint32_t*)0x10000558 = 0x20008);
    syscall(SYS_sendmsg, (intptr_t)r[0], 0x10000540, 0x100);
    break;
  }
}
int main(void)
{
  syscall(SYS_mmap, 0x10000000, 0x1000000, 7, 0x1012, -1, 0);
  install_segv_handler();
  for (procid = 0; procid < 4; procid++) {
    if (fork() == 0) {
      loop();
    }
  }
  sleep(1000000);
  return 0;
}
EOF
mycc -o /tmp/syzkaller16 -Wall -Wextra -O0 -m32 /tmp/syzkaller16.c -pthread ||
    exit 1

(cd ../testcases/swap; ./swap -t 1m -i 20 -h > /dev/null 2>&1) &
(cd /tmp; ./syzkaller16) &
sleep 60
pkill -9 syzkaller16 swap
wait

rm -f /tmp/syzkaller16 /tmp/syzkaller16.c /tmp/syzkaller16.core
exit 0
