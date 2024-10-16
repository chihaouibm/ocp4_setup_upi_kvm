#!/bin/bash

# Function to display menu and get user selection for a specified title and versions
choose_version() {
    local title="$1"
    shift
    local versions=("$@")
    local default_version="${versions[3]}"  # Set default to the fourth version

    echo "Select $title version:"
    for i in "${!versions[@]}"; do
        echo "$((i + 1))) ${versions[i]}"
    done
    echo "0) Exit"

    read -p "Enter your choice [0-$((${#versions[@]}))]: " choice

    if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "${#versions[@]}" ]; then
        if [ "$choice" -eq 0 ]; then
            echo "Exiting."
            exit 0
        else
            export SELECTED_VERSION="${versions[$((choice - 1))]}"
        fi
    else
        echo "Invalid choice. Defaulting to $default_version."
        export SELECTED_VERSION="$default_version"
    fi
}

# Define RHCOS versions and corresponding COREOS versions
RHCOS_VERSIONS=("4.12" "4.13" "4.14" "4.15" "4.16" "4.17")
COREOS_VERSIONS=("v0.12.0-1" "v0.13.1-1" "v0.14.0-1" "v0.15.0-2" "v0.16.1-1" "v0.17.0-3")

# Call the function to choose RHCOS version
choose_version "RHCOS" "${RHCOS_VERSIONS[@]}"
RHCOS="$SELECTED_VERSION"

# Automatically set COREOS version based on selected RHCOS version
INDEX=$(printf "%s\n" "${RHCOS_VERSIONS[@]}" | grep -n "^$RHCOS$" | cut -d: -f1)
COREOS="$SELECTED_VERSION"

# Set corresponding COREOS version based on selected RHCOS version
if [[ -n "$INDEX" ]]; then
    COREOS="${COREOS_VERSIONS[$((INDEX - 1))]}"
else
    echo "No corresponding COREOS version found. Defaulting to v0.15.0-2."
    COREOS="v0.15.0-2"
fi

# Display the selected versions
echo "Selected COREOS version: $COREOS"
echo "Selected RHCOS version: $RHCOS"

# Output the values
echo "COREOS is set to: $COREOS"
echo "RHCOS is set to: $RHCOS"


# Prerequisites: Clean Up Previous Installations
echo "Cleaning up previous installations..."

> /home/cpit/.ssh/known_hosts

# Remove any VMs if sno exists
if sudo virsh dominfo sno > /dev/null 2>&1; then
    echo "Removing existing sno VM..."
    sudo virsh destroy sno
    sudo virsh undefine sno --remove-all-storage
    echo "sno VM removed."
else
    echo "No sno VM found. Skipping removal."
fi


