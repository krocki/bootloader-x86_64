#!/bin/bash
set -e  # Exit on first error.
set -o pipefail

# Default GNU_EFI_DIR if not provided.
GNU_EFI_DIR=~/git/gnu-efi

usage_build() {
    echo "Usage: $0 -i <source.c> -o <output.efi> [--efi-dir <path>]"
    exit 1
}

# Parse arguments using getopt (supports short and long options)
TEMP=$(getopt -o i:o: -l efi-dir: -n 'build.sh' -- "$@")
if [ $? != 0 ]; then usage_build; fi
eval set -- "$TEMP"

while true; do
    case "$1" in
        -i) INPUT="$2"; shift 2 ;;
        -o) OUTPUT="$2"; shift 2 ;;
        --efi-dir) GNU_EFI_DIR="$2"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
    esac
done

# Check for required arguments.
if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
    usage_build
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' not found."
    exit 1
fi

echo "Using GNU_EFI_DIR: $GNU_EFI_DIR"
echo "Compiling $INPUT ..."

# Compile: produce main.o
gcc -I"${GNU_EFI_DIR}/inc" \
    -fpic -ffreestanding -fno-stack-protector -fno-stack-check \
    -fshort-wchar -mno-red-zone -maccumulate-outgoing-args \
    -c "$INPUT" -o main.o

echo "Linking to create a shared object..."
ld -shared -Bsymbolic \
   -L"${GNU_EFI_DIR}/x86_64/lib" -L"${GNU_EFI_DIR}/x86_64/gnuefi" \
   -T"${GNU_EFI_DIR}/gnuefi/elf_x86_64_efi.lds" \
   "${GNU_EFI_DIR}/x86_64/gnuefi/crt0-efi-x86_64.o" main.o \
   -o main.so -lgnuefi -lefi

echo "Converting shared object to EFI executable..."
objcopy -j .text -j .sdata -j .data -j .rodata \
        -j .dynamic -j .dynsym -j .rel -j .rela \
        -j .rel.* -j .rela.* -j .reloc \
        --target efi-app-x86_64 --subsystem=10 main.so "$OUTPUT"

echo "Build complete: EFI executable created at $OUTPUT"
