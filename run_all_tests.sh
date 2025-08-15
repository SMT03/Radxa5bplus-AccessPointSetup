#!/bin/bash

# Master Test Runner for Radxa5bplus-AccessPointSetup
# Orchestrates all test suites and provides comprehensive testing overview

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test suite paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RUNNER="$SCRIPT_DIR/test_runner.sh"
UNIT_TESTS="$SCRIPT_DIR/unit_tests.sh"
CONFIG_VALIDATION="$SCRIPT_DIR/config_validation.sh"

# Test results
MASTER_LOG="/tmp/radxa_master_test_results.log"
OVERALL_RESULTS=()

# Function to print colored output
print_header() {
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}======================================${NC}"
}

print_status() {
    echo -e "${BLUE}[MASTER]${NC} $1" | tee -a "$MASTER_LOG"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$MASTER_LOG"
}

print_failure() {
    echo -e "${RED}[FAILURE]${NC} $1" | tee -a "$MASTER_LOG"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$MASTER_LOG"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$MASTER_LOG"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking test prerequisites..."
    
    local missing_files=()
    
    # Check if main script exists
    if [ ! -f "$SCRIPT_DIR/radxa_ap_setup.sh" ]; then
        missing_files+=("radxa_ap_setup.sh")
    fi
    
    # Check if README exists
    if [ ! -f "$SCRIPT_DIR/README.md" ]; then
        missing_files+=("README.md")
    fi
    
    # Check if test scripts exist
    if [ ! -f "$TEST_RUNNER" ]; then
        missing_files+=("test_runner.sh")
    fi
    
    if [ ! -f "$UNIT_TESTS" ]; then
        missing_files+=("unit_tests.sh")
    fi
    
    if [ ! -f "$CONFIG_VALIDATION" ]; then
        missing_files+=("config_validation.sh")
    fi
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_failure "Missing required files: ${missing_files[*]}"
        print_failure "Please ensure all test files are present in: $SCRIPT_DIR"
        return 1
    fi
    
    print_success "All prerequisites met"
    return 0
}

# Function to make test scripts executable
make_executable() {
    print_status "Making test scripts executable..."
    
    chmod +x "$TEST_RUNNER" 2>/dev/null || print_warning "Could not make test_runner.sh executable"
    chmod +x "$UNIT_TESTS" 2>/dev/null || print_warning "Could not make unit_tests.sh executable"
    chmod +x "$CONFIG_VALIDATION" 2>/dev/null || print_warning "Could not make config_validation.sh executable"
    
    print_success "Test scripts made executable"
}

# Function to run comprehensive test suite
run_comprehensive_tests() {
    print_status "Running comprehensive test suite..."
    
    local exit_code=0
    
    # Run main test runner
    print_header "Running Main Test Suite"
    if bash "$TEST_RUNNER"; then
        print_success "Main test suite completed successfully"
        OVERALL_RESULTS+=("Main Test Suite: PASS")
    else
        print_failure "Main test suite failed"
        OVERALL_RESULTS+=("Main Test Suite: FAIL")
        exit_code=1
    fi
    
    echo ""
    
    # Run unit tests
    print_header "Running Unit Tests"
    if bash "$UNIT_TESTS"; then
        print_success "Unit tests completed successfully"
        OVERALL_RESULTS+=("Unit Tests: PASS")
    else
        print_failure "Unit tests failed"
        OVERALL_RESULTS+=("Unit Tests: FAIL")
        exit_code=1
    fi
    
    echo ""
    
    # Run configuration validation
    print_header "Running Configuration Validation"
    if bash "$CONFIG_VALIDATION"; then
        print_success "Configuration validation completed successfully"
        OVERALL_RESULTS+=("Configuration Validation: PASS")
    else
        print_failure "Configuration validation failed"
        OVERALL_RESULTS+=("Configuration Validation: FAIL")
        exit_code=1
    fi
    
    return $exit_code
}

# Function to run individual test suite
run_individual_test() {
    local test_name="$1"
    local test_script="$2"
    
    print_header "Running $test_name"
    
    if bash "$test_script"; then
        print_success "$test_name completed successfully"
        OVERALL_RESULTS+=("$test_name: PASS")
        return 0
    else
        print_failure "$test_name failed"
        OVERALL_RESULTS+=("$test_name: FAIL")
        return 1
    fi
}

