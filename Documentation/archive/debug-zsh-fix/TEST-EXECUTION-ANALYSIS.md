# Complete Test List with Execution Numbers

Generated: Mon Jul 14 12:11:14 PDT 2025

## Test Execution Order

1. ghs guard shows usage and help
2. ghs guard test validates successfully with correct setup
3. ghs guard test detects account mismatch
4. ghs guard test handles missing project assignment
5. ghs guard test detects incomplete git config
6. ghs guard test handles unauthenticated GitHub CLI
7. ghs guard status shows installation state
8. guard commands require git repository
9. guard handles corrupted git repository
10. guard handles malformed project configuration
11. guard handles missing project configuration file
12. guard handles gh API failures gracefully
13. guard handles git config with special characters
14. ghs guard install creates working hook
15. ghs guard install handles already installed hooks
16. ghs guard install backs up existing hooks
17. ghs guard uninstall removes hooks
18. ghs guard uninstall handles no hooks to remove
19. guard hook validates successfully with correct setup
20. guard hook blocks commit with account mismatch
21. guard hook respects skip flag
22. guard hook executes within performance requirements
23. guard hook actually prevents commit with wrong account
24. guard hook allows commit with correct account
25. guard hook respects GHS_SKIP_HOOK environment variable
26. complete workflow with multiple hosts
27. SSH testing respects host configuration
28. project assignment with enterprise users
29. different default emails for different hosts
30. host validation prevents common mistakes
31. switching between users on different hosts
32. full workflow: add, show, edit, switch
33. pre-flight check in switch command
34. status command shows assigned user
35. status shows user without profile
36. show command detects git config mismatch for active user
37. edit suggests reapply for active user
38. dispatcher handles new commands
39. help shows new commands
40. multiple SSH key suggestions prioritize username matches
41. email typo detection skips bot accounts
42. complete first-time user flow with current
43. invalid commands don't corrupt terminal
44. ghs assign stores user for project and auto-selects
45. ghs switch changes git config to selected user
46. add current user when authenticated
47. add current fails when not authenticated
48. add_user creates user without SSH key
49. add_user creates user with SSH key
50. add_user continues with warning when SSH key missing
51. add_user fixes SSH key permissions
52. add_user continues with warning for invalid SSH key format
53. add_user rejects invalid username format
54. add_user handles duplicate usernames
55. add_user shows usage when no username provided
56. add_user rejects unknown options
57. remove_user removes user by name
58. remove_user removes user by number
59. remove_user handles non-existent user
60. remove_user handles invalid user ID when no users exist
61. remove_user shows usage when no user provided
62. list_users shows empty state
63. list_users shows users with numbers
64. list_users shows SSH status for working keys
65. get_user_by_id returns correct username
66. get_user_by_id handles invalid ID
67. get_user_by_id handles non-existent ID when no users
68. add_user creates profile with git config
69. validate_ssh_key accepts valid ed25519 key
70. validate_ssh_key accepts valid RSA key
71. validate_ssh_key rejects missing file
72. validate_ssh_key rejects invalid format
73. validate_ssh_key fixes permissions
74. validate_ssh_key warns about wrong permissions without fixing
75. validate_ssh_key handles empty path
76. validate_ssh_key prevents directory traversal
77. apply_ssh_config sets git SSH command
78. apply_ssh_config removes SSH config when empty path
79. apply_ssh_config requires git repository for local scope
80. apply_ssh_config works globally outside repository
81. apply_ssh_config handles invalid scope
82. create_user_profile stores SSH key path
83. create_user_profile works without SSH key
84. apply_user_profile applies SSH configuration
85. apply_user_profile handles missing SSH key gracefully
86. SSH key permissions are fixed automatically during profile creation
87. SSH functions handle tilde in paths
88. validate_host accepts valid formats
89. validate_host rejects invalid formats
90. validate_host rejects empty host
91. validate_host rejects overly long host
92. profile_get handles format with custom host
93. profile_create creates format with host
94. profile_create defaults to github.com when host not specified
95. profile_create generates correct default email for enterprise
96. profile_create generates correct default email for github.com
97. cmd_add accepts --host parameter
98. cmd_add validates host format
99. cmd_add shows host when not github.com
100. cmd_edit can update host
101. cmd_show displays host for non-github.com
102. cmd_show doesn't display host for github.com
103. cmd_users shows host for non-github.com
104. cmd_switch shows host info for enterprise
105. test_ssh_auth uses custom host
106. cmd_test_ssh shows host for enterprise users
112. write_profile_entry creates valid profile format
113. write_profile_entry creates valid profile with SSH key
114. profile_create stores user data correctly
115. profile_get retrieves format correctly
116. profile_get handles missing SSH key
117. profile_get handles missing profile gracefully
118. profile_get handles invalid format gracefully
119. multiple profiles can coexist
120. profile_create replaces existing profile
121. profile_remove deletes user profile
122. ghs show displays profile information
123. ghs show works with user ID
124. ghs show detects missing SSH key
125. ghs show finds alternative SSH keys
126. ghs show detects permission issues
127. ghs show detects email typo
128. ghs show handles missing profile
129. ghs show handles non-existent user
130. ghs edit updates email
131. ghs edit updates name
132. ghs edit removes SSH key with none
133. ghs edit expands tilde in paths
134. ghs edit rejects GPG options
135. ghs edit with no changes shows current
136. ghs edit validates email format
137. ghs edit validates SSH key exists
138. ghs edit creates profile if missing
139. ghs edit handles multiple changes
140. ghs show completes within reasonable time
141. ghs edit completes within reasonable time
142. find_ssh_key_alternatives finds keys for user
143. profile_has_issues detects SSH key problems
144. profile_has_issues detects email typos
145. profile_has_issues returns 1 for clean profile
146. cmd_edit_usage shows complete help
147. profile_get_field extracts fields correctly
148. Script can be sourced without executing
149. Script can be executed directly with arguments
150. Script execution with no arguments doesn't crash
151. Script sources correctly in zsh
152. Function export works after sourcing
153. Script doesn't auto-execute on source with BASH_SOURCE check
154. Multiple source operations don't cause issues
155. Script respects GHS_STRICT_MODE environment variable
156. Script handles being sourced from different directories
157. test_ssh_auth handles permission denied
158. test_ssh_auth handles network issues
159. test_ssh_auth handles successful authentication
160. cmd_test_ssh shows error when no user specified and no current user
161. cmd_test_ssh tests current user when no user specified
162. cmd_test_ssh shows error for non-existent user
163. cmd_test_ssh shows info for user with no SSH key
164. cmd_test_ssh shows error for missing SSH key file
165. cmd_test_ssh quiet mode returns only exit codes
166. cmd_test_ssh shows success message for working key
167. cmd_test_ssh shows auth failure message
168. cmd_test_ssh shows network issue message
169. cmd_add tests SSH key when provided
170. SSH testing integration is working
171. zsh: local path variable doesn't break PATH
172. zsh: ghs assign works (integration test)
173. zsh: multiple sources work
174. zsh: critical commands remain available in functions

