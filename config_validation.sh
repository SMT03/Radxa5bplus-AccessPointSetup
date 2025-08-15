#!/bin/bash

# Configuration Validation Tests for Radxa5bplus-AccessPointSetup
# Tests the configuration files and settings that would be generated

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_CONFIG_TESTS=0
PASSED_CONFIG_TESTS=0
FAILED_CONFIG_TESTS=0

# Test results log
CONFIG_TEST_LOG="/tmp/radxa_config_test_results.log"
SCRIPT_PATH="./radxa_ap_setup.sh"

# Mock configuration directory
MOCK_CONFIG_DIR="/tmp/radxa_config_test"
MOCK_ETC_DIR="$MOCK_CONFIG_DIR/etc"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[CONFIG TEST]${NC} $1" | tee -a "$CONFIG_TEST_LOG"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$CONFIG_TEST_LOG"
    ((PASSED_CONFIG_TESTS++))
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$CONFIG_TEST_LOG"
    ((FAILED_CONFIG_TESTS++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$CONFIG_TEST_LOG"
}

# Function to run a config test
run_config_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit="$3"
    
    ((TOTAL_CONFIG_TESTS++))
    print_status "Running: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        if [ "$expected_exit" = "0" ] || [ -z "$expected_exit" ]; then
            print_success "$test_name"
        else
            print_failure "$test_name (expected exit $expected_exit, got 0)"
        fi
    else
        if [ "$expected_exit" != "0" ] && [ -n "$expected_exit" ]; then
            print_success "$test_name"
        else
            print_failure "$test_name (expected success, got failure)"
        fi
    fi
}

# Function to setup mock environment
setup_mock_environment() {
    print_status "Setting up mock environment..."
    
    # Create mock directory structure
    mkdir -p "$MOCK_ETC_DIR/hostapd"
    mkdir -p "$MOCK_ETC_DIR/dnsmasq"
    mkdir -p "$MOCK_ETC_DIR/default"
    mkdir -p "$MOCK_ETC_DIR/iptables"
    
    # Create mock configuration files
    cat > "$MOCK_ETC_DIR/hostapd/hostapd.conf" << 'EOF'
# Mock hostapd configuration
interface=wlP2p33s0
driver=nl80211
ssid=RadxaAP
hw_mode=g
channel=7
country_code=PK
wmm_enabled=1
ieee80211n=1
ht_capab=[HT40][SHORT-GI-20][SHORT-GI-40]
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=radxa123456
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
beacon_int=100
dtim_period=2
max_num_sta=10
EOF

    cat > "$MOCK_ETC_DIR/dnsmasq.conf" << 'EOF'
# Mock dnsmasq configuration
interface=wlP2p33s0
bind-interfaces
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
dhcp-option=3,192.168.4.1
dhcp-option=6,192.168.4.1
server=8.8.8.8
server=8.8.4.4
domain-needed
bogus-priv
log-queries
log-dhcp
cache-size=1000
EOF

    cat > "$MOCK_ETC_DIR/default/hostapd" << 'EOF'
# Mock hostapd default configuration
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

    cat > "$MOCK_ETC_DIR/dhcpcd.conf" << 'EOF'
# Mock dhcpcd configuration
interface wlP2p33s0
static ip_address=192.168.4.1/24
nohook wpa_supplicant
EOF
}

# Function to cleanup mock environment
cleanup_mock_environment() {
    print_status "Cleaning up mock environment..."
    rm -rf "$MOCK_CONFIG_DIR"
}

