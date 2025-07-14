#!/bin/bash

# Run tests once and save output
echo "Running tests once to capture output..."
npm test 2>&1 > /tmp/test_output.txt

echo "# Test Gap Analysis"
echo
echo "## The Missing Tests (107-111)"
echo

# Extract executed tests
grep "^ok" /tmp/test_output.txt | awk '{$1=$2=""; print $0}' | sed 's/^ *//' > /tmp/executed_names.txt

# Show tests around the gap
echo "### Tests 105-115 in execution order:"
grep -E "^ok (10[5-9]|11[0-5])" /tmp/test_output.txt

echo
echo "## File Analysis"
echo

# Check each file to see which tests it contributes
for file in tests/unit/test_multihost.bats tests/unit/test_profile_io.bats tests/unit/test_profile_management.bats; do
    echo "### $file"
    echo
    grep "@test" "$file" | sed 's/@test "\(.*\)" {/\1/' | while read -r test_name; do
        # Check if this test was executed
        if grep -qF "$test_name" /tmp/executed_names.txt; then
            # Find its number
            num=$(grep -F "$test_name" /tmp/test_output.txt | awk '{print $2}')
            echo "✓ '$test_name' -> Test #$num"
        else
            echo "✗ '$test_name' -> NOT EXECUTED"
        fi
    done
    echo
done

echo "## Summary"
echo
echo "Total tests that should run: $(find tests -name "*.bats" -exec grep -c "^@test" {} \; | awk '{sum += $1} END {print sum}')"
echo "Total tests BATS found: $(bats --count -r tests)"
echo "Total tests executed: $(grep -c "^ok" /tmp/test_output.txt)"

# Check for the specific profile_io tests
echo
echo "## Specific Investigation: test_profile_io.bats"
echo
echo "This file should contain tests 107-111 based on the numbering gap."
echo
echo "Tests in this file:"
nl -nln tests/unit/test_profile_io.bats | grep "@test"