## Test Definitions by File

### tests/guard_hooks/test_guard_commands.bats

- Line 20: ghs guard shows usage and help
- Line 28: ghs guard test validates successfully with correct setup
- Line 40: ghs guard test detects account mismatch
- Line 52: ghs guard test handles missing project assignment
- Line 63: ghs guard test detects incomplete git config
- Line 72: ghs guard test handles unauthenticated GitHub CLI
- Line 80: ghs guard status shows installation state
- Line 87: guard commands require git repository

### tests/guard_hooks/test_guard_error_scenarios.bats

- Line 18: guard handles corrupted git repository
- Line 26: guard handles malformed project configuration
- Line 40: guard handles missing project configuration file
- Line 53: guard handles gh API failures gracefully
- Line 78: guard handles git config with special characters

### tests/guard_hooks/test_hook_operations.bats

- Line 23: ghs guard install creates working hook
- Line 34: ghs guard install handles already installed hooks
- Line 44: ghs guard install backs up existing hooks
- Line 56: ghs guard uninstall removes hooks
- Line 67: ghs guard uninstall handles no hooks to remove
- Line 75: guard hook validates successfully with correct setup
- Line 93: guard hook blocks commit with account mismatch
- Line 104: guard hook respects skip flag
- Line 114: guard hook executes within performance requirements

### tests/integration/test_guard_hook_real.bats

