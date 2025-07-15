#!/bin/bash

# Generate a complete list of all tests with their execution numbers

echo "# Complete Test List with Execution Numbers"
echo
echo "Generated: $(date)"
echo
echo "## Test Execution Order"
echo

# Run tests and capture output with numbers
npm test 2>&1 | grep "^ok" | while read -r line; do
    # Extract test number and name
    number=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | cut -d' ' -f3-)
    echo "$number. $name"
done > /tmp/executed_tests.txt

# Show executed tests
cat /tmp/executed_tests.txt

echo
echo "## Test Definitions by File"
echo

# Find all test files and list their tests
test_count=0
find tests -name "*.bats" | sort | while read -r file; do
    echo "### $file"
    echo
    grep -n "@test" "$file" | while IFS=: read -r line_num test_def; do
        # Extract test name
        test_name=$(echo "$test_def" | sed 's/@test "\(.*\)" {/\1/')
        ((test_count++))
        echo "- Line $line_num: $test_name"
    done
    echo
done

echo
echo "## Summary"
echo
echo "- Total test files: $(find tests -name "*.bats" | wc -l | tr -d ' ')"
echo "- Total tests defined: $(find tests -name "*.bats" -exec grep -c "@test" {} \; | awk '{sum += $1} END {print sum}')"
echo "- Total tests executed: $(cat /tmp/executed_tests.txt | wc -l | tr -d ' ')"
echo "- BATS expected count: $(npm test 2>&1 | grep "^1\.\." | cut -d. -f3)"

echo
echo "## Gaps in Numbering"
echo

# Find gaps
prev=0
while read -r line; do
    num=$(echo "$line" | cut -d. -f1)
    if [[ $prev -ne 0 && $num -ne $((prev + 1)) ]]; then
        echo "- Gap: Test $prev jumps to test $num (missing $((prev + 1))-$((num - 1)))"
    fi
    prev=$num
done < /tmp/executed_tests.txt

echo
echo "## Missing Tests Analysis"
echo

# Compare defined vs executed
echo "Tests that are defined but may not be executing properly:"
echo

# This is a bit complex - we'll need to match test names between files and execution