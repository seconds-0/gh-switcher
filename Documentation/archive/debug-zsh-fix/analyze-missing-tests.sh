#!/bin/bash

echo "# Detailed Test Gap Analysis"
echo
echo "## The Gap: Tests 107-111"
echo

# First, let's see what test 106 and 112 are
echo "### What are tests 106 and 112?"
echo
npm test 2>&1 | grep -E "^ok (106|112)" | while read -r line; do
    echo "- $line"
done

echo
echo "### Finding the source files"
echo

# Find which file has test 106
test_106=$(npm test 2>&1 | grep "^ok 106" | cut -d' ' -f3-)
echo "Test 106: '$test_106'"
echo "Found in:"
find tests -name "*.bats" -exec grep -l "$test_106" {} \;

echo

# Find which file has test 112  
test_112=$(npm test 2>&1 | grep "^ok 112" | cut -d' ' -f3-)
echo "Test 112: '$test_112'"
echo "Found in:"
find tests -name "*.bats" -exec grep -l "$test_112" {} \;

echo
echo "### Checking test order between files"
echo

# Let's trace which tests come from which files
echo "Creating detailed execution trace..."

# Run tests with more detail
npm test 2>&1 | grep -E "^ok|\.bats" > /tmp/detailed_trace.txt

echo
echo "### All tests from test_multihost.bats"
echo
grep -n "@test" tests/unit/test_multihost.bats | while IFS=: read -r line_num test_def; do
    test_name=$(echo "$test_def" | sed 's/@test "\(.*\)" {/\1/')
    # Check if this test appears in execution
    if npm test 2>&1 | grep -q "$test_name"; then
        exec_num=$(npm test 2>&1 | grep "$test_name" | awk '{print $2}')
        echo "- Line $line_num: '$test_name' -> Executes as test $exec_num"
    else
        echo "- Line $line_num: '$test_name' -> NOT FOUND IN EXECUTION"
    fi
done

echo
echo "### All tests from test_profile_io.bats"
echo
grep -n "@test" tests/unit/test_profile_io.bats | while IFS=: read -r line_num test_def; do
    test_name=$(echo "$test_def" | sed 's/@test "\(.*\)" {/\1/')
    # Check if this test appears in execution
    if npm test 2>&1 | grep -q "$test_name"; then
        exec_num=$(npm test 2>&1 | grep "$test_name" | awk '{print $2}')
        echo "- Line $line_num: '$test_name' -> Executes as test $exec_num"
    else
        echo "- Line $line_num: '$test_name' -> NOT FOUND IN EXECUTION"
    fi
done