- Line 26: guard hook actually prevents commit with wrong account
- Line 44: guard hook allows commit with correct account
- Line 65: guard hook respects GHS_SKIP_HOOK environment variable

### tests/integration/test_multihost_workflow.bats

- Line 16: complete workflow with multiple hosts
- Line 71: SSH testing respects host configuration
- Line 107: project assignment with enterprise users
- Line 139: different default emails for different hosts
- Line 157: host validation prevents common mistakes
- Line 174: switching between users on different hosts

### tests/integration/test_profile_workflow.bats

- Line 17: full workflow: add, show, edit, switch
- Line 41: pre-flight check in switch command
- Line 57: status command shows assigned user
- Line 78: status shows user without profile
- Line 98: show command detects git config mismatch for active user
- Line 125: edit suggests reapply for active user
- Line 143: dispatcher handles new commands
- Line 160: help shows new commands
- Line 170: multiple SSH key suggestions prioritize username matches
- Line 188: email typo detection skips bot accounts
- Line 199: complete first-time user flow with current
- Line 245: invalid commands don't corrupt terminal

### tests/integration/test_project_assignment.bats

- Line 34: ghs assign stores user for project and auto-selects

### tests/integration/test_switch_command.bats

- Line 35: ghs switch changes git config to selected user

### tests/integration/test_user_management.bats

- Line 23: add current user when authenticated
- Line 46: add current fails when not authenticated
- Line 66: add_user creates user without SSH key
- Line 78: add_user creates user with SSH key
- Line 104: add_user continues with warning when SSH key missing
- Line 115: add_user fixes SSH key permissions
- Line 139: add_user continues with warning for invalid SSH key format
- Line 152: add_user rejects invalid username format
- Line 161: add_user handles duplicate usernames
- Line 173: add_user shows usage when no username provided
- Line 183: add_user rejects unknown options
- Line 193: remove_user removes user by name
- Line 206: remove_user removes user by number
- Line 219: remove_user handles non-existent user
- Line 228: remove_user handles invalid user ID when no users exist
- Line 237: remove_user shows usage when no user provided
- Line 247: list_users shows empty state
- Line 257: list_users shows users with numbers
- Line 271: list_users shows SSH status for working keys
- Line 308: get_user_by_id returns correct username
- Line 320: get_user_by_id handles invalid ID
- Line 329: get_user_by_id handles non-existent ID when no users
- Line 339: add_user creates profile with git config

### tests/service/test_ssh_integration.bats

- Line 23: validate_ssh_key accepts valid ed25519 key
- Line 31: validate_ssh_key accepts valid RSA key
- Line 39: validate_ssh_key rejects missing file
- Line 48: validate_ssh_key rejects invalid format
- Line 57: validate_ssh_key fixes permissions
- Line 70: validate_ssh_key warns about wrong permissions without fixing
- Line 82: validate_ssh_key handles empty path
- Line 90: validate_ssh_key prevents directory traversal
- Line 100: apply_ssh_config sets git SSH command
- Line 115: apply_ssh_config removes SSH config when empty path
- Line 129: apply_ssh_config requires git repository for local scope
- Line 141: apply_ssh_config works globally outside repository
- Line 153: apply_ssh_config handles invalid scope
- Line 163: create_user_profile stores SSH key path
- Line 172: create_user_profile works without SSH key
- Line 181: apply_user_profile applies SSH configuration
- Line 198: apply_user_profile handles missing SSH key gracefully
- Line 215: SSH key permissions are fixed automatically during profile creation
- Line 231: SSH functions handle tilde in paths

### tests/unit/test_multihost.bats

- Line 23: validate_host accepts valid formats
- Line 34: validate_host rejects invalid formats
- Line 48: validate_host rejects empty host
- Line 54: validate_host rejects overly long host
- Line 71: profile_get handles format with custom host
- Line 80: profile_create creates format with host
- Line 89: profile_create defaults to github.com when host not specified
- Line 98: profile_create generates correct default email for enterprise
- Line 107: profile_create generates correct default email for github.com
- Line 120: cmd_add accepts --host parameter
- Line 130: cmd_add validates host format
- Line 136: cmd_add shows host when not github.com
- Line 142: cmd_edit can update host
- Line 155: cmd_show displays host for non-github.com
- Line 165: cmd_show doesn't display host for github.com
- Line 176: cmd_users shows host for non-github.com
- Line 189: cmd_switch shows host info for enterprise
- Line 215: test_ssh_auth uses custom host
- Line 231: cmd_test_ssh shows host for enterprise users

