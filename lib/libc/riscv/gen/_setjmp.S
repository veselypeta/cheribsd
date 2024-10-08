/*-
 * Copyright (c) 2015-2016 Ruslan Bukin <br@bsdpad.com>
 * All rights reserved.
 *
 * Portions of this software were developed by SRI International and the
 * University of Cambridge Computer Laboratory under DARPA/AFRL contract
 * FA8750-10-C-0237 ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * Portions of this software were developed by the University of Cambridge
 * Computer Laboratory as part of the CTSRD Project, with support from the
 * UK Higher Education Innovation Fund (HEIF).
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

#include <machine/asm.h>
#include <machine/setjmp.h>

ENTRY(_setjmp)
#ifdef __CHERI_PURE_CAPABILITY__
	/* Store the magic value and stack pointer */
	cllc	ct0, .Lmagic
	cld	t0, (ct0)
	csc	ct0, (0 * 16)(ca0)
	csc	csp, (1 * 16)(ca0)
	cincoffset ca0, ca0, (2 * 16)

	/* Store the general purpose registers and ra */
	csc	cs0, (0 * 16)(ca0)
	csc	cs1, (1 * 16)(ca0)
	csc	cs2, (2 * 16)(ca0)
	csc	cs3, (3 * 16)(ca0)
	csc	cs4, (4 * 16)(ca0)
	csc	cs5, (5 * 16)(ca0)
	csc	cs6, (6 * 16)(ca0)
	csc	cs7, (7 * 16)(ca0)
	csc	cs8, (8 * 16)(ca0)
	csc	cs9, (9 * 16)(ca0)
	csc	cs10, (10 * 16)(ca0)
	csc	cs11, (11 * 16)(ca0)
	csc	cra, (12 * 16)(ca0)
	cspecialr ct0, ddc
	csc	ct0, (13 * 16)(ca0)
	cincoffset ca0, ca0, (14 * 16)

#if !defined(_STANDALONE) && defined(__riscv_float_abi_double)
	/* Store the fpe registers */
	cfsd	fs0, (0 * 8)(ca0)
	cfsd	fs1, (1 * 8)(ca0)
	cfsd	fs2, (2 * 8)(ca0)
	cfsd	fs3, (3 * 8)(ca0)
	cfsd	fs4, (4 * 8)(ca0)
	cfsd	fs5, (5 * 8)(ca0)
	cfsd	fs6, (6 * 8)(ca0)
	cfsd	fs7, (7 * 8)(ca0)
	cfsd	fs8, (8 * 8)(ca0)
	cfsd	fs9, (9 * 8)(ca0)
	cfsd	fs10, (10 * 8)(ca0)
	cfsd	fs11, (11 * 8)(ca0)
	cincoffset ca0, ca0, (12 * 8)
#endif

	/* Return value */
	li	a0, 0
	cret
#else
	/* Store the magic value and stack pointer */
	ld	t0, .Lmagic
	sd	t0, (0 * 8)(a0)
	sd	sp, (1 * 8)(a0)
	addi	a0, a0, (2 * 8)

	/* Store the general purpose registers and ra */
	sd	s0, (0 * 8)(a0)
	sd	s1, (1 * 8)(a0)
	sd	s2, (2 * 8)(a0)
	sd	s3, (3 * 8)(a0)
	sd	s4, (4 * 8)(a0)
	sd	s5, (5 * 8)(a0)
	sd	s6, (6 * 8)(a0)
	sd	s7, (7 * 8)(a0)
	sd	s8, (8 * 8)(a0)
	sd	s9, (9 * 8)(a0)
	sd	s10, (10 * 8)(a0)
	sd	s11, (11 * 8)(a0)
	sd	ra, (12 * 8)(a0)
	addi	a0, a0, (13 * 8)

#if !defined(_STANDALONE) && defined(__riscv_float_abi_double)
	/* Store the fpe registers */
	fsd	fs0, (0 * 8)(a0)
	fsd	fs1, (1 * 8)(a0)
	fsd	fs2, (2 * 8)(a0)
	fsd	fs3, (3 * 8)(a0)
	fsd	fs4, (4 * 8)(a0)
	fsd	fs5, (5 * 8)(a0)
	fsd	fs6, (6 * 8)(a0)
	fsd	fs7, (7 * 8)(a0)
	fsd	fs8, (8 * 8)(a0)
	fsd	fs9, (9 * 8)(a0)
	fsd	fs10, (10 * 8)(a0)
	fsd	fs11, (11 * 8)(a0)
	addi	a0, a0, (12 * 8)
#endif

	/* Return value */
	li	a0, 0
	ret
