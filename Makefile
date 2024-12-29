ARCH ?= x86_64
AS = nasm
CC = $(ARCH)-elf-gcc
LD = $(ARCH)-elf-ld
OBJCOPY = $(ARCH)-elf-objcopy
QEMU = qemu-system-$(ARCH)

NASMFLAGS = -f elf64
NASMFLAGS_BIN = -f bin
CFLAGS = -ffreestanding -nostdlib -mno-red-zone -Wall -Wextra -O3 -mcmodel=kernel
LDFLAGS = -T linker.ld -nostdlib

BUILD_DIR = bin
BOOT_DIR = boot
KERNEL_DIR = kernel

BOOT_SRC = $(BOOT_DIR)/$(ARCH)/first_stage.asm $(BOOT_DIR)/$(ARCH)/second_stage.asm
KERNEL_SRC = $(KERNEL_DIR)/entry/$(ARCH).asm $(KERNEL_DIR)/kernel.c

BOOT_OBJ = $(patsubst $(BOOT_DIR)/%.asm, $(BUILD_DIR)/%.o, $(filter %.asm, $(BOOT_SRC)))
KERNEL_OBJ = $(patsubst $(KERNEL_DIR)/%.asm, $(BUILD_DIR)/%.o, $(filter %.asm,$(KERNEL_SRC))) \
				$(patsubst $(KERNEL_DIR)/%.c, $(BUILD_DIR)/%.o, $(filter %.c,$(KERNEL_SRC)))

KERNEL_BIN = $(BUILD_DIR)/kernel-$(ARCH).bin
KERNEL_ELF = $(BUILD_DIR)/kernel-$(ARCH).elf
BOOTLOADER_IMG = $(BUILD_DIR)/bootloader-$(ARCH).img

all: $(BOOTLOADER_IMG)

$(BUILD_DIR)/first_stage.bin: $(BOOT_DIR)/$(ARCH)/first_stage.asm | $(BUILD_DIR)
	$(AS) $(NASMFLAGS_BIN) $< -o $@

$(BUILD_DIR)/second_stage.bin: $(BOOT_DIR)/$(ARCH)/second_stage.asm | $(BUILD_DIR)
	$(AS) $(NASMFLAGS_BIN) $< -o $@

$(BUILD_DIR)/entry-$(ARCH).o: $(KERNEL_DIR)/entry/$(ARCH).asm | $(BUILD_DIR)
	$(AS) $(NASMFLAGS) $< -o $@

$(BUILD_DIR)/kernel.o: $(KERNEL_DIR)/kernel.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(KERNEL_ELF): $(BUILD_DIR)/entry-$(ARCH).o $(BUILD_DIR)/kernel.o | $(BUILD_DIR)
	$(LD) $(LDFLAGS) -o $@ $^

$(KERNEL_BIN): $(KERNEL_ELF) | $(BUILD_DIR)
	$(OBJCOPY) -O binary $< $@

$(BOOTLOADER_IMG): $(BUILD_DIR)/first_stage.bin $(BUILD_DIR)/second_stage.bin $(KERNEL_BIN)
	dd if=/dev/zero of=$(BOOTLOADER_IMG) bs=512 count=2880

	dd if=$(BUILD_DIR)/first_stage.bin of=$(BOOTLOADER_IMG) bs=512 seek=0 conv=notrunc

	dd if=$(BUILD_DIR)/second_stage.bin of=$(BOOTLOADER_IMG) bs=512 seek=1 conv=notrunc

	dd if=$(KERNEL_BIN) of=$(BOOTLOADER_IMG) bs=512 seek=4 conv=notrunc

clean:
	rm -rf $(BUILD_DIR)/*.o $(BUILD_DIR)/*.bin $(BUILD_DIR)/*.img $(KERNEL_ELF)

run: $(BOOTLOADER_IMG)
	$(QEMU) -drive file=$(BOOTLOADER_IMG),format=raw -serial stdio # -S -gdb tcp::1234

rerun: clean run

.PHONY: all clean run
