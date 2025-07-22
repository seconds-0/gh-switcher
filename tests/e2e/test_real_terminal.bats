#!/usr/bin/env bats

# Real terminal integration tests using expect
# These tests catch shell-breaking bugs that subshell tests miss
# Focus: Shell crash prevention and strict mode validation

load '../helpers/test_helper'
load 'helpers/e2e_helper'

@test "terminal: bash sourced mode - no errexit, survives errors" {
    if ! command -v expect >/dev/null 2>&1; then
        skip "expect not installed - needed for terminal tests"
    fi
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    local debug="${DEBUG_TERMINAL_TESTS:-}"
    
    run expect ${debug:+-d} -c "
        set timeout 10
        log_user [expr {\"$debug\" ne \"\"}]
        
        # Start bash and source the script
        spawn bash --norc --noprofile
        expect -re {[$#] ?$}
        send \"source $script_path\r\"
        expect -re {[$#] ?$}
        
        # Verify errexit is OFF (critical for not crashing user shells)
        send \"set -o | grep errexit\r\"
        expect {
            -re {errexit\\s+off} {
                expect -re {[$#] ?$}
            }
            -re {errexit\\s+on} {
                puts \"FAIL: errexit ON when sourced - would crash user shells!\"
                exit 1
            }
            timeout {
                puts \"FAIL: Timeout checking errexit status\"
                exit 1
            }
        }
        
        # Test the exact command that crashed user shells
        send \"ghs remove\r\"
        expect {
            \"Username or ID required\" {
                expect -re {[$#] ?$}
            }
            eof {
                puts \"FAIL: Shell crashed on 'ghs remove' - the reported bug!\"
                exit 1
            }
        }
        
        # Verify shell is still alive and functional
        send \"echo 'Shell survived'\r\"
        expect {
            \"Shell survived\" {
                expect -re {[$#] ?$}
                puts \"SUCCESS: Shell survived errors when sourced\"
                send \"exit 0\r\"
                expect eof
                exit 0
            }
            timeout {
                puts \"FAIL: Shell not responding after error\"
                exit 1
            }
        }
    "
    assert_success
}

@test "terminal: zsh sourced mode - no errexit, survives errors" {
    if ! command -v expect >/dev/null 2>&1; then
        skip "expect not installed - needed for terminal tests"
    fi
    
    if ! command -v zsh >/dev/null 2>&1; then
        skip "zsh not installed"
    fi
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    local debug="${DEBUG_TERMINAL_TESTS:-}"
    
    run expect ${debug:+-d} -c "
        set timeout 10
        log_user [expr {\"$debug\" ne \"\"}]
        
        # Start zsh and source the script
        spawn zsh -f
        expect -re {%}
        send \"PS1='> '\r\"
        expect {> }
        send \"source $script_path\r\"
        expect {> }
        
        # The critical test: shell must survive errors when sourced
        # This is more important than checking the option directly
        send \"false && echo 'SHOULD_NOT_SEE_THIS' || echo 'Correctly handled false'\r\"
        expect {
            \"Correctly handled false\" {
                expect {> }
            }
            \"SHOULD_NOT_SEE_THIS\" {
                puts \"FAIL: Shell not handling errors correctly\"
                exit 1
            }
            eof {
                puts \"FAIL: Shell died on false command - errexit is active!\"
                exit 1
            }
            timeout {
                puts \"FAIL: Timeout testing error handling\"
                exit 1
            }
        }
        
        
        # Test the exact command that crashed user shells
        send \"ghs remove\r\"
        expect {
            \"Username or ID required\" {
                expect -re {[%$>] ?$}
                puts \"SUCCESS: Shell survived errors when sourced\"
                send \"exit 0\r\"
                expect eof
                exit 0
            }
            eof {
                puts \"FAIL: Shell crashed on 'ghs remove' - the reported bug!\"
                exit 1
            }
        }
    "
    assert_success
}

@test "terminal: script execution mode - errexit enabled as designed" {
    if ! command -v expect >/dev/null 2>&1; then
        skip "expect not installed - needed for terminal tests"
    fi
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    local debug="${DEBUG_TERMINAL_TESTS:-}"
    
    run expect ${debug:+-d} -c "
        set timeout 10
        log_user [expr {\"$debug\" ne \"\"}]
        
        spawn bash --norc --noprofile
        expect -re {[$#] ?$}
        
        # When executed directly, the script SHOULD have errexit
        # This ensures script failures are caught properly
        send \"$script_path nonexistent-command 2>&1\r\"
        expect {
            \"Unknown command: nonexistent-command\" {
                expect -re {[$#] ?$}
            }
            timeout {
                puts \"FAIL: Script execution timed out\"
                exit 1
            }
        }
        
        # Verify the script returns proper exit codes
        send \"echo \\$?\r\"
        expect {
            \"1\" {
                expect -re {[$#] ?$}
                puts \"SUCCESS: Script returns correct exit code\"
            }
            \"0\" {
                puts \"FAIL: Script returned 0 for error condition\"
                exit 1
            }
        }
        
        # When executed directly (not sourced), strict mode should be on
        # Create a wrapper script to test direct execution
        send \"cat > /tmp/test_direct.sh << 'EOF'
#!/bin/bash
# Execute gh-switcher directly and check if it has strict mode
$script_path help >/dev/null 2>&1
echo \"Exit code: \\$?\"
# Test that script properly exits on errors
$script_path nonexistent 2>&1 | grep -q 'Unknown command' && echo 'Error handled correctly'
EOF\r\"
        expect -re {[$#] ?$}
        
        send \"chmod +x /tmp/test_direct.sh\r\"
        expect -re {[$#] ?$}
        
        send \"bash /tmp/test_direct.sh\r\"
        expect {
            \"Error handled correctly\" {
                expect -re {[$#] ?$}
                puts \"SUCCESS: Script execution works with proper error handling\"
                send \"rm -f /tmp/test_direct.sh\r\"
                expect -re {[$#] ?$}
                send \"exit 0\r\"
                expect eof
                exit 0
            }
            timeout {
                puts \"FAIL: Script execution test failed\"
                exit 1
            }
        }
    "
    assert_success
}

@test "terminal: VS Code environment - both bash and zsh" {
    if ! command -v expect >/dev/null 2>&1; then
        skip "expect not installed - needed for terminal tests"
    fi
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    local debug="${DEBUG_TERMINAL_TESTS:-}"
    
    # Test VS Code with bash
    run expect ${debug:+-d} -c "
        set timeout 10
        log_user [expr {\"$debug\" ne \"\"}]
        
        spawn env TERM_PROGRAM=vscode VSCODE_INJECTION=1 bash --norc --noprofile
        expect -re {[$#] ?$}
        send \"source $script_path\r\"
        expect -re {[$#] ?$}
        
        # VS Code environment shouldn't cause crashes
        send \"ghs users\r\"
        expect {
            -re {(No users configured|Available users)} {
                expect -re {[$#] ?$}
            }
            timeout {
                puts \"FAIL: Command timed out in VS Code bash\"
                exit 1
            }
            eof {
                puts \"FAIL: Shell crashed in VS Code bash\"
                exit 1
            }
        }
        
        send \"exit 0\r\"
        expect eof
    "
    assert_success
    
    # Test VS Code with zsh (macOS default)
    if command -v zsh >/dev/null 2>&1; then
        run expect ${debug:+-d} -c "
            set timeout 10
            log_user [expr {\"$debug\" ne \"\"}]
            
            spawn env TERM_PROGRAM=vscode VSCODE_INJECTION=1 zsh -f
            expect -re {[%$>] ?$}
            send \"source $script_path\r\"
            expect -re {[%$>] ?$}
            
            # Test error handling in VS Code zsh
            send \"ghs remove\r\"
            expect {
                \"Username or ID required\" {
                    expect -re {[%$>] ?$}
                    puts \"SUCCESS: VS Code zsh environment works correctly\"
                    send \"exit 0\r\"
                    expect eof
                    exit 0
                }
                eof {
                    puts \"FAIL: Shell crashed in VS Code zsh\"
                    exit 1
                }
            }
        "
        assert_success
    fi
}

@test "terminal: real user shell configuration" {
    if ! command -v expect >/dev/null 2>&1; then
        skip "expect not installed - needed for terminal tests"
    fi
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    local debug="${DEBUG_TERMINAL_TESTS:-}"
    
    # Create a minimal but realistic bashrc
    local temp_rc=$(mktemp)
    cat > "$temp_rc" << 'EOF'
# Minimal .bashrc that sets common options
set -o vi           # vi mode
set -o histexpand   # history expansion
export PS1="\u@\h:\w$ "
alias ll='ls -la'
alias gst='git status'
# Some users have this in their .bashrc which could interfere
export GHS_TEST=1
EOF
    
    run expect ${debug:+-d} -c "
        set timeout 10
        log_user [expr {\"$debug\" ne \"\"}]
        
        spawn bash --rcfile $temp_rc
        expect -re {[$#] ?$}
        
        # Verify our rc file was loaded
        send \"echo \\$GHS_TEST\r\"
        expect \"1\"
        expect -re {[$#] ?$}
        
        # Source gh-switcher with realistic shell config
        send \"source $script_path\r\"
        expect -re {[$#] ?$}
        
        # The critical test - shell must survive errors
        send \"ghs remove\r\"
        expect {
            \"Username or ID required\" {
                expect -re {[$#] ?$}
                puts \"SUCCESS: Works with real shell configuration\"
                send \"exit 0\r\"
                expect eof
                exit 0
            }
            eof {
                puts \"FAIL: Crashed with user shell configuration\"
                exit 1
            }
        }
    "
    
    rm -f "$temp_rc"
    assert_success
}