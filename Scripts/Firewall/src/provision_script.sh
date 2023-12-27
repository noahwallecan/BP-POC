#!/bin/bash

# Provisioning Script for CentOS 8 Firewall as Router with NAT

sudo ip addr add 192.168.0.5/24 dev enp0s8
sudo ip link set enp0s8 up

# Define external and internal interfaces
EXTERNAL_INTERFACE="enp0s3"
INTERNAL_INTERFACE="System enp0s8"  # Update with the correct internal interface name
INTERNAL_NETWORK="192.168.0.0/24"
FIREWALL_IP="192.168.0.5/24"

sudo yum install firewalld -y
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Function to enable IP forwarding
enable_ip_forwarding() {
    echo "Enabling IP forwarding..."
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo sysctl -p
}

# Function to configure firewalld for NAT
configure_nat() {
    echo "Configuring firewalld for NAT..."
    sudo firewall-cmd --add-masquerade --zone=external --permanent
    sudo firewall-cmd --reload
}

# Function to configure internal interface
configure_internal_interface() {
    echo "Configuring internal interface $INTERNAL_INTERFACE..."
    sudo nmcli connection modify "$INTERNAL_INTERFACE" ipv4.addresses $FIREWALL_IP ipv4.method manual
    sudo nmcli connection up "$INTERNAL_INTERFACE"
}

# Function to allow HTTP (port 80) and HTTPS (port 443) traffic
allow_http_https() {
    echo "Allowing HTTP and HTTPS traffic..."
    sudo firewall-cmd --zone=external --add-service=http --permanent
    sudo firewall-cmd --zone=external --add-service=https --permanent
    sudo firewall-cmd --reload
}

# Function to update default gateway on internal VMs
update_default_gateway() {
    echo "Updating default gateway on internal VMs..."
    # Replace enp0sX with the actual internal interface on your VMs
    sudo nmcli connection modify "$INTERNAL_INTERFACE" ipv4.gateway $FIREWALL_IP
    sudo nmcli connection up "$INTERNAL_INTERFACE"
}

pass_NAT() {
    sudo iptables -A FORWARD -j ACCEPT
    sudo iptables -t nat -s 192.168.0.0/24 -A POSTROUTING -j MASQUERADE
    sudo iptables -t nat -A POSTROUTING -j MASQUERADE
    sudo iptables-save | sudo tee /etc/iptables/rules.v4
}

# Main script execution
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

enable_ip_forwarding
configure_nat
configure_internal_interface
allow_http_https
update_default_gateway
pass_NAT

echo "Internet access configuration for internal VMs is complete."