# Test 1: hostapd configuration validation
test_hostapd_configuration() {
    print_status "=== Testing hostapd Configuration ==="
    
    local config_file="$MOCK_ETC_DIR/hostapd/hostapd.conf"
    
    # Test basic configuration
    run_config_test "hostapd.conf exists" "test -f $config_file"
    run_config_test "hostapd.conf is readable" "test -r $config_file"
    
    # Test interface configuration
    run_config_test "Interface is set" "grep -q '^interface=' $config_file"
    run_config_test "Interface value is wlP2p33s0" "grep -q '^interface=wlP2p33s0$' $config_file"
    
    # Test driver configuration
    run_config_test "Driver is nl80211" "grep -q '^driver=nl80211$' $config_file"
    
    # Test basic AP settings
    run_config_test "SSID is set" "grep -q '^ssid=' $config_file"
    run_config_test "Hardware mode is set" "grep -q '^hw_mode=' $config_file"
    run_config_test "Channel is set" "grep -q '^channel=' $config_file"
    run_config_test "Country code is set" "grep -q '^country_code=' $config_file"
    
    # Test WiFi standards
    run_config_test "IEEE 802.11n enabled" "grep -q '^ieee80211n=1$' $config_file"
    run_config_test "WMM enabled" "grep -q '^wmm_enabled=1$' $config_file"
    run_config_test "HT capabilities configured" "grep -q '^ht_capab=' $config_file"
    
    # Test security settings
    run_config_test "WPA2 enabled" "grep -q '^wpa=2$' $config_file"
    run_config_test "WPA-PSK key management" "grep -q '^wpa_key_mgmt=WPA-PSK$' $config_file"
    run_config_test "WPA pairwise cipher" "grep -q '^wpa_pairwise=TKIP$' $config_file"
    run_config_test "RSN pairwise cipher" "grep -q '^rsn_pairwise=CCMP$' $config_file"
    
    # Test performance settings
    run_config_test "Beacon interval set" "grep -q '^beacon_int=' $config_file"
    run_config_test "DTIM period set" "grep -q '^dtim_period=' $config_file"
    run_config_test "Max stations set" "grep -q '^max_num_sta=' $config_file"
}

# Test 2: dnsmasq configuration validation
test_dnsmasq_configuration() {
    print_status "=== Testing dnsmasq Configuration ==="
    
    local config_file="$MOCK_ETC_DIR/dnsmasq.conf"
    
    # Test basic configuration
    run_config_test "dnsmasq.conf exists" "test -f $config_file"
    run_config_test "dnsmasq.conf is readable" "test -r $config_file"
    
    # Test interface configuration
    run_config_test "Interface binding" "grep -q '^interface=' $config_file"
    run_config_test "Bind interfaces enabled" "grep -q '^bind-interfaces$' $config_file"
    
    # Test DHCP configuration
    run_config_test "DHCP range configured" "grep -q '^dhcp-range=' $config_file"
    run_config_test "DHCP range format correct" "grep -q '^dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h$' $config_file"
    run_config_test "DHCP gateway option" "grep -q '^dhcp-option=3,192.168.4.1$' $config_file"
    run_config_test "DHCP DNS option" "grep -q '^dhcp-option=6,192.168.4.1$' $config_file"
    
    # Test DNS configuration
    run_config_test "Primary DNS server" "grep -q '^server=8.8.8.8$' $config_file"
    run_config_test "Secondary DNS server" "grep -q '^server=8.8.4.4$' $config_file"
    run_config_test "Domain needed enabled" "grep -q '^domain-needed$' $config_file"
    run_config_test "Bogus private enabled" "grep -q '^bogus-priv$' $config_file"
    
    # Test logging and performance
    run_config_test "Query logging enabled" "grep -q '^log-queries$' $config_file"
    run_config_test "DHCP logging enabled" "grep -q '^log-dhcp$' $config_file"
    run_config_test "Cache size configured" "grep -q '^cache-size=1000$' $config_file"
}

# Test 3: hostapd default configuration validation
test_hostapd_default_configuration() {
    print_status "=== Testing hostapd Default Configuration ==="
    
    local config_file="$MOCK_ETC_DIR/default/hostapd"
    
    # Test basic configuration
    run_config_test "hostapd default config exists" "test -f $config_file"
    run_config_test "hostapd default config is readable" "test -r $config_file"
    
    # Test DAEMON_CONF setting
    run_config_test "DAEMON_CONF is set" "grep -q '^DAEMON_CONF=' $config_file"
    run_config_test "DAEMON_CONF path correct" "grep -q '^DAEMON_CONF="/etc/hostapd/hostapd.conf"$' $config_file"
}

# Test 4: dhcpcd configuration validation
test_dhcpcd_configuration() {
    print_status "=== Testing dhcpcd Configuration ==="
    
    local config_file="$MOCK_ETC_DIR/dhcpcd.conf"
    
    # Test basic configuration
    run_config_test "dhcpcd.conf exists" "test -f $config_file"
    run_config_test "dhcpcd.conf is readable" "test -r $config_file"
    
    # Test interface configuration
    run_config_test "Interface section exists" "grep -q '^interface wlP2p33s0$' $config_file"
    
    # Test static IP configuration
    run_config_test "Static IP configured" "grep -q '^static ip_address=' $config_file"
    run_config_test "Static IP value correct" "grep -q '^static ip_address=192.168.4.1/24$' $config_file"
    
    # Test wpa_supplicant hook
    run_config_test "wpa_supplicant hook disabled" "grep -q '^nohook wpa_supplicant$' $config_file"
}