# Function to show test summary
show_test_summary() {
    print_header "Test Summary"
    
    local total_tests=${#OVERALL_RESULTS[@]}
    local passed_tests=0
    local failed_tests=0
    
    for result in "${OVERALL_RESULTS[@]}"; do
        if [[ "$result" == *": PASS" ]]; then
            ((passed_tests++))
            print_success "$result"
        else
            ((failed_tests++))
            print_failure "$result"
        fi
    done
    
    echo ""
    print_info "Total Test Suites: $total_tests"
    print_info "Passed: $passed_tests"
    print_info "Failed: $failed_tests"
    
    if [ $failed_tests -eq 0 ]; then
        print_success "🎉 All test suites passed! 🎉"
        return 0
    else
        print_failure "❌ Some test suites failed. Check logs for details."
        return 1
    fi
}

# Function to show log file locations
show_log_locations() {
    print_header "Test Log Locations"
    
    local logs=(
        "Master Test Log: $MASTER_LOG"
        "Main Test Suite: /tmp/radxa_test_results.log"
        "Unit Tests: /tmp/radxa_unit_test_results.log"
        "Configuration Tests: /tmp/radxa_config_test_results.log"
    )
    
    for log in "${logs[@]}"; do
        print_info "$log"
    done
    
    echo ""
    print_info "Use 'tail -f <log_file>' to monitor test progress in real-time"
}

# Function to show help
show_help() {
    cat << EOF
Master Test Runner for Radxa5bplus-AccessPointSetup

Usage: $0 [OPTIONS]

OPTIONS:
    --all, -a           Run all test suites (default)
    --main, -m          Run only main test suite
    --unit, -u          Run only unit tests
    --config, -c        Run only configuration validation
    --help, -h          Show this help message

DESCRIPTION:
    This script orchestrates comprehensive testing of the Radxa5bplus-AccessPointSetup
    repository. It runs multiple test suites to validate:
    
    - Script functionality and syntax
    - Configuration file generation
    - Security settings
    - Network configuration
    - Hardware compatibility
    - Error handling and logging
    
    Test results are logged to /tmp/radxa_*_test_results.log files.

EXAMPLES:
    $0                    # Run all tests
    $0 --main            # Run only main test suite
    $0 --unit            # Run only unit tests
    $0 --config          # Run only configuration validation

EOF
}

# Function to run specific test suite
run_specific_test() {
    case "$1" in
        --main|-m)
            run_individual_test "Main Test Suite" "$TEST_RUNNER"
            ;;
        --unit|-u)
            run_individual_test "Unit Tests" "$UNIT_TESTS"
            ;;
        --config|-c)
            run_individual_test "Configuration Validation" "$CONFIG_VALIDATION"
            ;;
        *)
            print_failure "Unknown test suite: $1"
            return 1
            ;;
    esac
}

# Function to cleanup test artifacts
cleanup_test_artifacts() {
    print_status "Cleaning up test artifacts..."
    
    # Remove temporary test directories
    rm -rf /tmp/radxa_test_mock 2>/dev/null || true
    rm -rf /tmp/radxa_config_test 2>/dev/null || true
    
    print_success "Test artifacts cleaned up"
}

# Main execution
main() {
    # Clear master log
    > "$MASTER_LOG"
    
    print_header "Radxa5bplus-AccessPointSetup Master Test Runner"
    print_info "Starting comprehensive testing at $(date)"
    print_info "Working directory: $SCRIPT_DIR"
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        print_failure "Prerequisites check failed. Exiting."
        exit 1
    fi
    
    # Make test scripts executable
    make_executable
    
    # Parse command line arguments
    case "${1:---all}" in
        --all|-a)
            print_status "Running all test suites..."
            if run_comprehensive_tests; then
                print_success "All test suites completed"
            else
                print_failure "Some test suites failed"
            fi
            ;;
        --main|-m|--unit|-u|--config|-c)
            print_status "Running specific test suite..."
            run_specific_test "$1"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_failure "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    echo ""
    
    # Show test summary
    show_test_summary
    summary_exit_code=$?
    
    echo ""
    
    # Show log file locations
    show_log_locations
    
    echo ""
    
    # Cleanup
    cleanup_test_artifacts
    
    # Exit with appropriate code
    exit $summary_exit_code
}

# Run main function
main "$@"