#endif
	.align	3
.Lmagic:
	.quad	_JB_MAGIC__SETJMP
END(_setjmp)

ENTRY(_longjmp)
#ifdef __CHERI_PURE_CAPABILITY__
	/* Check the magic value */
	cld	t0, 0(ca0)
	cllc	ct1, .Lmagic
	cld	t1, (ct1)
	bne	t0, t1, botch

	/* Restore the stack pointer */
	clc	csp, 16(ca0)
	cincoffset ca0, ca0, (2 * 16)

	/* Restore the general purpose registers and ra */
	clc	cs0, (0 * 16)(ca0)
	clc	cs1, (1 * 16)(ca0)
	clc	cs2, (2 * 16)(ca0)
	clc	cs3, (3 * 16)(ca0)
	clc	cs4, (4 * 16)(ca0)
	clc	cs5, (5 * 16)(ca0)
	clc	cs6, (6 * 16)(ca0)
	clc	cs7, (7 * 16)(ca0)
	clc	cs8, (8 * 16)(ca0)
	clc	cs9, (9 * 16)(ca0)
	clc	cs10, (10 * 16)(ca0)
	clc	cs11, (11 * 16)(ca0)
	clc	cra, (12 * 16)(ca0)
	clc	ct0, (13 * 16)(ca0)
	cspecialw ddc, ct0
	cincoffset ca0, ca0, (14 * 16)

#if !defined(_STANDALONE) && defined(__riscv_float_abi_double)
	/* Restore the fpe registers */
	cfld	fs0, (0 * 8)(ca0)
	cfld	fs1, (1 * 8)(ca0)
	cfld	fs2, (2 * 8)(ca0)
	cfld	fs3, (3 * 8)(ca0)
	cfld	fs4, (4 * 8)(ca0)
	cfld	fs5, (5 * 8)(ca0)
	cfld	fs6, (6 * 8)(ca0)
	cfld	fs7, (7 * 8)(ca0)
	cfld	fs8, (8 * 8)(ca0)
	cfld	fs9, (9 * 8)(ca0)
	cfld	fs10, (10 * 8)(ca0)
	cfld	fs11, (11 * 8)(ca0)
	cincoffset ca0, ca0, (12 * 8)
#endif

	/* Load the return value */
	mv	a0, a1
	cret
#else
	/* Check the magic value */
	ld	t0, 0(a0)
	ld	t1, .Lmagic
	bne	t0, t1, botch

	/* Restore the stack pointer */
	ld	t0, 8(a0)
	mv	sp, t0
	addi	a0, a0, (2 * 8)

	/* Restore the general purpose registers and ra */
	ld	s0, (0 * 8)(a0)
	ld	s1, (1 * 8)(a0)
	ld	s2, (2 * 8)(a0)
	ld	s3, (3 * 8)(a0)
	ld	s4, (4 * 8)(a0)
	ld	s5, (5 * 8)(a0)
	ld	s6, (6 * 8)(a0)
	ld	s7, (7 * 8)(a0)
	ld	s8, (8 * 8)(a0)
	ld	s9, (9 * 8)(a0)
	ld	s10, (10 * 8)(a0)
	ld	s11, (11 * 8)(a0)
	ld	ra, (12 * 8)(a0)
	addi	a0, a0, (13 * 8)

#if !defined(_STANDALONE) && defined(__riscv_float_abi_double)
	/* Restore the fpe registers */
	fld	fs0, (0 * 8)(a0)
	fld	fs1, (1 * 8)(a0)
	fld	fs2, (2 * 8)(a0)
	fld	fs3, (3 * 8)(a0)
	fld	fs4, (4 * 8)(a0)
	fld	fs5, (5 * 8)(a0)
	fld	fs6, (6 * 8)(a0)
	fld	fs7, (7 * 8)(a0)
	fld	fs8, (8 * 8)(a0)
	fld	fs9, (9 * 8)(a0)
	fld	fs10, (10 * 8)(a0)
	fld	fs11, (11 * 8)(a0)
	addi	a0, a0, (12 * 8)
#endif

	/* Load the return value */
	mv	a0, a1
	bnez	a1, 1f
	li	a0, 1
1:
	ret
#endif

botch:
#ifdef _STANDALONE
	j	botch
#elif defined(__CHERI_PURE_CAPABILITY__)
	clgc	ct0, _C_LABEL(longjmperror)
	cjalr	ct0
	clgc	ct0, _C_LABEL(abort)
	cjalr	ct0
#else
	call	_C_LABEL(longjmperror)
	call	_C_LABEL(abort)
#endif
END(_longjmp)
