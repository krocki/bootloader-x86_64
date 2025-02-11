#!/bin/bash
set -x
#/usr/lib/x86_64-efi-gcc -nostdlib -Wl,-znocombreloc -Wl,-subsystem:efi_application \
#    -I/usr/include/efi -I/usr/include/efi/x86_64 \
#    -o hello.efi hello.c -lefi -lgnuefi

# building
GNU_EFI_DIR=~/git/gnu-efi
gcc -I${GNU_EFI_DIR}/inc -fpic -ffreestanding -fno-stack-protector -fno-stack-check -fshort-wchar -mno-red-zone -maccumulate-outgoing-args -c main.c -o main.o

# linking

ld -shared -Bsymbolic -L${GNU_EFI_DIR}/x86_64/lib -L${GNU_EFI_DIR}/x86_64/gnuefi -T${GNU_EFI_DIR}/gnuefi/elf_x86_64_efi.lds ${GNU_EFI_DIR}/x86_64/gnuefi/crt0-efi-x86_64.o main.o -o main.so -lgnuefi -lefi

# convert so to EFI exucutable

objcopy -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym  -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 main.so main.efi

# choose a device ... /dev/sdX
# create a partition EFI
# gdisk /dev/sdX
# n
# 1
# 2048
# +600M
# EF00
# w

# sudo mkfs.fat -F32 /dev/sdX1
# sudo mount --mkdir /dev/sdX1 /media/user/usb
# sudo mkdir -p /media/user/usb/EFI/BOOT
# sudo cp main.efi /media/user/usb/EFI/BOOT/BOOTX64.EFI
# sudo umount -R /media/user/usb