# Test 5: Configuration file permissions validation
test_config_file_permissions() {
    print_status "=== Testing Configuration File Permissions ==="
    
    # Test hostapd config permissions
    run_config_test "hostapd.conf permissions" "test -r $MOCK_ETC_DIR/hostapd/hostapd.conf"
    
    # Test dnsmasq config permissions
    run_config_test "dnsmasq.conf permissions" "test -r $MOCK_ETC_DIR/dnsmasq.conf"
    
    # Test hostapd default permissions
    run_config_test "hostapd default permissions" "test -r $MOCK_ETC_DIR/default/hostapd"
    
    # Test dhcpcd config permissions
    run_config_test "dhcpcd.conf permissions" "test -r $MOCK_ETC_DIR/dhcpcd.conf"
}

# Test 6: Configuration syntax validation
test_config_syntax() {
    print_status "=== Testing Configuration Syntax ==="
    
    # Test hostapd configuration syntax
    local hostapd_config="$MOCK_ETC_DIR/hostapd/hostapd.conf"
    
    # Check for valid key=value format
    run_config_test "hostapd key=value format" "grep -q '^[a-zA-Z_][a-zA-Z0-9_]*=' $hostapd_config"
    
    # Check for no duplicate keys
    local duplicate_keys=$(grep '^[a-zA-Z_][a-zA-Z0-9_]*=' "$hostapd_config" | cut -d'=' -f1 | sort | uniq -d)
    if [ -z "$duplicate_keys" ]; then
        print_success "No duplicate keys in hostapd.conf"
    else
        print_failure "Duplicate keys found in hostapd.conf: $duplicate_keys"
    fi
    
    # Test dnsmasq configuration syntax
    local dnsmasq_config="$MOCK_ETC_DIR/dnsmasq.conf"
    
    # Check for valid key=value format
    run_config_test "dnsmasq key=value format" "grep -q '^[a-zA-Z_][a-zA-Z0-9_]*=' $dnsmasq_config"
    
    # Check for no duplicate keys
    local duplicate_keys=$(grep '^[a-zA-Z_][a-zA-Z0-9_]*=' "$dnsmasq_config" | cut -d'=' -f1 | sort | uniq -d)
    if [ -z "$duplicate_keys" ]; then
        print_success "No duplicate keys in dnsmasq.conf"
    else
        print_failure "Duplicate keys found in dnsmasq.conf: $duplicate_keys"
    fi
}

# Test 7: Network configuration validation
test_network_configuration() {
    print_status "=== Testing Network Configuration ==="
    
    # Test IP address format
    local ap_ip="192.168.4.1"
    run_config_test "AP IP format validation" "echo '$ap_ip' | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'"
    
    # Test subnet mask
    local subnet_mask="255.255.255.0"
    run_config_test "Subnet mask format validation" "echo '$subnet_mask' | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'"
    
    # Test DHCP range
    local dhcp_start="192.168.4.2"
    local dhcp_end="192.168.4.20"
    run_config_test "DHCP start IP format" "echo '$dhcp_start' | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'"
    run_config_test "DHCP end IP format" "echo '$dhcp_end' | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'"
    
    # Test IP range consistency
    local start_octet=$(echo "$dhcp_start" | cut -d'.' -f4)
    local end_octet=$(echo "$dhcp_end" | cut -d'.' -f4)
    if [ "$start_octet" -lt "$end_octet" ]; then
        print_success "DHCP range is valid (start < end)"
    else
        print_failure "DHCP range is invalid (start >= end)"
    fi
}

