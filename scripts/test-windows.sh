#!/bin/bash
# Simple Windows testing script for debugging CI issues

echo "=== Windows Test Script ==="
echo "Date: $(date)"
echo ""

# Environment detection
echo "=== Environment Detection ==="
echo "OSTYPE: ${OSTYPE:-not set}"
echo "MSYSTEM: ${MSYSTEM:-not set}"
echo "OS: ${OS:-not set}"
echo "Path to C drive: $(ls -la /c 2>&1 | head -1)"
echo "Shell: $SHELL"
echo "Bash version: $BASH_VERSION"
echo ""

# Test basic commands
echo "=== Testing Basic Commands ==="
echo -n "which: "
which which || echo "not found"
echo -n "date: "
date --version 2>&1 | head -1 || echo "failed"
echo -n "python: "
python --version 2>&1 || echo "not found"
echo -n "python3: "
python3 --version 2>&1 || echo "not found"
echo ""

# Test gh-switcher sourcing
echo "=== Testing gh-switcher.sh ==="
if [[ -f "gh-switcher.sh" ]]; then
    echo "Found gh-switcher.sh"
    echo "File size: $(ls -la gh-switcher.sh | awk '{print $5}') bytes"
    echo "First line: $(head -1 gh-switcher.sh)"
    
    # Try to source it
    echo ""
    echo "Attempting to source..."
    (
        export GHS_STRICT_MODE="false"
        if source ./gh-switcher.sh 2>&1; then
            echo "✅ Sourced successfully"
            
            # Check if functions are available
            if type ghs >/dev/null 2>&1; then
                echo "✅ ghs function available"
            else
                echo "❌ ghs function not found"
            fi
            
            if type cmd_users >/dev/null 2>&1; then
                echo "✅ cmd_users function available"
            else
                echo "❌ cmd_users function not found"
            fi
        else
            echo "❌ Failed to source"
        fi
    )
else
    echo "❌ gh-switcher.sh not found"
fi
echo ""

# Test BATS
echo "=== Testing BATS ==="
for bats_path in "bats" "/usr/local/bin/bats" "./node_modules/.bin/bats"; do
    if [[ -f "$bats_path" ]] || which "$bats_path" >/dev/null 2>&1; then
        echo "Found BATS at: $bats_path"
        $bats_path --version 2>&1 || echo "Failed to get version"
        break
    fi
done
echo ""

# Test a simple BATS test
echo "=== Running Simple BATS Test ==="
cat > test-simple.bats << 'EOF'
#!/usr/bin/env bats

@test "simple test" {
    [ 1 -eq 1 ]
}

@test "echo test" {
    result="$(echo "hello")"
    [ "$result" = "hello" ]
}
EOF

if which bats >/dev/null 2>&1; then
    bats test-simple.bats || echo "BATS test failed"
else
    echo "BATS not available"
fi

rm -f test-simple.bats

echo ""
echo "=== Test Complete ==="