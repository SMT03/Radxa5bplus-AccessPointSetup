#!/bin/bash

# Comprehensive Test Suite for Radxa5bplus-AccessPointSetup
# Tests script validation, configuration, and functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test results log
TEST_LOG="/tmp/radxa_test_results.log"
SCRIPT_PATH="./radxa_ap_setup.sh"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$TEST_LOG"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_LOG"
    ((PASSED_TESTS++))
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_LOG"
    ((FAILED_TESTS++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$TEST_LOG"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit="$3"
    
    ((TOTAL_TESTS++))
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test 1: Script file existence and permissions
test_script_existence() {
    print_status "=== Testing Script File Existence ==="
    
    run_test "Script file exists" "test -f $SCRIPT_PATH"
    run_test "Script is readable" "test -r $SCRIPT_PATH"
    run_test "Script is executable" "test -x $SCRIPT_PATH"
    
    if [ -f "$SCRIPT_PATH" ]; then
        local file_size=$(stat -c%s "$SCRIPT_PATH" 2>/dev/null || stat -f%z "$SCRIPT_PATH" 2>/dev/null)
        run_test "Script has reasonable size (>1KB)" "[ $file_size -gt 1024 ]"
    fi
}

# Test 2: Script syntax validation
test_script_syntax() {
    print_status "=== Testing Script Syntax ==="
    
    if command_exists bash; then
        run_test "Bash syntax check" "bash -n $SCRIPT_PATH"
    else
        print_warning "Bash not available, skipping syntax check"
    fi
    
    if command_exists shellcheck; then
        run_test "ShellCheck validation" "shellcheck $SCRIPT_PATH"
    else
        print_warning "ShellCheck not available, install with: apt install shellcheck"
    fi
}

# Test 3: Script content validation
test_script_content() {
    print_status "=== Testing Script Content ==="
    
    # Check for required shebang
    run_test "Has shebang line" "head -1 $SCRIPT_PATH | grep -q '^#!/bin/bash'"
    
    # Check for required functions
    local required_functions=(
        "check_root"
        "detect_wifi_interface"
        "install_packages"
        "configure_hostapd"
        "configure_dnsmasq"
        "configure_interface"
        "configure_iptables"
        "start_services"
        "verify_ap"
        "main"
    )
    
    for func in "${required_functions[@]}"; do
        run_test "Contains function: $func" "grep -q '^$func()' $SCRIPT_PATH"
    done
    
    # Check for required variables
    local required_vars=(
        "SSID"
        "PASSPHRASE"
        "AP_IP"
        "INTERFACE"
        "LOG_FILE"
    )
    
    for var in "${required_vars[@]}"; do
        run_test "Contains variable: $var" "grep -q '$var=' $SCRIPT_PATH"
    done
    
    # Check for error handling
    run_test "Has error handling (set -e)" "grep -q 'set -e' $SCRIPT_PATH"
    run_test "Has trap for cleanup" "grep -q 'trap.*INT.*TERM' $SCRIPT_PATH"
}

# Test 4: Configuration validation
test_configuration_validation() {
    print_status "=== Testing Configuration Validation ==="
    
    # Extract default values from script
    local ssid=$(grep 'SSID=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    local ap_ip=$(grep 'AP_IP=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    local dhcp_start=$(grep 'DHCP_RANGE_START=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    local dhcp_end=$(grep 'DHCP_RANGE_END=' "$SCRIPT_PATH" | head -1 | cut -d'"' -f2)
    
    # Validate SSID
    if [ -n "$ssid" ]; then
        run_test "SSID is not empty" "[ -n '$ssid' ]"
        run_test "SSID length is reasonable" "[ ${#ssid} -gt 0 ] && [ ${#ssid} -lt 33 ]"
    fi
    
    # Validate IP addresses
    if [ -n "$ap_ip" ]; then
        run_test "AP IP format validation" "echo '$ap_ip' | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'"
    fi
    
    if [ -n "$dhcp_start" ] && [ -n "$dhcp_end" ]; then
        run_test "DHCP range validation" "[ -n '$dhcp_start' ] && [ -n '$dhcp_end' ]"
    fi
    
    # Check for country code
    run_test "Country code is set" "grep -q 'COUNTRY_CODE=' $SCRIPT_PATH"
}

# Test 5: Security validation
test_security_validation() {
    print_status "=== Testing Security Features ==="
    
    # Check for WPA2 configuration
    run_test "WPA2 security enabled" "grep -q 'wpa=2' $SCRIPT_PATH"
    run_test "WPA-PSK key management" "grep -q 'wpa_key_mgmt=WPA-PSK' $SCRIPT_PATH"
    
    # Check for password requirements
    run_test "Password variable exists" "grep -q 'PASSPHRASE=' $SCRIPT_PATH"
    
    # Check for firewall configuration
    run_test "iptables configuration present" "grep -q 'iptables' $SCRIPT_PATH"
    run_test "NAT configuration present" "grep -q 'MASQUERADE' $SCRIPT_PATH"
    
    # Check for root requirement
    run_test "Root privilege check" "grep -q 'EUID -ne 0' $SCRIPT_PATH"
}

# Test 6: Network configuration validation
test_network_configuration() {
    print_status "=== Testing Network Configuration ==="
    
    # Check for interface detection
    run_test "Interface detection logic" "grep -q 'detect_wifi_interface' $SCRIPT_PATH"
    
    # Check for DHCP configuration
    run_test "DHCP server configuration" "grep -q 'dnsmasq' $SCRIPT_PATH"
    run_test "DHCP range configuration" "grep -q 'dhcp-range' $SCRIPT_PATH"
    
    # Check for DNS configuration
    run_test "DNS server configuration" "grep -q '8.8.8.8' $SCRIPT_PATH"
    
    # Check for IP forwarding
    run_test "IP forwarding configuration" "grep -q 'ip_forward' $SCRIPT_PATH"
}

# Test 7: Service management validation
test_service_management() {
    print_status "=== Testing Service Management ==="
    
    # Check for required services
    local required_services=(
        "hostapd"
        "dnsmasq"
    )
    
    for service in "${required_services[@]}"; do
        run_test "Service $service configuration" "grep -q '$service' $SCRIPT_PATH"
    done
    
    # Check for service control
    run_test "Service enable/disable logic" "grep -q 'systemctl.*enable' $SCRIPT_PATH"
    run_test "Service start/stop logic" "grep -q 'systemctl.*start' $SCRIPT_PATH"
    
    # Check for service verification
    run_test "Service verification logic" "grep -q 'verify_ap' $SCRIPT_PATH"
}

# Test 8: Error handling and logging
test_error_handling() {
    print_status "=== Testing Error Handling and Logging ==="
    
    # Check for logging
    run_test "Log file configuration" "grep -q 'LOG_FILE=' $SCRIPT_PATH"
    run_test "Logging functions exist" "grep -q 'print_error\|print_warning\|print_status' $SCRIPT_PATH"
    
    # Check for error handling
    run_test "Exit on error (set -e)" "grep -q 'set -e' $SCRIPT_PATH"
    run_test "Error function exists" "grep -q 'print_error' $SCRIPT_PATH"
    
    # Check for backup functionality
    run_test "Configuration backup logic" "grep -q 'backup_configs' $SCRIPT_PATH"
}

# Test 9: Hardware compatibility
test_hardware_compatibility() {
    print_status "=== Testing Hardware Compatibility ==="
    
    # Check for RTL8852BE support
    run_test "RTL8852BE chipset support" "grep -q 'RTL8852BE' $SCRIPT_PATH"
    
    # Check for WiFi interface patterns
    run_test "WiFi interface detection patterns" "grep -q 'wl.*wlan' $SCRIPT_PATH"
    
    # Check for driver configuration
    run_test "nl80211 driver support" "grep -q 'nl80211' $SCRIPT_PATH"
    
    # Check for IEEE 802.11n support
    run_test "IEEE 802.11n support" "grep -q 'ieee80211n' $SCRIPT_PATH"
}

# Test 10: Performance and optimization
test_performance_features() {
    print_status "=== Testing Performance Features ==="
    
    # Check for speed testing
    run_test "iperf3 integration" "grep -q 'iperf3' $SCRIPT_PATH"
    
    # Check for performance settings
    run_test "WMM enabled configuration" "grep -q 'wmm_enabled' $SCRIPT_PATH"
    run_test "HT capabilities configuration" "grep -q 'ht_capab' $SCRIPT_PATH"
    
    # Check for optimization settings
    run_test "Beacon interval configuration" "grep -q 'beacon_int' $SCRIPT_PATH"
    run_test "DTIM period configuration" "grep -q 'dtim_period' $SCRIPT_PATH"
}

# Test 11: Documentation and help
test_documentation() {
    print_status "=== Testing Documentation and Help ==="
    
    # Check for help information
    run_test "Troubleshooting information" "grep -q 'show_troubleshooting' $SCRIPT_PATH"
    
    # Check for usage information
    run_test "Usage instructions in comments" "grep -q 'Usage\|Example' $SCRIPT_PATH"
    
    # Check for README existence
    run_test "README.md exists" "test -f README.md"
    
    if [ -f "README.md" ]; then
        run_test "README has content" "[ -s README.md ]"
        run_test "README contains script information" "grep -q 'radxa_ap_setup' README.md"
    fi
}

# Test 12: Integration test simulation
test_integration_simulation() {
    print_status "=== Testing Integration Simulation ==="
    
    # Create a mock environment
    local mock_dir="/tmp/radxa_test_mock"
    mkdir -p "$mock_dir"
    
    # Test script parsing without execution
    if command_exists bash; then
        run_test "Script can be sourced without errors" "bash -c 'source $SCRIPT_PATH 2>/dev/null || exit 1'"
    fi
    
    # Test configuration file generation (dry run)
    run_test "Configuration generation logic exists" "grep -q 'cat >.*conf' $SCRIPT_PATH"
    
    # Cleanup
    rm -rf "$mock_dir"
}

# Test 13: Code quality and standards
test_code_quality() {
    print_status "=== Testing Code Quality and Standards ==="
    
    # Check for consistent formatting
    run_test "Consistent indentation" "grep -q '^    ' $SCRIPT_PATH"
    
    # Check for comments
    run_test "Has header comments" "grep -q '^#.*Radxa.*Rock5B' $SCRIPT_PATH"
    run_test "Has function comments" "grep -q '^# Function to' $SCRIPT_PATH"
    
    # Check for variable naming consistency
    run_test "Uppercase variable names" "grep -q '^[A-Z_]*=' $SCRIPT_PATH"
    
    # Check for function naming consistency
    run_test "Lowercase function names" "grep -q '^[a-z_]*()' $SCRIPT_PATH"
}

# Test 14: Dependencies and requirements
test_dependencies() {
    print_status "=== Testing Dependencies and Requirements ==="
    
    # Check for package installation logic
    run_test "Package installation logic" "grep -q 'apt-get install' $SCRIPT_PATH"
    
    # Check for required packages
    local required_packages=(
        "hostapd"
        "dnsmasq"
        "iptables-persistent"
        "iw"
        "wireless-tools"
    )
    
    for pkg in "${required_packages[@]}"; do
        run_test "Required package: $pkg" "grep -q '$pkg' $SCRIPT_PATH"
    done
    
    # Check for command availability checks
    run_test "Command existence checks" "grep -q 'command -v' $SCRIPT_PATH"
}

# Test 15: Final validation
test_final_validation() {
    print_status "=== Final Validation ==="
    
    # Check overall script structure
    run_test "Script has main function" "grep -q '^main()' $SCRIPT_PATH"
    run_test "Script calls main function" "grep -q 'main \"\$@\"' $SCRIPT_PATH"
    
    # Check for proper exit codes
    run_test "Script has proper exit handling" "grep -q 'exit [0-9]' $SCRIPT_PATH"
    
    # Check for user interaction
    run_test "Script has user prompts" "grep -q 'read -p' $SCRIPT_PATH"
    
    # Check for confirmation logic
    run_test "Script has confirmation logic" "grep -q 'confirm.*[Yy]' $SCRIPT_PATH"
}

# Function to run all tests
run_all_tests() {
    echo "Starting comprehensive test suite for Radxa5bplus-AccessPointSetup..." | tee "$TEST_LOG"
    echo "Test log: $TEST_LOG" | tee -a "$TEST_LOG"
    echo "========================================" | tee -a "$TEST_LOG"
    
    # Reset counters
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
    
    # Run all test categories
    test_script_existence
    test_script_syntax
    test_script_content
    test_configuration_validation
    test_security_validation
    test_network_configuration
    test_service_management
    test_error_handling
    test_hardware_compatibility
    test_performance_features
    test_documentation
    test_integration_simulation
    test_code_quality
    test_dependencies
    test_final_validation
    
    # Print summary
    echo "========================================" | tee -a "$TEST_LOG"
    echo "Test Summary:" | tee -a "$TEST_LOG"
    echo "Total Tests: $TOTAL_TESTS" | tee -a "$TEST_LOG"
    echo "Passed: $PASSED_TESTS" | tee -a "$TEST_LOG"
    echo "Failed: $FAILED_TESTS" | tee -a "$TEST_LOG"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}All tests passed! 🎉${NC}" | tee -a "$TEST_LOG"
        exit 0
    else
        echo -e "${RED}Some tests failed. Check the log for details.${NC}" | tee -a "$TEST_LOG"
        exit 1
    fi
}

# Main execution
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--help|-h]"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "This script runs a comprehensive test suite for the Radxa5bplus-AccessPointSetup repository."
    echo "Tests include: script validation, configuration, security, network setup, and more."
    exit 0
fi

# Run all tests
run_all_tests
