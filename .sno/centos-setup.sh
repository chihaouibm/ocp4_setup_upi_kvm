#!/bin/bash

# Function to display the menu
display_menu() {
    echo "Select the CentOS version you want to install:"
    echo "1) CentOS Stream 9 (Boot ISO)"
    echo "2) CentOS Stream 9 (DVD ISO)"
    echo "3) CentOS Stream 9 (Latest Boot ISO)"
    echo "4) CentOS Stream 9 (Latest DVD ISO)"
    echo "5) Exit"
}

# Function to get the ISO path based on user selection
get_iso_path() {
    case $1 in
        1)
            echo "/var/lib/libvirt/images/CentOS-Stream-9-20241014.0-x86_64-boot.iso"
            ;;
        2)
            echo "/var/lib/libvirt/images/CentOS-Stream-9-20241014.0-x86_64-dvd1.iso"
            ;;
        3)
            echo "/var/lib/libvirt/images/CentOS-Stream-9-latest-x86_64-boot.iso"
            ;;
        4)
            echo "/var/lib/libvirt/images/CentOS-Stream-9-latest-x86_64-dvd1.iso"
            ;;
        *)
            echo "Invalid selection"
            exit 1
            ;;
    esac
}

# Variables for the VM setup
VM_NAME="centos9-stream"
RAM_SIZE=5120  # 5GB in MB
CPU_COUNT=8
DISK_SIZE="20G"  # 20GB disk space
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
NETWORK_BRIDGE="default"

# Display the menu and read user choice
display_menu
read -p "Enter your choice [1-5]: " choice

# Get the ISO path based on the user choice
ISO_PATH=$(get_iso_path "$choice")

# Check if the ISO file exists; if not, download it
if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading ISO file from the mirror..."
    
    case $choice in
        1)
            sudo wget https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-20241014.0-x86_64-boot.iso -P /var/lib/libvirt/images/
            ;;
        2)
            sudo wget https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-20241014.0-x86_64-dvd1.iso -P /var/lib/libvirt/images/
            ;;
        3)
            sudo wget https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-boot.iso -P /var/lib/libvirt/images/
            ;;
        4)
            sudo wget https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso -P /var/lib/libvirt/images/
            ;;
        *)
            echo "Invalid selection"
            exit 1
            ;;
    esac
    
    # Check if the download was successful
    if [ ! -f "$ISO_PATH" ]; then
        echo "Error: Failed to download the ISO file."
        exit 1
    fi
fi

# Create the virtual disk if it doesn't exist
if [ ! -f "$DISK_PATH" ]; then
    echo "Creating disk for the VM..."
    sudo qemu-img create -f qcow2 "$DISK_PATH" $DISK_SIZE
else
    echo "Disk image already exists at $DISK_PATH"
fi

# Install the VM using virt-install
echo "Installing CentOS 9 Stream VM using ISO: $ISO_PATH..."
sudo virt-install \
    --name "$VM_NAME" \
    --memory "$RAM_SIZE" \
    --vcpus "$CPU_COUNT" \
    --disk path="$DISK_PATH",format=qcow2 \
    --location "$ISO_PATH" \
    --network network="$NETWORK_BRIDGE" \
    --os-variant centos-stream9 \
    --graphics none \
    --console pty,target_type=serial \
    --extra-args 'console=ttyS0,115200n8 serial'

echo "CentOS 9 Stream VM installation has been initiated."
