# TorrentOS kernel build
CC      := gcc
LD      := ld

CFLAGS  := -m32 -std=c99 -ffreestanding -O2 -Wall -Wextra \
           -fno-stack-protector -fno-pic -nostdlib -nodefaultlibs \
           -Ikernel

LDFLAGS := -m elf_i386 -T kernel/linker.ld --oformat elf32-i386

SRCS_C  := kernel/kernel.c \
           kernel/vga.c \
           kernel/string.c \
           kernel/keyboard.c \
           kernel/shell.c

SRCS_S  := kernel/boot.S

OBJS    := $(SRCS_S:.S=.o) $(SRCS_C:.c=.o)
KERNEL  := out/torrentos.kernel

.PHONY: all clean

all: $(KERNEL)

$(KERNEL): $(OBJS) | out
	$(LD) $(LDFLAGS) -o $@ $^

kernel/boot.o: kernel/boot.S
	$(CC) -m32 -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

out:
	mkdir -p out

clean:
	rm -f $(OBJS) $(KERNEL)
