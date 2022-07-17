/*===-- idiv0.c - 32-bit unsigned integer divide --------------------------===//
 *
 *                     The LLVM Compiler Infrastructure
 *
 * This file is dual licensed under the MIT and the University of Illinois Open
 * Source Licenses. See LICENSE.TXT for details.
 *
 *===----------------------------------------------------------------------===//
 *
 * This file implements the __aeabi_idiv0 and __aeabi_uidiv0
 * function for the ARM 32-bit architecture.
 *
 *===----------------------------------------------------------------------===*/
#pragma once
#include <signal.h>
extern "C" {
#ifdef __ARM_EABI__
extern int __aeabi_idiv0(void);
extern int __aeabi_uidiv0(void);
#endif
}