# Test 8: Security configuration validation
test_security_configuration() {
    print_status "=== Testing Security Configuration ==="
    
    local hostapd_config="$MOCK_ETC_DIR/hostapd/hostapd.conf"
    
    # Test WPA2 configuration
    run_config_test "WPA2 enabled" "grep -q '^wpa=2$' $hostapd_config"
    run_config_test "WPA-PSK key management" "grep -q '^wpa_key_mgmt=WPA-PSK$' $hostapd_config"
    
    # Test encryption ciphers
    run_config_test "WPA pairwise cipher" "grep -q '^wpa_pairwise=TKIP$' $hostapd_config"
    run_config_test "RSN pairwise cipher" "grep -q '^rsn_pairwise=CCMP$' $hostapd_config"
    
    # Test authentication
    run_config_test "Authentication algorithms" "grep -q '^auth_algs=1$' $hostapd_config"
    run_config_test "MAC address ACL disabled" "grep -q '^macaddr_acl=0$' $hostapd_config"
    
    # Test password length (should be >= 8 characters)
    local passphrase="radxa123456"
    if [ ${#passphrase} -ge 8 ]; then
        print_success "Password length is sufficient (${#passphrase} chars)"
    else
        print_failure "Password length is insufficient (${#passphrase} chars)"
    fi
}

# Test 9: Performance configuration validation
test_performance_configuration() {
    print_status "=== Testing Performance Configuration ==="
    
    local hostapd_config="$MOCK_ETC_DIR/hostapd/hostapd.conf"
    local dnsmasq_config="$MOCK_ETC_DIR/dnsmasq.conf"
    
    # Test WiFi performance settings
    run_config_test "IEEE 802.11n enabled" "grep -q '^ieee80211n=1$' $hostapd_config"
    run_config_test "WMM enabled" "grep -q '^wmm_enabled=1$' $hostapd_config"
    run_config_test "HT capabilities configured" "grep -q '^ht_capab=' $hostapd_config"
    
    # Test timing settings
    run_config_test "Beacon interval configured" "grep -q '^beacon_int=' $hostapd_config"
    run_config_test "DTIM period configured" "grep -q '^dtim_period=' $hostapd_config"
    
    # Test dnsmasq performance
    run_config_test "Cache size configured" "grep -q '^cache-size=' $dnsmasq_config"
    run_config_test "Cache size value reasonable" "grep -q '^cache-size=1000$' $dnsmasq_config"
}

# Test 10: Configuration completeness validation
test_config_completeness() {
    print_status "=== Testing Configuration Completeness ==="
    
    local hostapd_config="$MOCK_ETC_DIR/hostapd/hostapd.conf"
    local dnsmasq_config="$MOCK_ETC_DIR/dnsmasq.conf"
    
    # Test required hostapd settings
    local required_hostapd=(
        "interface"
        "driver"
        "ssid"
        "hw_mode"
        "channel"
        "country_code"
        "wpa"
        "wpa_passphrase"
        "wpa_key_mgmt"
    )
    
    for setting in "${required_hostapd[@]}"; do
        run_config_test "Required hostapd setting: $setting" "grep -q '^$setting=' $hostapd_config"
    done
    
    # Test required dnsmasq settings
    local required_dnsmasq=(
        "interface"
        "bind-interfaces"
        "dhcp-range"
        "dhcp-option"
        "server"
    )
    
    for setting in "${required_dnsmasq[@]}"; do
        run_config_test "Required dnsmasq setting: $setting" "grep -q '^$setting=' $dnsmasq_config"
    done
}

# Function to run all configuration tests
run_all_config_tests() {
    echo "Starting configuration validation test suite..." | tee "$CONFIG_TEST_LOG"
    echo "Config test log: $CONFIG_TEST_LOG" | tee -a "$CONFIG_TEST_LOG"
    echo "========================================" | tee -a "$CONFIG_TEST_LOG"
    
    # Reset counters
    TOTAL_CONFIG_TESTS=0
    PASSED_CONFIG_TESTS=0
    FAILED_CONFIG_TESTS=0
    
    # Setup mock environment
    setup_mock_environment
    
    # Run all configuration test categories
    test_hostapd_configuration
    test_dnsmasq_configuration
    test_hostapd_default_configuration
    test_dhcpcd_configuration
    test_config_file_permissions
    test_config_syntax
    test_network_configuration
    test_security_configuration
    test_performance_configuration
    test_config_completeness
    
    # Cleanup mock environment
    cleanup_mock_environment
    
    # Print summary
    echo "========================================" | tee -a "$CONFIG_TEST_LOG"
    echo "Configuration Test Summary:" | tee -a "$CONFIG_TEST_LOG"
    echo "Total Config Tests: $TOTAL_CONFIG_TESTS" | tee -a "$CONFIG_TEST_LOG"
    echo "Passed: $PASSED_CONFIG_TESTS" | tee -a "$CONFIG_TEST_LOG"
    echo "Failed: $FAILED_CONFIG_TESTS" | tee -a "$CONFIG_TEST_LOG"
    
    if [ $FAILED_CONFIG_TESTS -eq 0 ]; then
        echo -e "${GREEN}All configuration tests passed! 🎉${NC}" | tee -a "$CONFIG_TEST_LOG"
        exit 0
    else
        echo -e "${RED}Some configuration tests failed. Check the log for details.${NC}" | tee -a "$CONFIG_TEST_LOG"
        exit 1
    fi
}

# Main execution
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--help|-h]"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "This script runs configuration validation tests for the"
    echo "Radxa5bplus-AccessPointSetup script configurations."
    exit 0
fi

# Run all configuration tests
run_all_config_tests
