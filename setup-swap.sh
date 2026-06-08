#!/bin/bash
# setup-swap.sh
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

SWAP_SIZE="2G"
SWAP_FILE="/swapfile"

if grep -q "swap" /etc/fstab; then
    echo "Swap already exists."
    exit 0
fi

echo "Creating ${SWAP_SIZE} swap file..."
fallocate -l ${SWAP_SIZE} ${SWAP_FILE}
chmod 600 ${SWAP_FILE}
mkswap ${SWAP_FILE}
swapon ${SWAP_FILE}

echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab

echo "Swap setup complete!"
free -h
