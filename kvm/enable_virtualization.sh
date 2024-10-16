#!/bin/bash

# Exit the script if any command fails
set -e

# Run system update before any other operations
echo "Updating the system packages..."
dnf -y update

# Create the user 'cpit' if it doesn't exist, and set the password
if id "cpit" &>/dev/null; then
    echo "User 'cpit' already exists."
else
    echo "Creating user 'cpit'..."
    useradd -m cpit
    echo "Setting password for user 'cpit'..."
    echo "cpit:KameloTouati23;" | chpasswd
    echo "Adding 'cpit' to the wheel group for sudo access..."
    usermod -aG wheel cpit
fi

# Switch to user 'cpit' to perform the next operations
echo "Switching to user 'cpit' to execute the rest of the script..."

sudo -u cpit bash << EOF

# Generate SSH keys for secure access (skip if already exists)
if [ ! -f /home/cpit/.ssh/id_rsa ]; then
    echo "Generating SSH keys..."
    ssh-keygen -t rsa -b 2048 -N "" -f /home/cpit/.ssh/id_rsa
else
    echo "SSH keys already exist."
fi

# Display the public key for SSH access
echo "Public key for SSH access:"
cat /home/cpit/.ssh/id_rsa.pub

EOF

# Back to the root or original user for package installations and service configurations
echo "Checking if the server supports virtualization..."
lscpu | grep Virtualization || { echo "Virtualization not supported"; exit 1; }

# Install essential virtualization packages
echo "Installing virtualization packages..."
dnf -y install qemu-kvm libvirt virt-install virt-viewer cockpit socat tar

yum -y install /usr/bin/virt-customize

yum -y install bind-utils

# Enable and start the libvirtd service for virtualization
echo "Enabling and starting libvirtd service..."
systemctl enable --now libvirtd

# Start the necessary libvirt daemon services
echo "Starting libvirt socket services..."
for drv in qemu network nodedev nwfilter secret storage interface; do 
    systemctl start virt${drv}d{,-ro,-admin}.socket
done

# Enable and start the Cockpit service
echo "Enabling and starting Cockpit service..."
systemctl enable --now cockpit.socket

# Show the Cockpit web interface access URL
echo "You can access Cockpit via web browser at: https://localhost:9090"

echo -e "[main]\ndns=dnsmasq" | sudo tee /etc/NetworkManager/conf.d/openshift.conf

echo listen-address=127.0.0.1 > /etc/NetworkManager/dnsmasq.d/openshift.conf
echo bind-interfaces >> /etc/NetworkManager/dnsmasq.d/openshift.conf
echo server=185.12.64.1 >> /etc/NetworkManager/dnsmasq.d/openshift.conf
echo server=185.12.64.2 >> /etc/NetworkManager/dnsmasq.d/openshift.conf
echo server=8.8.8.8 >> /etc/NetworkManager/dnsmasq.d/openshift.conf
#echo address=/chihaoui.site/192.168.122.10 >> /etc/NetworkManager/dnsmasq.d/openshift.conf

systemctl reload NetworkManager