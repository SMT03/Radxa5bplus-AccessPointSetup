#!/bin/bash

# Radxa Rock5B+ Access Point Setup Script
# Designed for RTL8852BE WiFi chipset with comprehensive error handling
# Author: AI Assistant
# Date: $(date)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SSID="RadxaAP"
PASSPHRASE="radxa123456"
AP_IP="192.168.4.1"
DHCP_RANGE_START="192.168.4.2"
DHCP_RANGE_END="192.168.4.20"
CHANNEL=7
COUNTRY_CODE="PK"  # Pakistan
INTERFACE=""  # Will be auto-detected

# Log file
LOG_FILE="/tmp/radxa_ap_setup.log"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to detect WiFi interface
detect_wifi_interface() {
    print_status "Detecting WiFi interface..."
    
    # Check for common Radxa Rock5B+ interface patterns
    local interfaces=($(ls /sys/class/net/ | grep -E '^(wl|wlan)'))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        print_error "No WiFi interface found!"
        print_error "Make sure WiFi module is properly installed"
        exit 1
    elif [ ${#interfaces[@]} -eq 1 ]; then
        INTERFACE=${interfaces[0]}
        print_success "Found WiFi interface: $INTERFACE"
    else
        print_warning "Multiple WiFi interfaces found: ${interfaces[@]}"
        print_status "Using first interface: ${interfaces[0]}"
        INTERFACE=${interfaces[0]}
    fi
    
    # Verify interface supports AP mode
    if ! iw "$INTERFACE" info &>/dev/null; then
        print_error "Interface $INTERFACE is not accessible"
        exit 1
    fi
    
    # Check if interface supports AP mode
    if ! iw phy phy0 info | grep -q "AP"; then
        print_warning "AP mode support not clearly indicated, proceeding anyway..."
    fi
}

# Function to check and install required packages
install_packages() {
    print_status "Checking and installing required packages..."
    
    local packages=("hostapd" "dnsmasq" "iptables-persistent" "iw" "wireless-tools")
    local to_install=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package"; then
            to_install+=("$package")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        print_status "Installing packages: ${to_install[@]}"
        apt-get update
        apt-get install -y "${to_install[@]}" || {
            print_error "Failed to install required packages"
            exit 1
        }
    else
        print_success "All required packages already installed"
    fi
}

# Function to backup existing configurations
backup_configs() {
    print_status "Backing up existing configurations..."
    
    local configs=(
        "/etc/hostapd/hostapd.conf"
        "/etc/dnsmasq.conf"
        "/etc/dhcpcd.conf"
        "/etc/default/hostapd"
    )
    
    for config in "${configs[@]}"; do
        if [ -f "$config" ]; then
            cp "$config" "$config.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        fi
    done
}

# Function to disconnect from existing WiFi
disconnect_wifi() {
    print_status "Disconnecting from existing WiFi connections..."
    
    # Stop NetworkManager if running
    if systemctl is-active --quiet NetworkManager; then
        print_status "Stopping NetworkManager..."
        systemctl stop NetworkManager
        systemctl disable NetworkManager
    fi
    
    # Stop wpa_supplicant
    if systemctl is-active --quiet wpa_supplicant; then
        print_status "Stopping wpa_supplicant..."
        systemctl stop wpa_supplicant
    fi
    
    # Kill any running wpa_supplicant processes
    pkill wpa_supplicant 2>/dev/null || true
    
    # Disconnect using nmcli if available
    if command -v nmcli &> /dev/null; then
        nmcli device disconnect "$INTERFACE" 2>/dev/null || true
    fi
    
    # Bring interface down and up
    ip link set "$INTERFACE" down
    sleep 2
    ip link set "$INTERFACE" up
    sleep 2
}

# Function to configure hostapd
configure_hostapd() {
    print_status "Configuring hostapd..."
    
    # Check RTL8852BE specific requirements
    local driver="nl80211"
    local hw_mode="g"  # Start with 2.4GHz for compatibility
    
    cat > /etc/hostapd/hostapd.conf << EOF
# Radxa Rock5B+ hostapd configuration
# RTL8852BE chipset configuration

# Interface and driver
interface=$INTERFACE
driver=$driver

# Basic AP settings
ssid=$SSID
hw_mode=$hw_mode
channel=$CHANNEL
country_code=$COUNTRY_CODE

# Advanced settings for RTL8852BE
wmm_enabled=1
ieee80211n=1
ht_capab=[HT40][SHORT-GI-20][SHORT-GI-40]

# Security settings
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSPHRASE
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# Additional stability settings for Realtek chipsets
beacon_int=100
dtim_period=2
max_num_sta=10
EOF

    # Configure hostapd daemon
    echo "DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"" > /etc/default/hostapd
    
    print_success "hostapd configured"
}

# Function to configure dnsmasq
configure_dnsmasq() {
    print_status "Configuring dnsmasq..."
    
    # Backup original dnsmasq.conf
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig 2>/dev/null || true
    
    cat > /etc/dnsmasq.conf << EOF
# Radxa Rock5B+ dnsmasq configuration
# DHCP and DNS server for AP mode

# Interface configuration
interface=$INTERFACE
bind-interfaces

# DHCP configuration
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,255.255.255.0,24h
dhcp-option=3,$AP_IP
dhcp-option=6,$AP_IP

# DNS configuration
server=8.8.8.8
server=8.8.4.4
domain-needed
bogus-priv

# Logging (for troubleshooting)
log-queries
log-dhcp

# Performance settings
cache-size=1000
EOF

    print_success "dnsmasq configured"
}

# Function to configure network interface
configure_interface() {
    print_status "Configuring network interface..."
    
    # Configure static IP for AP interface
    cat >> /etc/dhcpcd.conf << EOF

# Radxa AP mode configuration
interface $INTERFACE
static ip_address=$AP_IP/24
nohook wpa_supplicant
EOF

    # Alternative: use systemd-networkd if dhcpcd is not working
    if ! systemctl is-enabled dhcpcd &>/dev/null; then
        print_warning "dhcpcd not available, configuring with ip command"
        ip addr flush dev "$INTERFACE"
        ip addr add "$AP_IP/24" dev "$INTERFACE"
        ip link set "$INTERFACE" up
    fi
}

# Function to configure iptables for NAT
configure_iptables() {
    print_status "Configuring iptables for NAT..."
    
    # Enable IP forwarding
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Find the internet interface (usually eth0 or similar)
    local internet_if=$(ip route | grep default | head -1 | awk '{print $5}')
    if [ -z "$internet_if" ]; then
        print_warning "Could not detect internet interface, using eth0"
        internet_if="eth0"
    fi
    
    print_status "Using $internet_if as internet interface"
    
    # Clear existing rules
    iptables -t nat -F
    iptables -t mangle -F
    iptables -F
    iptables -X
    
    # Set up NAT
    iptables -t nat -A POSTROUTING -o "$internet_if" -j MASQUERADE
    iptables -A FORWARD -i "$internet_if" -o "$INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i "$INTERFACE" -o "$internet_if" -j ACCEPT
    
    # Allow AP traffic
    iptables -A INPUT -i "$INTERFACE" -j ACCEPT
    iptables -A OUTPUT -o "$INTERFACE" -j ACCEPT
    
    # Save iptables rules
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    elif command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
    fi
    
    print_success "iptables configured"
}

# Function to start services
start_services() {
    print_status "Starting AP services..."
    
    # Unmask and enable services
    systemctl unmask hostapd 2>/dev/null || true
    systemctl enable hostapd
    systemctl enable dnsmasq
    
    # Restart networking
    if systemctl is-active --quiet dhcpcd; then
        systemctl restart dhcpcd
    fi
    
    # Start hostapd
    print_status "Starting hostapd..."
    if ! systemctl start hostapd; then
        print_error "Failed to start hostapd"
        print_status "Checking hostapd status..."
        systemctl status hostapd --no-pager -l
        journalctl -u hostapd --no-pager -l | tail -20
        return 1
    fi
    
    sleep 3
    
    # Start dnsmasq
    print_status "Starting dnsmasq..."
    if ! systemctl start dnsmasq; then
        print_error "Failed to start dnsmasq"
        print_status "Checking dnsmasq status..."
        systemctl status dnsmasq --no-pager -l
        journalctl -u dnsmasq --no-pager -l | tail -20
        return 1
    fi
    
    print_success "Services started successfully"
}

# Function to verify AP is working
verify_ap() {
    print_status "Verifying AP setup..."
    
    # Check if services are running
    if ! systemctl is-active --quiet hostapd; then
        print_error "hostapd is not running"
        return 1
    fi
    
    if ! systemctl is-active --quiet dnsmasq; then
        print_error "dnsmasq is not running"
        return 1
    fi
    
    # Check interface configuration
    if ! ip addr show "$INTERFACE" | grep -q "$AP_IP"; then
        print_error "Interface $INTERFACE does not have IP $AP_IP"
        return 1
    fi
    
    # Check if AP is broadcasting
    sleep 5
    if command -v iw &> /dev/null; then
        if ! iw dev "$INTERFACE" info | grep -q "type AP"; then
            print_warning "Interface may not be in AP mode"
        fi
    fi
    
    print_success "AP verification completed"
    print_status "SSID: $SSID"
    print_status "Password: $PASSPHRASE"
    print_status "AP IP: $AP_IP"
    print_status "DHCP Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
}

# Function to run speed test
speed_test() {
    print_status "Setting up speed test server..."
    
    if command -v iperf3 &> /dev/null; then
        print_status "Starting iperf3 server on port 5201..."
        print_status "Connect a client and run: iperf3 -c $AP_IP"
        iperf3 -s -D  # Start as daemon
    else
        print_warning "iperf3 not installed. Install with: apt install iperf3"
    fi
}

# Function to show troubleshooting info
show_troubleshooting() {
    print_status "Troubleshooting information:"
    echo -e "${YELLOW}Common issues and solutions:${NC}"
    echo "1. If clients can't connect:"
    echo "   - Check password is correct"
    echo "   - Try different channel (1, 6, 11)"
    echo "   - Check 'journalctl -u hostapd -f'"
    echo ""
    echo "2. If no internet access:"
    echo "   - Check iptables rules: iptables -t nat -L"
    echo "   - Verify IP forwarding: cat /proc/sys/net/ipv4/ip_forward"
    echo "   - Check default route: ip route"
    echo ""
    echo "3. Logs to check:"
    echo "   - hostapd: journalctl -u hostapd -f"
    echo "   - dnsmasq: journalctl -u dnsmasq -f"
    echo "   - DHCP leases: cat /var/lib/dhcp/dhcpd.leases"
    echo ""
    echo "4. Restart services:"
    echo "   - systemctl restart hostapd"
    echo "   - systemctl restart dnsmasq"
    echo ""
    echo "5. RTL8852BE specific:"
    echo "   - Driver: $(lsmod | grep rtw89)"
    echo "   - May need firmware updates for stability"
}

# Main execution
main() {
    clear
    print_status "Radxa Rock5B+ Access Point Setup Script"
    print_status "Designed for RTL8852BE WiFi chipset"
    print_status "Log file: $LOG_FILE"
    echo ""
    
    # Prompt for configuration
    read -p "Enter SSID [$SSID]: " input_ssid
    SSID=${input_ssid:-$SSID}
    
    read -s -p "Enter WiFi Password [$PASSPHRASE]: " input_pass
    PASSPHRASE=${input_pass:-$PASSPHRASE}
    echo ""
    
    read -p "Enter AP IP [$AP_IP]: " input_ip
    AP_IP=${input_ip:-$AP_IP}
    
    echo ""
    print_status "Configuration:"
    print_status "SSID: $SSID"
    print_status "AP IP: $AP_IP"
    echo ""
    
    read -p "Continue with setup? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled"
        exit 0
    fi
    
    # Execute setup steps
    check_root
    detect_wifi_interface
    install_packages
    backup_configs
    disconnect_wifi
    configure_hostapd
    configure_dnsmasq
    configure_interface
    configure_iptables
    
    if start_services && verify_ap; then
        print_success "Access Point setup completed successfully!"
        echo ""
        show_troubleshooting
        speed_test
    else
        print_error "Setup failed. Check logs and troubleshooting info."
        show_troubleshooting
        exit 1
    fi
}

# Trap to cleanup on script exit
trap 'print_status "Script interrupted"' INT TERM

# Run main function
main "$@"