### tests/unit/test_performance.bats

- Line 47: ghs users completes within reasonable time
- Line 52: ghs switch completes within 100ms
- Line 62: ghs add completes within 100ms
- Line 67: ghs status completes within 250ms
- Line 72: ghs guard test completes within reasonable time

### tests/unit/test_profile_io.bats

- Line 18: write_profile_entry creates valid profile format
- Line 36: write_profile_entry creates valid profile with SSH key
- Line 54: profile_create stores user data correctly
- Line 66: profile_get retrieves format correctly
- Line 81: profile_get handles missing SSH key
- Line 95: profile_get handles missing profile gracefully
- Line 103: profile_get handles invalid format gracefully
- Line 116: multiple profiles can coexist
- Line 132: profile_create replaces existing profile
- Line 151: profile_remove deletes user profile

### tests/unit/test_profile_management.bats

- Line 31: ghs show displays profile information
- Line 47: ghs show works with user ID
- Line 56: ghs show detects missing SSH key
- Line 66: ghs show finds alternative SSH keys
- Line 82: ghs show detects permission issues
- Line 95: ghs show detects email typo
- Line 105: ghs show handles missing profile
- Line 114: ghs show handles non-existent user
- Line 121: ghs edit updates email
- Line 133: ghs edit updates name
- Line 144: ghs edit removes SSH key with none
- Line 155: ghs edit expands tilde in paths
- Line 175: ghs edit rejects GPG options
- Line 183: ghs edit with no changes shows current
- Line 193: ghs edit validates email format
- Line 202: ghs edit validates SSH key exists
- Line 211: ghs edit creates profile if missing
- Line 214:     run ghs edit alice --email alice@test.com
- Line 220: ghs edit handles multiple changes
- Line 233: ghs show completes within reasonable time
- Line 243: ghs edit completes within reasonable time
- Line 255: find_ssh_key_alternatives finds keys for user
- Line 274: profile_has_issues detects SSH key problems
- Line 285: profile_has_issues detects email typos
- Line 295: profile_has_issues returns 1 for clean profile
- Line 305: cmd_edit_usage shows complete help
- Line 318: profile_get_field extracts fields correctly

### tests/unit/test_script_sourcing.bats

- Line 11: Script can be sourced without executing
- Line 20: Script can be executed directly with arguments
- Line 28: Script execution with no arguments doesn't crash
- Line 37: Script sources correctly in zsh
- Line 46: Function export works after sourcing
- Line 53: Script doesn't auto-execute on source with BASH_SOURCE check
- Line 72: Multiple source operations don't cause issues
- Line 84: Script respects GHS_STRICT_MODE environment variable
- Line 96: Script handles being sourced from different directories

### tests/unit/test_ssh_testing.bats

- Line 23: test_ssh_auth handles permission denied
- Line 43: test_ssh_auth handles network issues
- Line 63: test_ssh_auth handles successful authentication
- Line 88: cmd_test_ssh shows error when no user specified and no current user
- Line 94: cmd_test_ssh tests current user when no user specified
- Line 116: cmd_test_ssh shows error for non-existent user
- Line 122: cmd_test_ssh shows info for user with no SSH key
- Line 132: cmd_test_ssh shows error for missing SSH key file
- Line 144: cmd_test_ssh quiet mode returns only exit codes
- Line 158: cmd_test_ssh shows success message for working key
- Line 188: cmd_test_ssh shows auth failure message
- Line 216: cmd_test_ssh shows network issue message
- Line 247: cmd_add tests SSH key when provided
- Line 276: SSH testing integration is working

### tests/unit/test_zsh_compatibility.bats

- Line 15: zsh: local path variable doesn't break PATH
- Line 30: zsh: ghs assign works (integration test)
- Line 40: zsh: multiple sources work
- Line 52: zsh: critical commands remain available in functions


## Summary

- Total test files: 17
- Total tests defined: 175
- Total tests executed: 169
- BATS expected count: 174

## Gaps in Numbering

- Gap: Test 106 jumps to test 112 (missing 107-111)

## Missing Tests Analysis

Tests that are defined but may not be executing properly:

