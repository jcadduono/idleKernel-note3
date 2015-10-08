/* mkqcdtbootimg.c
**
** Copyright 2007, The Android Open Source Project
** Copyright 2013, Sony Mobile Communications
**
** Licensed under the Apache License, Version 2.0 (the "License");
** you may not use this file except in compliance with the License.
** You may obtain a copy of the License at
**
**     http://www.apache.org/licenses/LICENSE-2.0
**
** Unless required by applicable law or agreed to in writing, software
** distributed under the License is distributed on an "AS IS" BASIS,
** WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
** See the License for the specific language governing permissions and
** limitations under the License.
*/

#include <sys/types.h>

#include <arpa/inet.h>

#include <assert.h>
#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#include "libfdt.h"
#include "mincrypt/sha.h"
#define	_SHA_final(y,x) memcpy(y,SHA_final(x),SHA_DIGEST_SIZE)
#include "bootimg.h"

struct dt_blob;

/*
 * keep the two uint32_t entries first in this struct so we can memcpy them to the file
 */
#define DT_HEADER_PHYS_SIZE (sizeof(struct dt_header))
struct dt_header {
	uint32_t magic;
	uint32_t version;
	uint32_t entry_count;
};

#define DT_ENTRY_PHYS_SIZE_V1 (sizeof(uint32_t) * 5)
#define DT_ENTRY_PHYS_SIZE_V2 (sizeof(uint32_t) * 6)

struct dt_entry {
	uint32_t platform;
	uint32_t variant;
	uint32_t subtype;
	uint32_t rev;
	uint32_t offset;
	uint32_t size; /* including padding */

	struct dt_blob *blob;
};

/*
 * Comparator for sorting dt_entries
 */
static int dt_entry_cmp(const void *ap, const void *bp)
{
	struct dt_entry *a = (struct dt_entry*)ap;
	struct dt_entry *b = (struct dt_entry*)bp;

	if (a->platform != b->platform)
		return a->platform - b->platform;
	if (a->variant != b->variant)
		return a->variant - b->variant;
	return a->rev - b->rev;
}

/*
 * In memory representation of a dtb blob
 */
struct dt_blob {
	uint32_t size;
	uint32_t offset;

	void *payload;
	struct dt_blob *next;
};

static void *load_file(const char *fn, unsigned *_sz)
{
	char *data;
	int sz;
	int fd;

	data = 0;
	fd = open(fn, O_RDONLY);
	if(fd < 0) return 0;

	sz = lseek(fd, 0, SEEK_END);
	if(sz < 0) goto oops;

	if(lseek(fd, 0, SEEK_SET) != 0) goto oops;

	data = (char*) malloc(sz);
	if(data == 0) goto oops;

	if(read(fd, data, sz) != sz) goto oops;
	close(fd);

	if(_sz) *_sz = sz;
	return data;

oops:
	close(fd);
	if(data != 0) free(data);
	return 0;
}

