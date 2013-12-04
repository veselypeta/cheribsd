/*-
 * Copyright (c) 2012-2013 Robert N. M. Watson
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract (FA8750-10-C-0237)
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SANDBOX_H_
#define	_SANDBOX_H_

/*
 * Per-sandbox meta-data structure mapped read-only within the sandbox at a
 * fixed address to allow sandboxed code to find its stack, heap, etc.
 *
 * NB: This data structure (and its base address) are part of the ABI between
 * libcheri and programs running in sandboxes.  Only ever append to this,
 * don't modify the order, lengths, or interpretations of existing fields.  If
 * this reaches a page in size, then allocation code in sandbox.c will need
 * updating.  See also sandbox.c and sandboxasm.h.
 */
struct sandbox_metadata {
	register_t	sbm_heapbase;		/* Offset: 0 */
	register_t	sbm_heaplen;		/* Offset: 8 */
};

extern int sb_verbose;

struct sandbox;
int	sandbox_setup(const char *path, register_t sandboxlen,
	    struct sandbox **sbp);
void	sandbox_destroy(struct sandbox *sb);

#if defined(__CHERI__) && defined(__capability)
register_t
sandbox_cinvoke(struct sandbox *sb, register_t a0, register_t a1,
    register_t a2, register_t a3, register_t a4, register_t a5, register_t a6,
    register_t a7, __capability void *c3, __capability void *c4,
    __capability void *c5, __capability void *c6, __capability void *c7,
    __capability void *c8, __capability void *c9, __capability void *c10);
#endif
register_t	sandbox_invoke(struct sandbox *sb, register_t a0,
	    register_t a1, register_t a2, register_t a3, struct chericap *c3,
	    struct chericap *c4, struct chericap *c5, struct chericap *c6,
	    struct chericap *c7, struct chericap *c8, struct chericap *c9,
	    struct chericap *c10);

#endif /* !_SANDBOX_H_ */
