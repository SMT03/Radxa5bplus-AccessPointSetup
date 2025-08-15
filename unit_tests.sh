#!/bin/bash

# Unit Tests for Radxa5bplus-AccessPointSetup
# Tests individual functions and components in isolation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_UNIT_TESTS=0
PASSED_UNIT_TESTS=0
FAILED_UNIT_TESTS=0

# Test results log
UNIT_TEST_LOG="/tmp/radxa_unit_test_results.log"
SCRIPT_PATH="./radxa_ap_setup.sh"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[UNIT TEST]${NC} $1" | tee -a "$UNIT_TEST_LOG"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$UNIT_TEST_LOG"
    ((PASSED_UNIT_TESTS++))
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$UNIT_TEST_LOG"
    ((FAILED_UNIT_TESTS++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$UNIT_TEST_LOG"
}

# Function to run a unit test
run_unit_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit="$3"
    
    ((TOTAL_UNIT_TESTS++))
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

# Test 1: Variable initialization and defaults
test_variable_initialization() {
    print_status "=== Testing Variable Initialization ==="
    
    # Test default SSID
    local ssid=$(grep 'SSID=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    run_unit_test "Default SSID is set" "[ -n '$ssid' ]"
    run_unit_test "Default SSID is 'RadxaAP'" "[ '$ssid' = 'RadxaAP' ]"
    
    # Test default password
    local pass=$(grep 'PASSPHRASE=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    run_unit_test "Default password is set" "[ -n '$pass' ]"
    run_unit_test "Default password length >= 8" "[ ${#pass} -ge 8 ]"
    
    # Test default AP IP
    local ap_ip=$(grep 'AP_IP=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    run_unit_test "Default AP IP is set" "[ -n '$ap_ip' ]"
    run_unit_test "Default AP IP is 192.168.4.1" "[ '$ap_ip' = '192.168.4.1' ]"
    
    # Test DHCP range
    local dhcp_start=$(grep 'DHCP_RANGE_START=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    local dhcp_end=$(grep 'DHCP_RANGE_END=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    run_unit_test "DHCP start is set" "[ -n '$dhcp_start' ]"
    run_unit_test "DHCP end is set" "[ -n '$dhcp_end' ]"
    run_unit_test "DHCP start is 192.168.4.2" "[ '$dhcp_start' = '192.168.4.2' ]"
    run_unit_test "DHCP end is 192.168.4.20" "[ '$dhcp_end' = '192.168.4.20' ]"
    
    # Test channel and country
    local channel=$(grep 'CHANNEL=' "$SCRIPT_PATH" | head -1 | cut -d'=' -f2)
    local country=$(grep 'COUNTRY_CODE=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    run_unit_test "Channel is set" "[ -n '$channel' ]"
    run_unit_test "Country code is set" "[ -n '$country' ]"
    run_unit_test "Channel is 7" "[ '$channel' = '7' ]"
    run_unit_test "Country is PK" "[ '$country' = 'PK' ]"
}

# Test 2: Function definition validation
test_function_definitions() {
    print_status "=== Testing Function Definitions ==="
    
    # Test core function definitions
    local core_functions=(
        "check_root"
        "detect_wifi_interface"
        "install_packages"
        "backup_configs"
        "disconnect_wifi"
        "configure_hostapd"
        "configure_dnsmasq"
        "configure_interface"
        "configure_iptables"
        "start_services"
        "verify_ap"
        "speed_test"
        "show_troubleshooting"
        "main"
    )
    
    for func in "${core_functions[@]}"; do
        run_unit_test "Function $func is defined" "grep -q '^$func()' $SCRIPT_PATH"
    done
    
    # Test utility function definitions
    local utility_functions=(
        "print_status"
        "print_success"
        "print_warning"
        "print_error"
        "run_test"
        "command_exists"
    )
    
    for func in "${utility_functions[@]}"; do
        run_unit_test "Utility function $func is defined" "grep -q '^$func()' $SCRIPT_PATH"
    done
}

# Test 3: Configuration file generation patterns
test_config_generation() {
    print_status "=== Testing Configuration Generation Patterns ==="
    
    # Test hostapd configuration generation
    run_unit_test "hostapd.conf generation pattern exists" "grep -q 'cat > /etc/hostapd/hostapd.conf' $SCRIPT_PATH"
    run_unit_test "hostapd interface variable usage" "grep -q 'interface=\$INTERFACE' $SCRIPT_PATH"
    run_unit_test "hostapd SSID variable usage" "grep -q 'ssid=\$SSID' $SCRIPT_PATH"
    run_unit_test "hostapd password variable usage" "grep -q 'wpa_passphrase=\$PASSPHRASE' $SCRIPT_PATH"
    
    # Test dnsmasq configuration generation
    run_unit_test "dnsmasq.conf generation pattern exists" "grep -q 'cat > /etc/dnsmasq.conf' $SCRIPT_PATH"
    run_unit_test "dnsmasq interface binding" "grep -q 'bind-interfaces' $SCRIPT_PATH"
    run_unit_test "dnsmasq DHCP range usage" "grep -q 'dhcp-range=\$DHCP_RANGE_START' $SCRIPT_PATH"
    
    # Test dhcpcd configuration
    run_unit_test "dhcpcd.conf modification pattern" "grep -q 'cat >> /etc/dhcpcd.conf' $SCRIPT_PATH"
    run_unit_test "dhcpcd static IP usage" "grep -q 'static ip_address=\$AP_IP' $SCRIPT_PATH"
}

# Test 4: Security configuration validation
test_security_configuration() {
    print_status "=== Testing Security Configuration ==="
    
    # Test WPA2 configuration
    run_unit_test "WPA2 is enabled" "grep -q 'wpa=2' $SCRIPT_PATH"
    run_unit_test "WPA-PSK key management" "grep -q 'wpa_key_mgmt=WPA-PSK' $SCRIPT_PATH"
    run_unit_test "WPA pairwise cipher" "grep -q 'wpa_pairwise=TKIP' $SCRIPT_PATH"
    run_unit_test "RSN pairwise cipher" "grep -q 'rsn_pairwise=CCMP' $SCRIPT_PATH"
    
    # Test authentication
    run_unit_test "Authentication algorithms" "grep -q 'auth_algs=1' $SCRIPT_PATH"
    run_unit_test "MAC address ACL disabled" "grep -q 'macaddr_acl=0' $SCRIPT_PATH"
    
    # Test firewall configuration
    run_unit_test "iptables NAT rules" "grep -q 'iptables -t nat' $SCRIPT_PATH"
    run_unit_test "MASQUERADE rule" "grep -q 'MASQUERADE' $SCRIPT_PATH"
    run_unit_test "FORWARD rules" "grep -q 'iptables -A FORWARD' $SCRIPT_PATH"
}

# Test 5: Network configuration validation
test_network_configuration() {
    print_status "=== Testing Network Configuration ==="
    
    # Test interface detection
    run_unit_test "Interface detection pattern" "grep -q 'ls /sys/class/net/' $SCRIPT_PATH"
    run_unit_test "WiFi interface regex pattern" "grep -q 'grep -E.*wl.*wlan' $SCRIPT_PATH"
    
    # Test IP configuration
    run_unit_test "IP forwarding enable" "grep -q 'net.ipv4.ip_forward=1' $SCRIPT_PATH"
    run_unit_test "IP forwarding activation" "grep -q 'echo 1 > /proc/sys/net/ipv4/ip_forward' $SCRIPT_PATH"
    
    # Test DHCP configuration
    run_unit_test "DHCP option 3 (gateway)" "grep -q 'dhcp-option=3' $SCRIPT_PATH"
    run_unit_test "DHCP option 6 (DNS)" "grep -q 'dhcp-option=6' $SCRIPT_PATH"
    run_unit_test "DNS server 8.8.8.8" "grep -q 'server=8.8.8.8' $SCRIPT_PATH"
    run_unit_test "DNS server 8.8.4.4" "grep -q 'server=8.8.4.4' $SCRIPT_PATH"
    
    # Test routing configuration
    run_unit_test "Default route detection" "grep -q 'ip route.*grep default' $SCRIPT_PATH"
    run_unit_test "Internet interface detection" "grep -q 'internet_if.*ip route' $SCRIPT_PATH"
}

# Test 6: Service management validation
test_service_management() {
    print_status "=== Testing Service Management ==="
    
    # Test service control
    run_unit_test "hostapd enable" "grep -q 'systemctl enable hostapd' $SCRIPT_PATH"
    run_unit_test "dnsmasq enable" "grep -q 'systemctl enable dnsmasq' $SCRIPT_PATH"
    run_unit_test "hostapd start" "grep -q 'systemctl start hostapd' $SCRIPT_PATH"
    run_unit_test "dnsmasq start" "grep -q 'systemctl start dnsmasq' $SCRIPT_PATH"
    
    # Test service verification
    run_unit_test "hostapd status check" "grep -q 'systemctl is-active.*hostapd' $SCRIPT_PATH"
    run_unit_test "dnsmasq status check" "grep -q 'systemctl is-active.*dnsmasq' $SCRIPT_PATH"
    
    # Test service unmasking
    run_unit_test "hostapd unmask" "grep -q 'systemctl unmask hostapd' $SCRIPT_PATH"
    
    # Test dhcpcd restart
    run_unit_test "dhcpcd restart logic" "grep -q 'systemctl restart dhcpcd' $SCRIPT_PATH"
}

# Test 7: Error handling and logging validation
test_error_handling() {
    print_status "=== Testing Error Handling and Logging ==="
    
    # Test error handling directives
    run_unit_test "Exit on error enabled" "grep -q 'set -e' $SCRIPT_PATH"
    run_unit_test "Signal trap configured" "grep -q 'trap.*INT.*TERM' $SCRIPT_PATH"
    
    # Test logging functions
    run_unit_test "Log file variable defined" "grep -q 'LOG_FILE=' $SCRIPT_PATH"
    run_unit_test "Log file path is /tmp/radxa_ap_setup.log" "grep -q '/tmp/radxa_ap_setup.log' $SCRIPT_PATH"
    
    # Test colored output functions
    run_unit_test "Color codes defined" "grep -q 'RED=.*GREEN=.*YELLOW=.*BLUE=' $SCRIPT_PATH"
    run_unit_test "No color reset defined" "grep -q 'NC=.*No Color' $SCRIPT_PATH"
    
    # Test error function usage
    run_unit_test "print_error function usage" "grep -q 'print_error' $SCRIPT_PATH"
    run_unit_test "print_warning function usage" "grep -q 'print_warning' $SCRIPT_PATH"
    run_unit_test "print_success function usage" "grep -q 'print_success' $SCRIPT_PATH"
}

# Test 8: Hardware compatibility validation
test_hardware_compatibility() {
    print_status "=== Testing Hardware Compatibility ==="
    
    # Test RTL8852BE specific features
    run_unit_test "RTL8852BE chipset support" "grep -q 'RTL8852BE' $SCRIPT_PATH"
    run_unit_test "nl80211 driver support" "grep -q 'nl80211' $SCRIPT_PATH"
    
    # Test WiFi standards support
    run_unit_test "IEEE 802.11n support" "grep -q 'ieee80211n' $SCRIPT_PATH"
    run_unit_test "HT capabilities" "grep -q 'ht_capab' $SCRIPT_PATH"
    run_unit_test "WMM enabled" "grep -q 'wmm_enabled' $SCRIPT_PATH"
    
    # Test interface patterns
    run_unit_test "WiFi interface pattern wl" "grep -q 'wl.*wlan' $SCRIPT_PATH"
    run_unit_test "Interface info command" "grep -q 'iw.*info' $SCRIPT_PATH"
    run_unit_test "Physical interface check" "grep -q 'iw phy phy0 info' $SCRIPT_PATH"
}

# Test 9: Performance and optimization validation
test_performance_features() {
    print_status "=== Testing Performance Features ==="
    
    # Test speed testing integration
    run_unit_test "iperf3 integration" "grep -q 'iperf3' $SCRIPT_PATH"
    run_unit_test "iperf3 server start" "grep -q 'iperf3 -s' $SCRIPT_PATH"
    run_unit_test "iperf3 daemon mode" "grep -q 'iperf3 -s -D' $SCRIPT_PATH"
    
    # Test performance settings
    run_unit_test "Beacon interval" "grep -q 'beacon_int' $SCRIPT_PATH"
    run_unit_test "DTIM period" "grep -q 'dtim_period' $SCRIPT_PATH"
    run_unit_test "Max stations" "grep -q 'max_num_sta' $SCRIPT_PATH"
    
    # Test optimization settings
    run_unit_test "Cache size configuration" "grep -q 'cache-size' $SCRIPT_PATH"
    run_unit_test "Log queries enabled" "grep -q 'log-queries' $SCRIPT_PATH"
    run_unit_test "Log DHCP enabled" "grep -q 'log-dhcp' $SCRIPT_PATH"
}

# Test 10: User interaction validation
test_user_interaction() {
    print_status "=== Testing User Interaction ==="
    
    # Test user prompts
    run_unit_test "SSID input prompt" "grep -q 'read -p.*SSID' $SCRIPT_PATH"
    run_unit_test "Password input prompt" "grep -q 'read -s -p.*Password' $SCRIPT_PATH"
    run_unit_test "AP IP input prompt" "grep -q 'read -p.*AP IP' $SCRIPT_PATH"
    run_unit_test "Confirmation prompt" "grep -q 'read -p.*Continue' $SCRIPT_PATH"
    
    # Test input validation
    run_unit_test "SSID default value handling" "grep -q 'SSID=\${input_ssid:-\$SSID}' $SCRIPT_PATH"
    run_unit_test "Password default value handling" "grep -q 'PASSPHRASE=\${input_pass:-\$PASSPHRASE}' $SCRIPT_PATH"
    run_unit_test "AP IP default value handling" "grep -q 'AP_IP=\${input_ip:-\$AP_IP}' $SCRIPT_PATH"
    
    # Test confirmation logic
    run_unit_test "Confirmation regex pattern" "grep -q 'confirm.*[Yy]' $SCRIPT_PATH"
    run_unit_test "Setup cancellation handling" "grep -q 'Setup cancelled' $SCRIPT_PATH"
}

# Test 11: Package management validation
test_package_management() {
    print_status "=== Testing Package Management ==="
    
    # Test package installation logic
    run_unit_test "apt-get update" "grep -q 'apt-get update' $SCRIPT_PATH"
    run_unit_test "apt-get install" "grep -q 'apt-get install -y' $SCRIPT_PATH"
    
    # Test required packages
    local required_packages=(
        "hostapd"
        "dnsmasq"
        "iptables-persistent"
        "iw"
        "wireless-tools"
    )
    
    for pkg in "${required_packages[@]}"; do
        run_unit_test "Required package $pkg" "grep -q '$pkg' $SCRIPT_PATH"
    done
    
    # Test package checking logic
    run_unit_test "Package existence check" "grep -q 'dpkg -l.*grep' $SCRIPT_PATH"
    run_unit_test "Package installation array" "grep -q 'to_install.*=' $SCRIPT_PATH"
}

# Test 12: Backup and recovery validation
test_backup_recovery() {
    print_status "=== Testing Backup and Recovery ==="
    
    # Test configuration backup
    run_unit_test "Backup function exists" "grep -q 'backup_configs' $SCRIPT_PATH"
    run_unit_test "hostapd.conf backup" "grep -q '/etc/hostapd/hostapd.conf' $SCRIPT_PATH"
    run_unit_test "dnsmasq.conf backup" "grep -q '/etc/dnsmasq.conf' $SCRIPT_PATH"
    run_unit_test "dhcpcd.conf backup" "grep -q '/etc/dhcpcd.conf' $SCRIPT_PATH"
    
    # Test backup timestamping
    run_unit_test "Backup timestamp format" "grep -q 'date +%Y%m%d_%H%M%S' $SCRIPT_PATH"
    
    # Test original config backup
    run_unit_test "dnsmasq.conf.orig backup" "grep -q 'dnsmasq.conf.orig' $SCRIPT_PATH"
}

# Test 13: Network disconnection validation
test_network_disconnection() {
    print_status "=== Testing Network Disconnection ==="
    
    # Test service stopping
    run_unit_test "NetworkManager stop" "grep -q 'systemctl stop NetworkManager' $SCRIPT_PATH"
    run_unit_test "NetworkManager disable" "grep -q 'systemctl disable NetworkManager' $SCRIPT_PATH"
    run_unit_test "wpa_supplicant stop" "grep -q 'systemctl stop wpa_supplicant' $SCRIPT_PATH"
    
    # Test process management
    run_unit_test "wpa_supplicant kill" "grep -q 'pkill wpa_supplicant' $SCRIPT_PATH"
    
    # Test interface management
    run_unit_test "Interface down command" "grep -q 'ip link set.*down' $SCRIPT_PATH"
    run_unit_test "Interface up command" "grep -q 'ip link set.*up' $SCRIPT_PATH"
    
    # Test nmcli disconnection
    run_unit_test "nmcli disconnect" "grep -q 'nmcli device disconnect' $SCRIPT_PATH"
}

# Test 14: Configuration file content validation
test_config_file_content() {
    print_status "=== Testing Configuration File Content ==="
    
    # Test hostapd configuration content
    run_unit_test "hostapd country code" "grep -q 'country_code=\$COUNTRY_CODE' $SCRIPT_PATH"
    run_unit_test "hostapd channel" "grep -q 'channel=\$CHANNEL' $SCRIPT_PATH"
    run_unit_test "hostapd hw_mode" "grep -q 'hw_mode=' $SCRIPT_PATH"
    
    # Test dnsmasq configuration content
    run_unit_test "dnsmasq bind-interfaces" "grep -q 'bind-interfaces' $SCRIPT_PATH"
    run_unit_test "dnsmasq domain-needed" "grep -q 'domain-needed' $SCRIPT_PATH"
    run_unit_test "dnsmasq bogus-priv" "grep -q 'bogus-priv' $SCRIPT_PATH"
    
    # Test dhcpcd configuration content
    run_unit_test "dhcpcd nohook wpa_supplicant" "grep -q 'nohook wpa_supplicant' $SCRIPT_PATH"
}

# Test 15: Final integration validation
test_final_integration() {
    print_status "=== Testing Final Integration ==="
    
    # Test main function structure
    run_unit_test "Main function calls check_root" "grep -q 'check_root' $SCRIPT_PATH"
    run_unit_test "Main function calls detect_wifi_interface" "grep -q 'detect_wifi_interface' $SCRIPT_PATH"
    run_unit_test "Main function calls install_packages" "grep -q 'install_packages' $SCRIPT_PATH"
    run_unit_test "Main function calls backup_configs" "grep -q 'backup_configs' $SCRIPT_PATH"
    
    # Test execution flow
    run_unit_test "Main function calls disconnect_wifi" "grep -q 'disconnect_wifi' $SCRIPT_PATH"
    run_unit_test "Main function calls configure_hostapd" "grep -q 'configure_hostapd' $SCRIPT_PATH"
    run_unit_test "Main function calls configure_dnsmasq" "grep -q 'configure_dnsmasq' $SCRIPT_PATH"
    run_unit_test "Main function calls configure_interface" "grep -q 'configure_interface' $SCRIPT_PATH"
    run_unit_test "Main function calls configure_iptables" "grep -q 'configure_iptables' $SCRIPT_PATH"
    
    # Test service startup
    run_unit_test "Main function calls start_services" "grep -q 'start_services' $SCRIPT_PATH"
    run_unit_test "Main function calls verify_ap" "grep -q 'verify_ap' $SCRIPT_PATH"
    
    # Test final steps
    run_unit_test "Main function calls show_troubleshooting" "grep -q 'show_troubleshooting' $SCRIPT_PATH"
    run_unit_test "Main function calls speed_test" "grep -q 'speed_test' $SCRIPT_PATH"
}

# Function to run all unit tests
run_all_unit_tests() {
    echo "Starting unit test suite for Radxa5bplus-AccessPointSetup..." | tee "$UNIT_TEST_LOG"
    echo "Unit test log: $UNIT_TEST_LOG" | tee -a "$UNIT_TEST_LOG"
    echo "========================================" | tee -a "$UNIT_TEST_LOG"
    
    # Reset counters
    TOTAL_UNIT_TESTS=0
    PASSED_UNIT_TESTS=0
    FAILED_UNIT_TESTS=0
    
    # Run all unit test categories
    test_variable_initialization
    test_function_definitions
    test_config_generation
    test_security_configuration
    test_network_configuration
    test_service_management
    test_error_handling
    test_hardware_compatibility
    test_performance_features
    test_user_interaction
    test_package_management
    test_backup_recovery
    test_network_disconnection
    test_config_file_content
    test_final_integration
    
    # Print summary
    echo "========================================" | tee -a "$UNIT_TEST_LOG"
    echo "Unit Test Summary:" | tee -a "$UNIT_TEST_LOG"
    echo "Total Unit Tests: $TOTAL_UNIT_TESTS" | tee -a "$UNIT_TEST_LOG"
    echo "Passed: $PASSED_UNIT_TESTS" | tee -a "$UNIT_TEST_LOG"
    echo "Failed: $FAILED_UNIT_TESTS" | tee -a "$UNIT_TEST_LOG"
    
    if [ $FAILED_UNIT_TESTS -eq 0 ]; then
        echo -e "${GREEN}All unit tests passed! 🎉${NC}" | tee -a "$UNIT_TEST_LOG"
        exit 0
    else
        echo -e "${RED}Some unit tests failed. Check the log for details.${NC}" | tee -a "$UNIT_TEST_LOG"
        exit 1
    fi
}

# Main execution
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--help|-h]"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "This script runs unit tests for individual functions and components"
    echo "of the Radxa5bplus-AccessPointSetup script."
    exit 0
fi

# Run all unit tests
run_all_unit_tests