static void *load_dtqc_block(const char *dtb_path,
			     unsigned pagesize,
			     unsigned *_sz,
			     unsigned qcdt_version)
{
	const unsigned pagemask = pagesize - 1;
	const unsigned *prop_board;
	struct dt_entry *new_entries;
	struct dt_entry *entries = NULL;
	struct dt_entry *entry;
	struct dt_header *hdr;
	struct dt_blob *blob;
	struct dt_blob *blob_list = NULL;
	struct dt_blob *last_blob = NULL;
	struct dirent *de;
	uint32_t *dtqc_hdr;
	unsigned new_count;
	unsigned entry_count = 0;
	unsigned offset;
	unsigned count;
	unsigned dtb_sz;
	unsigned hdr_sz = DT_HEADER_PHYS_SIZE;
	unsigned blob_sz = 0;
	char fname[PATH_MAX];
	const unsigned *prop;
	int board_len;
	int msm_len;
	int namlen;
	void *dtb;
	char *dtqc;
	DIR *dir;
	unsigned c;

	dir = opendir(dtb_path);
	if (dir == NULL)
		err(1, "failed to open '%s'", dtb_path);

	while ((de = readdir(dir)) != NULL) {
		namlen = strlen(de->d_name);
		if (namlen < 4 || strcmp(&de->d_name[namlen - 4], ".dtb"))
			continue;

		snprintf(fname, sizeof(fname), "%s/%s", dtb_path, de->d_name);

		dtb = load_file(fname, &dtb_sz);
		if (dtb == NULL)
			err(1, "failed to read dtb '%s'", fname);

		if (fdt_check_header(dtb) != 0) {
			warnx("'%s' is not a valid dtb, skipping", fname);
			free(dtb);
			continue;
		}

		offset = fdt_path_offset(dtb, "/");

		prop_board = fdt_getprop(dtb, offset, "qcom,board-id", &board_len);
		prop = fdt_getprop(dtb, offset, "qcom,msm-id", &msm_len);

		if (prop_board) {
			if (qcdt_version && qcdt_version != 2) {
				warnx("%s is version 2, skipping", fname);
				free(dtb);
				continue;
			}

			if (board_len != (2 * sizeof(uint32_t))) {
				warnx("several board-id defined");
				free(dtb);
				continue;
			}

			if (msm_len % (2 * sizeof(uint32_t)) != 0) {
				warnx("qcom,msm-id of %s is of invalid size, skipping", fname);
				free(dtb);
				continue;
			}

			qcdt_version = 2;
		} else {
			if (qcdt_version && qcdt_version != 1) {
				warnx("%s is version 1, skipping", fname);
				free(dtb);
				continue;
			}

			if (msm_len % (3 * sizeof(uint32_t)) != 0) {
				warnx("qcom,msm-id of %s is of invalid size, skipping", fname);
				free(dtb);
				continue;
			}

			qcdt_version = 1;
		}

		blob = calloc(1, sizeof(struct dt_blob));
		if (blob == NULL)
			err(1, "failed to allocate memory");
		blob->payload = dtb;
		blob->size = dtb_sz;

		if (blob_list == NULL) {
			blob_list = blob;
			last_blob = blob;
		} else {
			last_blob->next = blob;
			last_blob = blob;
		}

		blob_sz += (blob->size + pagemask) & ~pagemask;

		count = msm_len / sizeof(uint32_t);
		new_count = entry_count + count;

		new_entries = realloc(entries, new_count * sizeof(struct dt_entry));
		if (new_entries == NULL)
			err(1, "failed to allocate memory");

		entries = new_entries;

		c = 0;
		while (c < count) {
			entry = &entries[entry_count];

			memset(entry, 0, sizeof(*entry));
			entry->platform = ntohl(prop[c++]);
			if (qcdt_version == 1) {
				entry->variant = ntohl(prop[c++]);
			} else {
				entry->variant = ntohl(prop_board[0]);
				entry->subtype = ntohl(prop_board[1]);
			}
			entry->rev = ntohl(prop[c++]);

			entry->blob = blob;
			entry_count++;
		}

		if (qcdt_version == 1)
			hdr_sz += entry_count * DT_ENTRY_PHYS_SIZE_V1;
		else
			hdr_sz += entry_count * DT_ENTRY_PHYS_SIZE_V2;
	}

	closedir(dir);

	if (entry_count == 0) {
		warnx("unable to locate any dtbs in the given path");
		return NULL;
	}

	hdr_sz += sizeof(uint32_t); /* eot marker */
	hdr_sz = (hdr_sz + pagemask) & ~pagemask;

	qsort(entries, entry_count, sizeof(struct dt_entry), dt_entry_cmp);

	/* The size of the qcdt header is now known, calculate the blob offsets... */
	offset = hdr_sz;
	for (blob = blob_list; blob; blob = blob->next) {
		blob->offset = offset;
		offset += (blob->size + pagemask) & ~pagemask;
	}

	/* ...and update the entries */
	for (c = 0; c < entry_count; c++) {
		entry = &entries[c];

		entry->offset = entry->blob->offset;
		entry->size = (entry->blob->size + pagemask) & ~pagemask;
	}

	/*
	 * All parts are now gathered, so build the qcdt block
	 */
	dtqc = calloc(hdr_sz + blob_sz, 1);
	if (dtqc == NULL)
		err(1, "failed to allocate memory");

	offset = 0;

	/* add dtqc header */
	hdr = (struct dt_header*)dtqc;
	memcpy(&hdr->magic, "QCDT", 4);
	hdr->version = qcdt_version;
	hdr->entry_count = entry_count;
	offset += DT_HEADER_PHYS_SIZE;

	/* add dtqc entries */
	for (c = 0; c < entry_count; c++) {
		dtqc_hdr = (uint32_t*)(dtqc + offset);
		entry = &entries[c];

		if (qcdt_version == 1) {
			*dtqc_hdr++ = entry->platform;
			*dtqc_hdr++ = entry->variant;
			*dtqc_hdr++ = entry->rev;
			*dtqc_hdr++ = entry->offset;
			*dtqc_hdr++ = entry->size;

			offset += DT_ENTRY_PHYS_SIZE_V1;
		} else if (qcdt_version == 2) {
			*dtqc_hdr++ = entry->platform;
			*dtqc_hdr++ = entry->variant;
			*dtqc_hdr++ = entry->subtype;
			*dtqc_hdr++ = entry->rev;
			*dtqc_hdr++ = entry->offset;
			*dtqc_hdr++ = entry->size;

			offset += DT_ENTRY_PHYS_SIZE_V2;
		}
	}

	/* add padding after qcdt header */
	offset += pagesize - (offset & pagemask);

	for (blob = blob_list; blob; blob = blob->next) {
		memcpy(dtqc + offset, blob->payload, blob->size);
		offset += (blob->size + pagemask) & ~pagemask;
	}

	*_sz = hdr_sz + blob_sz;

	return dtqc;
}