# Remove existing ISOs and other generated files
sudo rm -rf /var/lib/libvirt/images/rhcos-live.x86_64.iso
rm -rf /var/lib/libvirt/images/*.*
rm -rf ./sno
rm -rf ./oc
rm -rf ./openshift-baremetal-install
rm -rf ./rhcos-live.x86_64.iso
rm -rf ./coreos-installer
rm -f coreos-installer.{1,2,3,4} rhcos-live.x86_64.iso.{1,2,3,4} disk_nvme0n1p1.xml disk_nvme1n1p1.xml

# Clean the current directory
rm -f disk_nvme0n1p1.xml disk_nvme1n1p1.xml

echo "Cleanup complete."

# Set Environment Variables
export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-$RHCOS/release.txt | grep 'Pull From: quay.io' | awk '{print $3}')
export CMD=openshift-baremetal-install
export PULLSECRET_FILE=~/pullsecret.txt

echo "Download OpenShift Client Tools"
# Download OpenShift Client Tools
curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-$RHCOS/openshift-client-linux.tar.gz | tar xzvf - oc
sudo cp oc /usr/local/bin

echo "Extract OpenShift Installer"
# Extract OpenShift Installer
oc adm release extract --registry-config "${PULLSECRET_FILE}" --command="${CMD}" --to . "${RELEASE_IMAGE}"
sudo cp ./openshift-baremetal-install /usr/local/bin

echo "Download CoreOS Installer"
# Download CoreOS Installer
wget -q https://mirror.openshift.com/pub/openshift-v4/clients/coreos-installer/$COREOS/coreos-installer
sudo cp ./coreos-installer /usr/local/bin && sudo chmod +x /usr/local/bin/coreos-installer

echo "Download RHCOS ISO"
# Download RHCOS ISO
wget -q https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$RHCOS/latest/rhcos-live.x86_64.iso

echo "Make Config Dir SNO"
# Create Directory for Installation
mkdir -p sno

echo "Creating install-config.yaml"
cat << EOF | tee ./sno/install-config.yaml
apiVersion: v1beta4
baseDomain: chihaoui.site
metadata:
  name: sno
networking:
  networkType: OVNKubernetes
  machineCIDR: 192.168.122.0/24
compute:
  - name: worker
    replicas: 0
controlPlane:
  name: master
  replicas: 1
platform:
  none: {}  # No specific platform configuration
BootstrapInPlace:
  InstallationDisk: /dev/sda
pullSecret: |
  {
    "auths": {
      "cloud.openshift.com": {
        "auth": "..........",
        "email": "................"
      },
      "cp.icr.io": {
        "auth": "............"
      },
      "registry.redhat.io": {
        "auth": "..............."
      },
      "quay.io": {
        "auth": "........",
        "email": ".........."
      },
      "registry.connect.redhat.com": {
        "auth": "...........",
        "email": "....................."
      }
    }
  }
sshKey: |
  ssh-rsa AAAAB3NzaC1yc
EOF


echo "Export SSH KEY"
# Set Additional Environment Variables
export SSH_KEY=$(cat $HOME/.ssh/id_rsa.pub)

# Create Ignition Config for Single Node
echo "Creating single-node Ignition config..."
openshift-baremetal-install --dir=sno create single-node-ignition-config

# Check if the Ignition config was created successfully
if [ ! -f "./sno/bootstrap-in-place-for-live-iso.ign" ]; then
    echo "ERROR: Ignition config file ./sno/bootstrap-in-place-for-live-iso.ign not found!"
    exit 1
fi

# Verify file permissions for the Ignition file
if [ ! -r "./sno/bootstrap-in-place-for-live-iso.ign" ]; then
    echo "ERROR: Ignition config file ./sno/bootstrap-in-place-for-live-iso.ign is not readable. Fixing permissions..."
    chmod 644 ./sno/bootstrap-in-place-for-live-iso.ign
fi

# Validate the Ignition file format
if ! jq . ./sno/bootstrap-in-place-for-live-iso.ign > /dev/null 2>&1; then
    echo "ERROR: Ignition config file ./sno/bootstrap-in-place-for-live-iso.ign is not a valid JSON file."
    exit 1
else
    echo "Ignition config validated successfully."
fi

# Embed Ignition Config into ISO
echo "Embedding Ignition config into ISO..."

coreos-installer iso ignition embed -fi ./sno/bootstrap-in-place-for-live-iso.ign ./rhcos-live.x86_64.iso

# Check for errors during the embedding process
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to embed Ignition config into the ISO."
    exit 1
else
    echo "Ignition config embedded into ISO successfully."
fi

# Copy ISO to Libvirt Images Directory
sudo cp -rf rhcos-live.x86_64.iso /var/lib/libvirt/images/rhcos-live.x86_64.iso

# Create disk_nvme0n1p1.xml
cat << EOF | sudo tee disk_nvme0n1p1.xml
<disk type='block' device='disk'>
  <driver name='qemu' type='raw'/>
  <source dev='/dev/nvme0n1p1'/>
  <target dev='vdb' bus='virtio'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
</disk>
EOF

# Create disk_nvme1n1p1.xml
cat << EOF | sudo tee disk_nvme1n1p1.xml
<disk type='block' device='disk'>
  <driver name='qemu' type='raw'/>
  <source dev='/dev/nvme1n1p1'/>
  <target dev='vdb' bus='virtio'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
</disk>
EOF

echo "XML files created."

# Install OpenShift VM Using virt-install
sudo virt-install --name sno -m  52:54:00:65:aa:da --memory 120832 --vcpus 100 --disk size=500 --cdrom /var/lib/libvirt/images/rhcos-live.x86_64.iso --os-variant generic --boot hd,cdrom --network network=default --graphics none --console pty,target_type=serial --extra-args 'console=ttyS0,115200n8 serial'

