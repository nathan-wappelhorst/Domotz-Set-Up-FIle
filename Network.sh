#!/bin/bash

set -e

# Must run as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run as root (sudo ./configure_network.sh)"
   exit 1
fi

echo "Detecting physical ethernet adapters..."

# Get physical ethernet interfaces (exclude loopback & virtual)
mapfile -t adapters < <(ls /sys/class/net | while read iface; do
    if [[ "$iface" != "lo" ]] && \
       [[ -d "/sys/class/net/$iface/device" ]] && \
       [[ "$(cat /sys/class/net/$iface/type)" -eq 1 ]]; then
        echo "$iface"
    fi
done)

if [[ ${#adapters[@]} -eq 0 ]]; then
    echo "Error: No physical ethernet adapters found."
    exit 1
fi

NETPLAN_FILE="/etc/netplan/99-custom-config.yaml"

echo "Writing Netplan configuration to $NETPLAN_FILE..."

if [[ ${#adapters[@]} -ge 2 ]]; then
    ETH1="${adapters[0]}"
    ETH2="${adapters[1]}"

    echo "First adapter (DHCP):  $ETH1"
    echo "Second adapter (Static): $ETH2"

    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $ETH1:
      dhcp4: true
    $ETH2:
      dhcp4: false
      addresses:
        - 192.168.137.20/24
EOF

else
    ETH1="${adapters[0]}"

    echo "Only one adapter detected."
    echo "Setting $ETH1 to Static: 192.168.137.20/24"

    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $ETH1:
      dhcp4: false
      addresses:
        - 192.168.137.20/24
EOF

fi

echo "Applying Netplan configuration..."
netplan apply

echo "Done."
