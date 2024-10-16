#!/bin/bash

# Set the directory variable
INSTALL_DIR="/home/cpit/sno"

# Run the OpenShift Bare Metal installation wait command
openshift-baremetal-install wait-for install-complete --dir "${INSTALL_DIR}"

# Check the exit status of the command
if [[ $? -eq 0 ]]; then
    echo "Installation completed successfully."
else
    echo "Installation failed or is still in progress."
    exit 1
fi