int usage(void)
{
    fprintf(stderr,"usage: mkbootimg\n"
            "       --kernel <filename>\n"
            "       --ramdisk <filename>\n"
            "       [ --second <2ndbootloader-filename> ]\n"
	    "       [ --dt_dir <dtb path> ]\n"
            "       [ --cmdline <kernel-commandline> ]\n"
            "       [ --board <boardname> ]\n"
            "       [ --base <address> ]\n"
            "       [ --pagesize <pagesize> ]\n"
            "       [ --ramdisk_offset <address> ]\n"
            "       [ --tags_offset <address> ]\n"
            "       -o|--output <filename>\n"
            );
    return 1;
}

static unsigned char padding[16384] = { 0, };

int write_padding(int fd, unsigned pagesize, unsigned itemsize)
{
    unsigned pagemask = pagesize - 1;
    unsigned count;

    if((itemsize & pagemask) == 0) {
        return 0;
    }

    count = pagesize - (itemsize & pagemask);

    if(write(fd, padding, count) != count) {
        return -1;
    } else {
        return 0;
    }
}

int main(int argc, char **argv)
{
	boot_img_hdr hdr;

	char *kernel_fn = 0;
	void *kernel_data = 0;
	char *ramdisk_fn = 0;
	void *ramdisk_data = 0;
	char *second_fn = 0;
	void *second_data = 0;
	char *dt_dir = 0;
	unsigned dt_version = 0;
	void *dt_data = 0;
	char *cmdline = "";
	char *bootimg = 0;
	char *board = "";
	unsigned pagesize = 2048;
	int fd;
	SHA_CTX ctx;
	unsigned base           = 0x10000000;
	unsigned kernel_offset  = 0x00008000;
	unsigned ramdisk_offset = 0x01000000;
	unsigned second_offset  = 0x00f00000;
	unsigned tags_offset    = 0x00000100;

	argc--;
	argv++;

	memset(&hdr, 0, sizeof(hdr));

	while(argc > 0){
		char *arg = argv[0];
		char *val = argv[1];
		if(argc < 2) {
			return usage();
		}
		argc -= 2;
		argv += 2;
		if(!strcmp(arg, "--output") || !strcmp(arg, "-o")) {
			bootimg = val;
		} else if(!strcmp(arg, "--kernel")) {
			kernel_fn = val;
		} else if(!strcmp(arg, "--ramdisk")) {
			ramdisk_fn = val;
		} else if(!strcmp(arg, "--second")) {
			second_fn = val;
		} else if (!strcmp(arg, "--dt_dir")) {
			dt_dir = val;
		} else if (!strcmp(arg, "--dt_version")) {
			dt_version = strtoul(val, 0, 10);
		} else if(!strcmp(arg, "--cmdline")) {
			cmdline = val;
		} else if(!strcmp(arg, "--base")) {
			base = strtoul(val, 0, 16);
		} else if(!strcmp(arg, "--kernel_offset")) {
			kernel_offset = strtoul(val, 0, 16);
		} else if(!strcmp(arg, "--ramdisk_offset")) {
			ramdisk_offset = strtoul(val, 0, 16);
		} else if(!strcmp(arg, "--second_offset")) {
			second_offset = strtoul(val, 0, 16);
		} else if(!strcmp(arg, "--tags_offset")) {
			tags_offset = strtoul(val, 0, 16);
		} else if(!strcmp(arg, "--board")) {
			board = val;
		} else if(!strcmp(arg,"--pagesize")) {
			pagesize = strtoul(val, 0, 10);
			if ((pagesize != 2048) && (pagesize != 4096)
					&& (pagesize != 8192) && (pagesize != 16384)) {
				fprintf(stderr,"error: unsupported page size %d\n", pagesize);
				return -1;
			}
		} else {
			return usage();
		}
	}
	hdr.page_size = pagesize;

	hdr.kernel_addr =  base + kernel_offset;
	hdr.ramdisk_addr = base + ramdisk_offset;
	hdr.second_addr =  base + second_offset;
	hdr.tags_addr =    base + tags_offset;

	if(bootimg == 0) {
		fprintf(stderr,"error: no output filename specified\n");
		return usage();
	}

	if(kernel_fn == 0) {
		fprintf(stderr,"error: no kernel image specified\n");
		return usage();
	}

	if(ramdisk_fn == 0) {
		fprintf(stderr,"error: no ramdisk image specified\n");
		return usage();
	}

	if(strlen(board) >= BOOT_NAME_SIZE) {
		fprintf(stderr,"error: board name too large\n");
		return usage();
	}

	strcpy(hdr.name, board);

	memcpy(hdr.magic, BOOT_MAGIC, BOOT_MAGIC_SIZE);

	if(strlen(cmdline) > (BOOT_ARGS_SIZE - 1)) {
		fprintf(stderr,"error: kernel commandline too large\n");
		return 1;
	}
	strcpy((char*)hdr.cmdline, cmdline);

	kernel_data = load_file(kernel_fn, &hdr.kernel_size);
	if(kernel_data == 0) {
		fprintf(stderr,"error: could not load kernel '%s'\n", kernel_fn);
		return 1;
	}

	if(!strcmp(ramdisk_fn,"NONE")) {
		ramdisk_data = 0;
		hdr.ramdisk_size = 0;
	} else {
		ramdisk_data = load_file(ramdisk_fn, &hdr.ramdisk_size);
		if(ramdisk_data == 0) {
			fprintf(stderr,"error: could not load ramdisk '%s'\n", ramdisk_fn);
			return 1;
		}
	}

	if(second_fn) {
		second_data = load_file(second_fn, &hdr.second_size);
		if(second_data == 0) {
			fprintf(stderr,"error: could not load secondstage '%s'\n", second_fn);
			return 1;
		}
	}

	if (dt_dir) {
		dt_data = load_dtqc_block(dt_dir, pagesize, &hdr.dt_size, dt_version);
		if (dt_data == 0) {
			fprintf(stderr, "error: could not load device tree blobs '%s'\n", dt_dir);
			return 1;
		}
	}

	/* put a hash of the contents in the header so boot images can be
	 * differentiated based on their first 2k.
	 */
	SHA_init(&ctx);
	SHA_update(&ctx, kernel_data, hdr.kernel_size);
	SHA_update(&ctx, &hdr.kernel_size, sizeof(hdr.kernel_size));
	SHA_update(&ctx, ramdisk_data, hdr.ramdisk_size);
	SHA_update(&ctx, &hdr.ramdisk_size, sizeof(hdr.ramdisk_size));
	SHA_update(&ctx, second_data, hdr.second_size);
	SHA_update(&ctx, &hdr.second_size, sizeof(hdr.second_size));
	if (dt_data) {
		SHA_update(&ctx, dt_data, hdr.dt_size);
		SHA_update(&ctx, &hdr.dt_size, sizeof(hdr.dt_size));
	}
	_SHA_final((uint8_t *)hdr.id, &ctx);

	fd = open(bootimg, O_CREAT | O_TRUNC | O_WRONLY, 0644);
	if(fd < 0) {
		fprintf(stderr,"error: could not create '%s'\n", bootimg);
		return 1;
	}

	if(write(fd, &hdr, sizeof(hdr)) != sizeof(hdr)) goto fail;
	if(write_padding(fd, pagesize, sizeof(hdr))) goto fail;

	if(write(fd, kernel_data, hdr.kernel_size) != hdr.kernel_size) goto fail;
	if(write_padding(fd, pagesize, hdr.kernel_size)) goto fail;

	if(write(fd, ramdisk_data, hdr.ramdisk_size) != hdr.ramdisk_size) goto fail;
	if(write_padding(fd, pagesize, hdr.ramdisk_size)) goto fail;

	if(second_data) {
		if(write(fd, second_data, hdr.second_size) != hdr.second_size) goto fail;
		if(write_padding(fd, pagesize, hdr.ramdisk_size)) goto fail;
	}

	if (dt_data) {
		if (write(fd, dt_data, hdr.dt_size) != hdr.dt_size) goto fail;
		if (write_padding(fd, pagesize, hdr.dt_size)) goto fail;
	}

	return 0;

fail:
	unlink(bootimg);
	close(fd);
	fprintf(stderr,"error: failed writing '%s': %s\n", bootimg,
			strerror(errno));
	return 1;
}
