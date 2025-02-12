#!/bin/bash
set -e
set -o pipefail

usage_install() {
    echo "Usage: $0 -i <input.efi> -o <output device> [--prepare-disk]"
    echo "  -i : Path to EFI executable (e.g. main.efi)"
    echo "  -o : Output device. Either a whole disk (e.g. /dev/sda) if using --prepare-disk, or an existing partition (e.g. /dev/sda1)"
    echo "  --prepare-disk : (Optional) Automatically wipe the disk, create a GPT partition table and an EFI partition."
    exit 1
}

PREPARE_DISK=0
INPUT=""
OUTPUT=""

# Parse arguments.
TEMP=$(getopt -o i:o: -l prepare-disk -n 'install.sh' -- "$@")
if [ $? != 0 ]; then usage_install; fi
eval set -- "$TEMP"

while true; do
    case "$1" in
        -i) INPUT="$2"; shift 2 ;;
        -o) OUTPUT="$2"; shift 2 ;;
        --prepare-disk) PREPARE_DISK=1; shift ;;
        --) shift; break ;;
        *) break ;;
    esac
done

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
    usage_install
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: EFI file '$INPUT' not found."
    exit 1
fi

# If prepare-disk is set, assume OUTPUT is a whole disk (like /dev/sda)
if [ "$PREPARE_DISK" -eq 1 ]; then
    if [ ! -b "$OUTPUT" ]; then
        echo "Error: Output device '$OUTPUT' is not a valid block device."
        exit 1
    fi
    echo "Preparing disk $OUTPUT: wiping, partitioning and formatting EFI partition..."
    # Zap existing partition data
    sudo sgdisk --zap-all "$OUTPUT"
    # Create new GPT table
    sudo sgdisk -o "$OUTPUT"
    # Create a new partition (#1) starting at sector 2048 with a size of +600M, and type EF00 (EFI System Partition)
    sudo sgdisk -n 1:2048:+600M -t 1:EF00 "$OUTPUT"
    # Assume new partition is named OUTPUT with a trailing "1" (e.g., /dev/sda -> /dev/sda1)
    PARTITION="${OUTPUT}1"
    # Wait for system to register new partition
    sleep 2
    echo "Formatting partition $PARTITION as FAT32..."
    sudo mkfs.fat -F32 "$PARTITION"
else
    # Without prepare-disk, we assume OUTPUT is an existing partition.
    if [ ! -b "$OUTPUT" ]; then
        echo "Error: Output device '$OUTPUT' is not a valid block device."
        exit 1
    fi
    # Verify the partition is FAT32 by checking filesystem type.
    FS_TYPE=$(blkid -o value -s TYPE "$OUTPUT" 2>/dev/null || echo "")
    if [ "$FS_TYPE" != "vfat" ]; then
        echo "Error: The output partition '$OUTPUT' is not FAT32 (detected type: $FS_TYPE)."
        exit 1
    fi
    PARTITION="$OUTPUT"
fi

# Mount the partition to a temporary mount point.
MOUNT_POINT="/mnt/efi_temp"
sudo mkdir -p "$MOUNT_POINT"
echo "Mounting partition $PARTITION at $MOUNT_POINT..."
sudo mount "$PARTITION" "$MOUNT_POINT"

# Create EFI boot directory structure.
sudo mkdir -p "$MOUNT_POINT/EFI/BOOT"

# Copy the EFI executable to the standard path.
echo "Copying $INPUT to $MOUNT_POINT/EFI/BOOT/BOOTX64.EFI..."
sudo cp "$INPUT" "$MOUNT_POINT/EFI/BOOT/BOOTX64.EFI"

# Unmount the partition.
echo "Unmounting $MOUNT_POINT..."
sudo umount "$MOUNT_POINT"
sudo rmdir "$MOUNT_POINT"
echo "Installation complete. EFI executable installed to $PARTITION in /EFI/BOOT/BOOTX64.EFI"
