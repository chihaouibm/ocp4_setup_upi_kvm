#!/bin/bash

# Define the service files content
cat <<EOF > /etc/systemd/system/socat_proxy_443.service
[Unit]
Description=Socat Proxy for Port 443
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:443,fork TCP:192.168.122.9:443
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/socat_proxy_6443.service
[Unit]
Description=Socat Proxy for Port 6443
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:6443,fork TCP:192.168.122.9:6443
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new services
systemctl daemon-reload

# Start and enable the services
systemctl start socat_proxy_443.service
systemctl enable socat_proxy_443.service

systemctl start socat_proxy_6443.service
systemctl enable socat_proxy_6443.service

echo "Services socat_proxy_443 and socat_proxy_6443 have been created, started, and enabled."
