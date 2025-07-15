Running tests once to capture output...
# Test Gap Analysis

## The Missing Tests (107-111)

### Tests 105-115 in execution order:
ok 105 test_ssh_auth uses custom host
ok 106 cmd_test_ssh shows host for enterprise users
ok 112 write_profile_entry creates valid profile format
ok 113 write_profile_entry creates valid profile with SSH key
ok 114 profile_create stores user data correctly
ok 115 profile_get retrieves format correctly

## File Analysis

### tests/unit/test_multihost.bats

✓ 'validate_host accepts valid formats' -> Test #88
✓ 'validate_host rejects invalid formats' -> Test #89
✓ 'validate_host rejects empty host' -> Test #90
✓ 'validate_host rejects overly long host' -> Test #91
✓ 'profile_get handles format with custom host' -> Test #92
✓ 'profile_create creates format with host' -> Test #93
✓ 'profile_create defaults to github.com when host not specified' -> Test #94
✓ 'profile_create generates correct default email for enterprise' -> Test #95
✓ 'profile_create generates correct default email for github.com' -> Test #96
✓ 'cmd_add accepts --host parameter' -> Test #97
✓ 'cmd_add validates host format' -> Test #98
✓ 'cmd_add shows host when not github.com' -> Test #99
✓ 'cmd_edit can update host' -> Test #100
✓ 'cmd_show displays host for non-github.com' -> Test #101
✓ 'cmd_show doesn't display host for github.com' -> Test #102
✓ 'cmd_users shows host for non-github.com' -> Test #103
✓ 'cmd_switch shows host info for enterprise' -> Test #104
✓ 'test_ssh_auth uses custom host' -> Test #105
✓ 'cmd_test_ssh shows host for enterprise users' -> Test #106

### tests/unit/test_profile_io.bats

✓ 'write_profile_entry creates valid profile format' -> Test #112
✓ 'write_profile_entry creates valid profile with SSH key' -> Test #113
✓ 'profile_create stores user data correctly' -> Test #114
✓ 'profile_get retrieves format correctly' -> Test #115
✓ 'profile_get handles missing SSH key' -> Test #116
✓ 'profile_get handles missing profile gracefully' -> Test #117
✓ 'profile_get handles invalid format gracefully' -> Test #118
✓ 'multiple profiles can coexist' -> Test #119
✓ 'profile_create replaces existing profile' -> Test #120
✓ 'profile_remove deletes user profile' -> Test #121

### tests/unit/test_profile_management.bats

✓ 'ghs show displays profile information' -> Test #122
✓ 'ghs show works with user ID' -> Test #123
✓ 'ghs show detects missing SSH key' -> Test #124
✓ 'ghs show finds alternative SSH keys' -> Test #125
✓ 'ghs show detects permission issues' -> Test #126
✓ 'ghs show detects email typo' -> Test #127
✓ 'ghs show handles missing profile' -> Test #128
✓ 'ghs show handles non-existent user' -> Test #129
✓ 'ghs edit updates email' -> Test #130
✓ 'ghs edit updates name' -> Test #131
✓ 'ghs edit removes SSH key with none' -> Test #132
✓ 'ghs edit expands tilde in paths' -> Test #133
✓ 'ghs edit rejects GPG options' -> Test #134
✓ 'ghs edit with no changes shows current' -> Test #135
✓ 'ghs edit validates email format' -> Test #136
✓ 'ghs edit validates SSH key exists' -> Test #137
✓ 'ghs edit creates profile if missing' -> Test #138
✗ 'run ghs edit alice --email alice@test.com' -> NOT EXECUTED
✓ 'ghs edit handles multiple changes' -> Test #139
✓ 'ghs show completes within reasonable time' -> Test #140
✓ 'ghs edit completes within reasonable time' -> Test #141
✓ 'find_ssh_key_alternatives finds keys for user' -> Test #142
✓ 'profile_has_issues detects SSH key problems' -> Test #143
✓ 'profile_has_issues detects email typos' -> Test #144
✓ 'profile_has_issues returns 1 for clean profile' -> Test #145
✓ 'cmd_edit_usage shows complete help' -> Test #146
✓ 'profile_get_field extracts fields correctly' -> Test #147

## Summary

Total tests that should run: 174
Total tests BATS found: 174
Total tests executed: 169

## Specific Investigation: test_profile_io.bats

This file should contain tests 107-111 based on the numbering gap.

Tests in this file:
13    	@test "write_profile_entry creates valid profile format" {
30    	@test "write_profile_entry creates valid profile with SSH key" {
47    	@test "profile_create stores user data correctly" {
58    	@test "profile_get retrieves format correctly" {
72    	@test "profile_get handles missing SSH key" {
85    	@test "profile_get handles missing profile gracefully" {
92    	@test "profile_get handles invalid format gracefully" {
104   	@test "multiple profiles can coexist" {
119   	@test "profile_create replaces existing profile" {
137   	@test "profile_remove deletes user profile" {
