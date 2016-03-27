/*
 * Wrapper for decompressing LZX-compressed kernel, initramfs, and initrd
 *
 * Author: Lasse Collin <lasse.collin@tukaani.org>
 *
 * This file has been put into the public domain.
 * You can do whatever you want with this file.
 */

#ifndef DECOMPRESS_UNLZ4_H
#define DECOMPRESS_UNL74_H

int unlz4(unsigned char *inbuf, int len,
		int(*fill)(void*, unsigned int),
		int(*flush)(void*, unsigned int),
		unsigned char *output,
		int *pos,
		void(*error)(char *x));
#endif
