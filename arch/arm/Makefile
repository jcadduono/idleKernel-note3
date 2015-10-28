#
# arch/arm/Makefile
#
# This file is included by the global makefile so that you can add your own
# architecture-specific flags and dependencies.
#
# This file is subject to the terms and conditions of the GNU General Public
# License.  See the file "COPYING" in the main directory of this archive
# for more details.
#
# Copyright (C) 1995-2001 by Russell King

LDFLAGS_vmlinux	:=-p --no-undefined -X
ifeq ($(CONFIG_CPU_ENDIAN_BE8),y)
LDFLAGS_vmlinux	+= --be8
endif

OBJCOPYFLAGS	:=-O binary -R .comment -S
GZFLAGS		:=-9
#KBUILD_CFLAGS	+=-pipe
# Explicitly specifiy 32-bit ARM ISA since toolchain default can be -mthumb:
KBUILD_CFLAGS	+=$(call cc-option,-marm,)

# Never generate .eh_frame
KBUILD_CFLAGS	+= $(call cc-option,-fno-dwarf2-cfi-asm)

# Do not use arch/arm/defconfig - it's always outdated.
# Select a platform tht is kept up-to-date
KBUILD_DEFCONFIG := versatile_defconfig

# defines filename extension depending memory management type.
ifeq ($(CONFIG_MMU),)
MMUEXT		:= -nommu
endif

ifeq ($(CONFIG_FRAME_POINTER),y)
KBUILD_CFLAGS	+=-fno-omit-frame-pointer -mapcs -mno-sched-prolog
endif

ifeq ($(CONFIG_CC_STACKPROTECTOR),y)
KBUILD_CFLAGS	+=-fstack-protector
endif

ifeq ($(CONFIG_CPU_BIG_ENDIAN),y)
KBUILD_CPPFLAGS	+= -mbig-endian
AS		+= -EB
LD		+= -EB
else
KBUILD_CPPFLAGS	+= -mlittle-endian
AS		+= -EL
LD		+= -EL
endif

comma = ,

arch-$(CONFIG_ARCH_MSM_KRAIT) :=-D__LINUX_ARM_ARCH__=7 $(call cc-option,-mcpu=cortex-a15,-march=armv7-a)

ifeq ($(CONFIG_AEABI),y)
CFLAGS_ABI	:=-mabi=aapcs-linux -mno-thumb-interwork
else
CFLAGS_ABI	:=$(call cc-option,-mapcs-32,-mabi=apcs-gnu) $(call cc-option,-mno-thumb-interwork,)
endif

ifeq ($(CONFIG_ARM_UNWIND),y)
CFLAGS_ABI	+=-funwind-tables
endif

ifeq ($(CONFIG_THUMB2_KERNEL),y)
AFLAGS_AUTOIT	:=$(call as-option,-Wa$(comma)-mimplicit-it=always,-Wa$(comma)-mauto-it)
AFLAGS_NOWARN	:=$(call as-option,-Wa$(comma)-mno-warn-deprecated,-Wa$(comma)-W)
CFLAGS_THUMB2	:=-mthumb $(AFLAGS_AUTOIT) $(AFLAGS_NOWARN)
AFLAGS_THUMB2	:=$(CFLAGS_THUMB2) -Wa$(comma)-mthumb
# Work around buggy relocation from gas if requested:
ifeq ($(CONFIG_THUMB2_AVOID_R_ARM_THM_JUMP11),y)
CFLAGS_MODULE	+=-fno-optimize-sibling-calls
endif
endif

# Need -Uarm for gcc < 3.x
KBUILD_CFLAGS	+=$(CFLAGS_ABI) $(CFLAGS_THUMB2) $(arch-y) $(tune-y) $(call cc-option,-mshort-load-bytes,$(call cc-option,-malignment-traps,)) -msoft-float -Uarm
KBUILD_AFLAGS	+=$(CFLAGS_ABI) $(AFLAGS_THUMB2) $(arch-y) $(tune-y) -include asm/unified.h -msoft-float

CHECKFLAGS	+= -D__arm__

#Default value
head-y		:= arch/arm/kernel/head$(MMUEXT).o arch/arm/kernel/init_task.o
textofs-y	:= 0x00008000

# Machine directory name.  This list is sorted alphanumerically
# by CONFIG_* macro name.
machine-$(CONFIG_ARCH_MSM) := msm

# The byte offset of the kernel image in RAM from the start of RAM.
TEXT_OFFSET := $(textofs-y)

# The first directory contains additional information for the boot setup code
ifneq ($(machine-y),)
MACHINE  := arch/arm/mach-$(word 1,$(machine-y))/
else
MACHINE  :=
endif

machdirs := $(patsubst %,arch/arm/mach-%/,$(machine-y))

ifeq ($(KBUILD_SRC),)
KBUILD_CPPFLAGS += $(patsubst %,-I%include,$(machdirs))
else
KBUILD_CPPFLAGS += $(patsubst %,-I$(srctree)/%include,$(machdirs))
endif

export	TEXT_OFFSET GZFLAGS MMUEXT

# Do we have FASTFPE?
FASTFPE		:=arch/arm/fastfpe
ifeq ($(FASTFPE),$(wildcard $(FASTFPE)))
FASTFPE_OBJ	:=$(FASTFPE)/
endif

core-$(CONFIG_VFP)		+= arch/arm/vfp/
core-$(CONFIG_VMWARE_MVP)      += arch/arm/mvp/

# If we have a machine-specific directory, then include it in the build.
core-y				+= arch/arm/kernel/ arch/arm/mm/ arch/arm/common/
core-y				+= arch/arm/net/
core-y				+= arch/arm/crypto/
core-y				+= $(machdirs)

drivers-$(CONFIG_OPROFILE)      += arch/arm/oprofile/
core-y				+= arch/arm/perfmon/

libs-y				:= arch/arm/lib/ $(libs-y)

# Default target when executing plain make
ifeq ($(CONFIG_XIP_KERNEL),y)
KBUILD_IMAGE := xipImage
else ifeq ($(CONFIG_BUILD_ARM_APPENDED_DTB_IMAGE),y)
KBUILD_IMAGE := zImage-dtb
else
KBUILD_IMAGE := zImage
endif

# Build the DT binary blobs if we have OF configured
ifeq ($(CONFIG_USE_OF),y)
KBUILD_DTBS := dtbs
endif

all:	$(KBUILD_IMAGE) $(KBUILD_DTBS)

boot := arch/arm/boot

archprepare:
	$(Q)$(MAKE) $(build)=arch/arm/tools include/generated/mach-types.h

# Convert bzImage to zImage
bzImage: zImage

zImage Image xipImage bootpImage uImage: vmlinux
	$(Q)$(MAKE) $(build)=$(boot) MACHINE=$(MACHINE) $(boot)/$@

zinstall uinstall install: vmlinux
	$(Q)$(MAKE) $(build)=$(boot) MACHINE=$(MACHINE) $@

%.dtb: scripts
	$(Q)$(MAKE) $(build)=$(boot) MACHINE=$(MACHINE) $(boot)/$@

dtbs: scripts
	$(Q)$(MAKE) $(build)=$(boot) MACHINE=$(MACHINE) $(boot)/$@

zImage-dtb: vmlinux scripts
	$(Q)$(MAKE) $(build)=$(boot) MACHINE=$(MACHINE) $(boot)/$@

# We use MRPROPER_FILES and CLEAN_FILES now
archclean:
	$(Q)$(MAKE) $(clean)=$(boot)

# My testing targets (bypasses dependencies)
bp:;	$(Q)$(MAKE) $(build)=$(boot) MACHINE=$(MACHINE) $(boot)/bootpImage
i zi:;	$(Q)$(MAKE) $(build)=$(boot) MACHINE=$(MACHINE) $@


define archhelp
  echo  '* zImage        - Compressed kernel image (arch/$(ARCH)/boot/zImage)'
  echo  '  Image         - Uncompressed kernel image (arch/$(ARCH)/boot/Image)'
  echo  '* xipImage      - XIP kernel image, if configured (arch/$(ARCH)/boot/xipImage)'
  echo  '  uImage        - U-Boot wrapped zImage'
  echo  '  bootpImage    - Combined zImage and initial RAM disk'
  echo  '                  (supply initrd image via make variable INITRD=<path>)'
  echo  '* dtbs          - Build device tree blobs for enabled boards'
  echo  '  install       - Install uncompressed kernel'
  echo  '  zinstall      - Install compressed kernel'
  echo  '  uinstall      - Install U-Boot wrapped compressed kernel'
  echo  '                  Install using (your) ~/bin/$(INSTALLKERNEL) or'
  echo  '                  (distribution) /sbin/$(INSTALLKERNEL) or'
  echo  '                  install to $$(INSTALL_PATH) and run lilo'
endef
