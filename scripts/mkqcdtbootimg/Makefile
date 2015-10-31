LIBFDT_DIR=../dtc/libfdt

include $(LIBFDT_DIR)/Makefile.libfdt

OBJ_FILES := mkqcdtbootimg.o mincrypt/sha.o $(addprefix $(LIBFDT_DIR)/,$(LIBFDT_OBJS))
CFLAGS := -static -I$(LIBFDT_DIR) -O2 -fomit-frame-pointer -Wall

all: mkqcdtbootimg

mkqcdtbootimg: $(OBJ_FILES)
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f $(OBJ_FILES)

