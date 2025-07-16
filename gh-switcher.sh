#!/bin/bash

# 🎯 Clean GitHub Project Switcher Implementation
# Lightweight, maintainable GitHub account switching following architectural principles
# 
# Design Principles:
# - Functions under 50 lines
# - Single responsibility per function  
# - Clear separation of concerns
# - Simple over complex
#
# Error Message Style Guide:
# - ❌ = Hard errors that stop execution
# - ⚠️  = Warnings that allow continuation
# - ℹ️  = Informational messages
# - 💡 = Helpful tips
# - ✅ = Success confirmations

# Enable strict mode but allow it to be disabled for testing
[[ "${GHS_STRICT_MODE:-true}" == "true" ]] && set -euo pipefail

# Handle VSCode shell integration variables to prevent unset variable errors
: "${VSCODE_SHELL_ENV_REPORTING:=}"

# Handle common environment variables that might be unset
: "${USER:=$(whoami 2>/dev/null || echo "user")}"

# =============================================================================
# CONFIGURATION
# =============================================================================

# Performance multiplier for Windows/Git Bash environments
GHS_PERF_MULTIPLIER=1
[[ "$OSTYPE" == "msys" ]] && GHS_PERF_MULTIPLIER=2

# Only set readonly if not already set (allows multiple sourcing)
if [[ -z "${GH_USERS_CONFIG:-}" ]]; then
    readonly GH_USERS_CONFIG="$HOME/.gh-users"
fi
if [[ -z "${GH_USER_PROFILES:-}" ]]; then
    readonly GH_USER_PROFILES="$HOME/.gh-user-profiles"
fi
if [[ -z "${GH_PROJECT_CONFIG:-}" ]]; then
    readonly GH_PROJECT_CONFIG="$HOME/.gh-project-accounts"
fi

# Initialize configuration files
init_config() {
    # Ensure variables are set (defensive programming for shell environments)
    : "${GH_USERS_CONFIG:=$HOME/.gh-users}"
    : "${GH_USER_PROFILES:=$HOME/.gh-user-profiles}"
    : "${GH_PROJECT_CONFIG:=$HOME/.gh-project-accounts}"
    
    [[ -f "$GH_USERS_CONFIG" ]] || touch "$GH_USERS_CONFIG"
    [[ -f "$GH_USER_PROFILES" ]] || touch "$GH_USER_PROFILES"
    [[ -f "$GH_PROJECT_CONFIG" ]] || touch "$GH_PROJECT_CONFIG"
}


# =============================================================================
# FILE UTILITIES
# =============================================================================

# Execute command with exclusive file lock (simple approach)
with_file_lock() {
    local file="$1"
    shift
    
    local lock_file="${file}.lock"
    local timeout=5
    local start_time=$(date +%s)
    
    # Retry loop with timeout
    while true; do
        # Try to acquire lock (atomic)
        if (set -C; echo $$ > "$lock_file") 2>/dev/null; then
            break
        fi
        
        # Check for stale lock
        if [[ -f "$lock_file" ]]; then
            local lock_pid=$(cat "$lock_file" 2>/dev/null)
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                # Process is dead, remove stale lock
                rm -f "$lock_file"
                continue
            fi
        fi
        
        # Check timeout
        local current_time=$(date +%s)
        if (( current_time - start_time >= timeout )); then
            echo "❌ Lock timeout after ${timeout}s for $file" >&2
            return 1
        fi
        
        # Brief sleep before retry
        sleep 0.1
    done
    
    # Set up cleanup
    trap 'rm -f "$lock_file"' EXIT INT TERM
    
    # Run the command
    "$@"
    local result=$?
    
    # Clean up
    rm -f "$lock_file"
    trap - EXIT INT TERM
    
    return $result
}

# Atomic file write operation
file_write_atomic() {
    local filepath="$1"
    local content="$2"
    local temp_file="${filepath}.tmp.$$"
    
    # Write to temp file
    printf '%s' "$content" > "$temp_file" || return 1
    
    # Atomic move
    if mv "$temp_file" "$filepath"; then
        return 0
    else
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Safe file read operation
file_read_safe() {
    local filepath="$1"
    
    if [[ -f "$filepath" && -r "$filepath" ]]; then
        cat "$filepath"
        return 0
    else
        return 1
    fi
}

# Append line to file (with deduplication)
file_append_line() {
    local filepath="$1"
    local line="$2"
    
    # Initialize file if it doesn't exist
    [[ -f "$filepath" ]] || touch "$filepath"
    
    # Check if line already exists
    if grep -Fxq "$line" "$filepath" 2>/dev/null; then
        return 1  # Line already exists
    fi
    
    # Append line
    echo "$line" >> "$filepath"
    return 0
}

# Remove line from file
file_remove_line() {
    local filepath="$1"
    local line="$2"
    local temp_file
    temp_file=$(mktemp "${filepath}.XXXXXX") || return 1
    
    [[ -f "$filepath" ]] || return 1
    
    # Filter out the line and write to temp file
    grep -Fxv "$line" "$filepath" > "$temp_file" 2>/dev/null || touch "$temp_file"
    
    # Replace original file
    mv "$temp_file" "$filepath"
}

# =============================================================================
# VALIDATION UTILITIES
# =============================================================================

# Validate username format (GitHub rules)
validate_username() {
    local username="$1"
    
    # Basic sanity check first
    if [[ ${#username} -gt 2000 ]]; then
        echo "❌ Input too long (${#username} chars)" >&2
        return 1
    fi
    
    # GitHub's actual rules: 1-39 chars
    if [[ ${#username} -lt 1 ]] || [[ ${#username} -gt 39 ]]; then
        echo "❌ Username must be 1-39 characters (GitHub limit)" >&2
        return 1
    fi
    
    # GitHub username rules: alphanumeric with single hyphens, not at start/end
    if [[ ! "$username" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        echo "❌ Invalid GitHub username format" >&2
        echo "   Must be alphanumeric, may contain single hyphens" >&2
        return 1
    fi
    
    # No double hyphens
    if [[ "$username" == *--* ]]; then
        echo "❌ Username cannot contain consecutive hyphens" >&2
        return 1
    fi
    
    return 0
}

# Basic field length validation
_validate_field_length() {
    local field="$1"
    local field_name="$2"
    local max_length="${3:-2000}"  # Default 2000, can override
    
    if [[ ${#field} -gt $max_length ]]; then
        echo "❌ $field_name too long (${#field} chars, max $max_length)" >&2
        return 1
    fi
    return 0
}

# Validate email format (basic check)
_validate_email() {
    local email="$1"
    
    # Length check - RFC 5321 limit
    _validate_field_length "$email" "Email" 254 || return 1
    
    # Basic format check - must have @ with something on both sides
    if [[ ! "$email" =~ .+@.+ ]]; then
        echo "❌ Invalid email format" >&2
        return 1
    fi
    
    return 0
}

# Validate SSH key file
# Note: This function is ~61 lines, exceeding our 50-line guideline.
# We've reviewed and determined the length is justified by:
# 1. Security checks (path traversal, suspicious patterns)
# 2. Multiple validation steps (exists, permissions, format)
# 3. Clear error messages for each failure mode
# Security and clarity take precedence over brevity here.
validate_ssh_key() {
    local key_path="$1"
    local fix_perms="${2:-false}"
    
    # Empty path is valid (HTTPS mode)
    [[ -z "$key_path" ]] && return 0
    
    # Expand tilde first
    key_path="${key_path/#~/$HOME}"
    
    # Check for directory traversal and suspicious patterns
    if [[ "$key_path" =~ \.\. ]] || [[ "$key_path" =~ /\.\./ ]]; then
        echo "❌ SSH key path contains suspicious patterns" >&2
        return 1
    fi
    
    # Ensure path is absolute or relative to home
    if [[ "$key_path" != /* ]] && [[ "$key_path" != ~/* ]]; then
        # Convert relative path to absolute
        key_path="$(pwd)/$key_path"
    fi
    
    # Check file exists
    if [[ ! -f "$key_path" ]]; then
        echo "❌ SSH key not found: $key_path" >&2
        return 1
    fi
    
    # Check file format
    if ! grep -q "BEGIN.*PRIVATE KEY" "$key_path" 2>/dev/null; then
        echo "❌ File doesn't appear to be a private key: $key_path" >&2
        return 1
    fi
    
    # Check permissions
    local perms
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS stat returns octal permissions
        perms=$(stat -f "%Lp" "$key_path" 2>/dev/null)
    else
        # Linux stat  
        perms=$(stat -c "%a" "$key_path" 2>/dev/null)
    fi
    
    if [[ "$perms" != "600" ]]; then
        # On Windows/Git Bash, permissions don't work the same way
        if [[ "$OSTYPE" == "msys" ]]; then
            if [[ "$fix_perms" == "true" ]]; then
                # Try chmod anyway (sets read-only bit at least)
                chmod 600 "$key_path" 2>/dev/null || true
                echo "ℹ️  Note: SSH key permissions are limited on Windows NTFS" >&2
                echo "   Git Bash SSH will work correctly despite this" >&2
            fi
            # Don't fail on Windows - Git Bash SSH doesn't check permissions
            return 0
        else
            # On Unix systems, this is a real security issue
            if [[ "$fix_perms" == "true" ]]; then
                echo "⚠️  SSH key has incorrect permissions: $key_path" >&2
                echo "   Set permissions to 600" >&2
                if ! chmod 600 "$key_path"; then
                    echo "❌ Failed to fix SSH key permissions" >&2
                    return 1
                fi
            else
                echo "⚠️  SSH key has incorrect permissions: $key_path" >&2
                echo "   Set permissions to 600 with: chmod 600 $key_path" >&2
                return 1
            fi
        fi
    fi
    
    return 0
}

# Validate host format
validate_host() {
    local host="$1"
    
    # Basic sanity check
    [[ -z "$host" ]] && { echo "❌ Host cannot be empty" >&2; return 1; }
    [[ ${#host} -gt 253 ]] && { echo "❌ Host too long" >&2; return 1; }
    
    # Check for specific invalid patterns first to give better error messages
    # No protocol prefix
    if [[ "$host" =~ ^https?:// ]]; then
        echo "❌ Host should not include protocol" >&2
        echo "   Use: github.com (not https://github.com)" >&2
        return 1
    fi
    
    # No port suffix
    if [[ "$host" =~ :[0-9]+$ ]]; then
        echo "❌ Host should not include port" >&2
        echo "   Use: github.com (not github.com:443)" >&2
        return 1
    fi
    
    # Must be a valid domain name (simplified check)
    # - Only alphanumeric, dots, and hyphens
    if [[ ! "$host" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        echo "❌ Invalid host format: $host" >&2
        echo "   Expected format: github.com or github.company.com" >&2
        return 1
    fi
    
    # Must have at least one dot (not just 'github')
    if [[ ! "$host" =~ \. ]]; then
        echo "❌ Host must be a fully qualified domain" >&2
        echo "   Expected format: github.com or github.company.com" >&2
        return 1
    fi
    
    return 0
}


# Apply SSH configuration
apply_ssh_config() {
    local ssh_key="$1"
    local scope="${2:-local}"
    
    # Validate scope
    if [[ "$scope" != "local" ]] && [[ "$scope" != "global" ]]; then
        echo "❌ Invalid scope: $scope" >&2
        return 1
    fi
    
    # Check if in git repository for local scope
    if [[ "$scope" == "local" ]] && ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not in a git repository" >&2
        return 1
    fi
    
    if [[ -n "$ssh_key" ]] && [[ -f "$ssh_key" ]]; then
        # Set SSH command
        git config "--${scope}" core.sshCommand "ssh -i '$ssh_key' -o IdentitiesOnly=yes"
        echo "✅ Configured SSH key: $ssh_key"
    else
        # Remove SSH command
        git config "--${scope}" --unset core.sshCommand 2>/dev/null || true
        echo "✅ Removed SSH configuration"
    fi
    
    return 0
}

# =============================================================================
# USER MANAGEMENT
# =============================================================================

# Add user to configuration
user_add() {
    local username="$1"
    
    validate_username "$username" || return 1
    user_exists "$username" && return 1
    
    with_file_lock "$GH_USERS_CONFIG" file_append_line "$GH_USERS_CONFIG" "$username"
    return 0
}

# Remove user from configuration
user_remove() {
    local username="$1"
    
    validate_username "$username" || return 1
    user_exists "$username" || return 1
    
    with_file_lock "$GH_USERS_CONFIG" file_remove_line "$GH_USERS_CONFIG" "$username"
}

# Check if user exists
user_exists() {
    local username="$1"
    [[ -n "$username" ]] || return 1
    [[ -f "$GH_USERS_CONFIG" ]] && grep -Fxq "$username" "$GH_USERS_CONFIG"
}

# Get user by ID number
user_get_by_id() {
    local user_id="$1"
    
    # Validate with helpful errors for tests
    [[ "$user_id" =~ ^[0-9]+$ ]] || { echo "Invalid user ID: $user_id" >&2; return 1; }
    [[ -s "$GH_USERS_CONFIG" ]] || { echo "No users configured" >&2; return 1; }
    
    # Validate ID is within bounds
    local total_users
    total_users=$(wc -l < "$GH_USERS_CONFIG")
    if [[ "$user_id" -lt 1 ]] || [[ "$user_id" -gt "$total_users" ]]; then
        echo "User ID $user_id out of range (1-$total_users)" >&2
        return 1
    fi
    
    sed -n "${user_id}p" "$GH_USERS_CONFIG"
}

# Count total users
user_count() {
    if [[ -f "$GH_USERS_CONFIG" ]]; then
        wc -l < "$GH_USERS_CONFIG"
    else
        echo "0"
    fi
}

# List all users
user_list() {
    if [[ -f "$GH_USERS_CONFIG" ]]; then
        cat "$GH_USERS_CONFIG"
    fi
}

# =============================================================================
# PROFILE MANAGEMENT
# =============================================================================

# Write profile entry (pipe-delimited for simplicity and extensibility)
_write_profile_entry_to_file() {
    local file="$1"
    local username="$2"
    local name="$3"
    local email="$4"
    local ssh_key="${5:-}"
    local host="${6:-github.com}"  # Default to github.com
    
    # Tab-separated format, no escaping needed
    # Validate no tabs in input (they can't exist in these fields anyway)
    if [[ "$username$name$email$ssh_key$host" == *$'\t'* ]]; then
        echo "❌ Invalid character (tab) in profile data" >&2
        return 1
    fi
    
    # Format: username	name	email	ssh_key	host
    printf "%s\t%s\t%s\t%s\t%s\n" "$username" "$name" "$email" "$ssh_key" "$host" >> "$file"
}

# Write a profile entry (compatibility wrapper)
write_profile_entry() {
    local username="$1"
    local name="$2"
    local email="$3"
    local ssh_key="${4:-}"
    local host="${5:-github.com}"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$GH_USER_PROFILES")"
    
    # Write to global profile file
    _write_profile_entry_to_file "$GH_USER_PROFILES" "$username" "$name" "$email" "$ssh_key" "$host"
}

# Internal helper for profile creation (called with file lock)
_profile_create_locked() {
    local username="$1"
    local name="$2"
    local email="$3"
    local ssh_key="$4"
    local host="$5"
    
    # Create temp file for atomic update
    local temp_file
    temp_file=$(mktemp "${GH_USER_PROFILES}.XXXXXX") || return 1
    
    # Copy existing profiles except the one we're updating
    if [[ -f "$GH_USER_PROFILES" ]]; then
        grep -v "^${username}	" "$GH_USER_PROFILES" > "$temp_file" || true
    fi
    
    # Add new profile entry
    _write_profile_entry_to_file "$temp_file" "$username" "$name" "$email" "$ssh_key" "$host"
    
    # Atomic replace
    mv -f "$temp_file" "$GH_USER_PROFILES"
}

# Create user profile
profile_create() {
    local username="$1"
    local name="${2:-$username}"
    local email="${3:-}"
    local ssh_key="${4:-}"
    local host="${5:-github.com}"
    
    # Generate default email based on host
    if [[ -z "$email" ]]; then
        if [[ "$host" == "github.com" ]]; then
            email="${username}@users.noreply.github.com"
        else
            # Enterprise format: username@host
            email="${username}@${host}"
        fi
    fi
    
    # Validate inputs
    validate_username "$username" || return 1
    _validate_field_length "$name" "Name" 200 || return 1
    _validate_email "$email" || return 1
    validate_host "$host" || return 1
    
    # Note: Tab-delimited format is used for profiles
    
    # Perform the profile creation with file locking
    with_file_lock "$GH_USER_PROFILES" _profile_create_locked "$username" "$name" "$email" "$ssh_key" "$host"
    
    return 0
}

# Get user profile
profile_get() {
    local username="$1"
    
    validate_username "$username" || return 1
    [[ -f "$GH_USER_PROFILES" ]] || return 1
    
    local profile_line
    # Look for tab-delimited format
    profile_line=$(grep "^${username}	" "$GH_USER_PROFILES" | head -1)
    [[ -n "$profile_line" ]] || return 1
    
    # Parse tab-delimited format (handle empty fields correctly)
    # Format: username	name	email	ssh_key	host
    local name email ssh_key host
    
    # Manual parsing to handle empty fields properly
    local line="$profile_line"
    line="${line#*	}"  # Skip username field
    name="${line%%	*}"; line="${line#*	}"
    email="${line%%	*}"; line="${line#*	}"
    ssh_key="${line%%	*}"; line="${line#*	}"
    host="$line"
    
    echo "name:$name"
    echo "email:$email"
    echo "ssh_key:$ssh_key"
    echo "host:${host:-github.com}"  # Fallback if empty
}

# Apply profile to git config
profile_apply() {
    local username="$1"
    local scope="${2:-local}"
    
    
    local profile
    profile=$(profile_get "$username") || return 1
    
    # Parse profile using helper
    local name email ssh_key
    name=$(profile_get_field "$profile" "name")
    email=$(profile_get_field "$profile" "email")
    ssh_key=$(profile_get_field "$profile" "ssh_key")
    
    git_set_config "$name" "$email" "$scope" || return 1
    
    if [[ -n "$ssh_key" ]]; then
        ssh_apply_config "$ssh_key" "$scope" || return 1
        echo "✅ Configured SSH key: $ssh_key"
    fi
    
    echo "✅ Updated ${scope} git config for $username"
    return 0
}

# Internal helper for profile removal (called with file lock)
_profile_remove_locked() {
    local username="$1"
    
    # Create temp file for atomic update
    local temp_file
    temp_file=$(mktemp "${GH_USER_PROFILES}.XXXXXX") || return 1
    
    # Copy all profiles except the one being removed
    grep -v "^${username}	" "$GH_USER_PROFILES" > "$temp_file" || true
    
    # Atomic replace
    mv -f "$temp_file" "$GH_USER_PROFILES"
}

# Remove user profile
profile_remove() {
    local username="$1"
    
    validate_username "$username" || return 1
    
    
    [[ -f "$GH_USER_PROFILES" ]] || return 1
    
    # Perform the profile removal with file locking
    with_file_lock "$GH_USER_PROFILES" _profile_remove_locked "$username"
}



# =============================================================================
# PROJECT MANAGEMENT  
# =============================================================================

# Assign user to project
project_assign() {
    local username="$1"
    local project="${2:-$(basename "$PWD")}"
    
    validate_username "$username" || return 1
    user_exists "$username" || return 1
    
    # Remove existing assignment and add new one (atomic operation)
    local temp_file
    temp_file=$(mktemp "${GH_PROJECT_CONFIG}.XXXXXX") || return 1
    
    # Ensure cleanup on any error
    trap 'rm -f "$temp_file" 2>/dev/null' EXIT
    
    # Copy all assignments except the one being updated
    if [[ -f "$GH_PROJECT_CONFIG" ]]; then
        grep -v "^$project=" "$GH_PROJECT_CONFIG" > "$temp_file" || true
    fi
    
    # Add new assignment
    echo "$project=$username" >> "$temp_file" || { trap - EXIT; rm -f "$temp_file"; return 1; }
    
    # Atomic replace
    mv -f "$temp_file" "$GH_PROJECT_CONFIG"
    trap - EXIT
    
    # Clear cache when assignments change
    auto_switch_cache_clear
}

# Get assigned user for project
project_get_user() {
    local project="${1:-$(basename "$PWD")}"
    
    if [[ ! -f "$GH_PROJECT_CONFIG" ]]; then
        # Silent failure - no projects configured yet
        return 1
    fi
    
    local assignment
    assignment=$(grep "^$project=" "$GH_PROJECT_CONFIG" | head -1)
    [[ -n "$assignment" ]] || return 1
    
    echo "$assignment" | cut -d'=' -f2-
}

# Path-based assignment functions (for directory auto-switch)
# Store full path assignments: /Users/alice/work=alice-work
project_assign_path() {
    local dir_path="$1"
    local username="$2"
    
    validate_username "$username" || return 1
    user_exists "$username" || return 1
    
    # Normalize path (resolve to absolute)
    dir_path=$(cd "$dir_path" 2>/dev/null && pwd) || { echo "❌ Invalid path: $dir_path" >&2; return 1; }
    
    # Escape path for safe storage (replace | with \|)
    local escaped_path="${dir_path//|/\\|}"
    
    # Remove existing assignment and add new one (atomic operation)
    local temp_file
    temp_file=$(mktemp "${GH_PROJECT_CONFIG}.XXXXXX") || return 1
    
    # Ensure cleanup on any error
    trap 'rm -f "$temp_file" 2>/dev/null' EXIT
    
    # Copy all assignments except the one being updated
    if [[ -f "$GH_PROJECT_CONFIG" ]]; then
        # Keep old format assignments (project=user)
        grep -v "^${escaped_path}|" "$GH_PROJECT_CONFIG" > "$temp_file" || true
    fi
    
    # Add new path assignment with marker
    echo "${escaped_path}|$username" >> "$temp_file" || { trap - EXIT; rm -f "$temp_file"; return 1; }
    
    # Atomic replace
    mv -f "$temp_file" "$GH_PROJECT_CONFIG"
    trap - EXIT
    
    # Clear cache when assignments change
    auto_switch_cache_clear
}

# Get assigned user for path (with parent directory inheritance)
project_get_user_by_path() {
    local check_path="$1"
    
    [[ ! -f "$GH_PROJECT_CONFIG" ]] && return 1
    
    # Normalize to absolute path
    check_path=$(cd "$check_path" 2>/dev/null && pwd) || check_path="$1"
    
    # Try cache first
    local cached_user
    if cached_user=$(auto_switch_cache_read "$check_path" 2>/dev/null); then
        echo "$cached_user"
        return 0
    fi
    
    # Look for longest matching path prefix
    local best_user=""
    local best_length=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip old format lines (no pipe separator)
        [[ "$line" != *"|"* ]] && continue
        
        # Extract path and user (unescape pipe)
        local stored_path="${line%%|*}"
        stored_path="${stored_path//\\|/|}"
        local stored_user="${line#*|}"
        
        # Check if current path starts with stored path
        if [[ "$check_path" == "$stored_path" || "$check_path" == "$stored_path"/* ]]; then
            local path_length=${#stored_path}
            if [[ $path_length -gt $best_length ]]; then
                best_user="$stored_user"
                best_length=$path_length
            fi
        fi
    done < "$GH_PROJECT_CONFIG"
    
    # Cache the result
    if [[ -n "$best_user" ]]; then
        auto_switch_cache_write "$check_path" "$best_user"
        echo "$best_user"
        return 0
    fi
    
    return 1
}

# =============================================================================
# SSH MANAGEMENT
# =============================================================================

# Apply SSH configuration
ssh_apply_config() {
    local key_path="$1"
    local scope="${2:-local}"
    
    local git_flags=""
    [[ "$scope" == "global" ]] && git_flags="--global"
    
    if [[ "$scope" == "local" ]] && ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not in a git repository (required for local scope)" >&2
        return 1
    fi
    
    if [[ -z "$key_path" ]]; then
        # Remove SSH config
        git config $git_flags --unset core.sshCommand 2>/dev/null || true
        return 0
    fi
    
    validate_ssh_key "$key_path" || return 1
    
    # Set SSH command
    git config $git_flags core.sshCommand "ssh -i \"$key_path\" -o IdentitiesOnly=yes"
}

# =============================================================================
# SSH TESTING
# =============================================================================

# Test SSH authentication with GitHub
test_ssh_auth() {
    local ssh_key="$1"
    local host="${2:-github.com}"
    
    # Test SSH with specific host
    # Using SSH's built-in timeout for portability (no external timeout command)
    local output
    # Disable pipefail for this command as SSH returns 1 even on success
    if output=$(ssh -T "git@${host}" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=3 \
        -o ServerAliveInterval=3 \
        -o ServerAliveCountMax=1 \
        -o IdentitiesOnly=yes \
        -o IdentityFile="$ssh_key" \
        2>&1); then
        # SSH returned 0 (shouldn't happen with GitHub)
        true
    fi
    
    # SSH to GitHub returns 1 even on success, check the output
    if [[ "$output" =~ "successfully authenticated" ]]; then
        return 0
    fi
    
    # Simple categorization
    if [[ "$output" =~ "Permission denied" ]]; then
        echo "auth_failed"
        return 1
    else
        echo "connection_failed"  
        return 2
    fi
}

# =============================================================================
# PROFILE ISSUE DETECTION
# =============================================================================

# Find alternative SSH keys for a user
find_ssh_key_alternatives() {
    local username="$1"
    local possible_keys=()
    
    # Search for SSH keys
    while IFS= read -r -d '' key; do
        # Skip public keys and known_hosts
        [[ "$key" =~ \.(pub|pem|ppk)$ ]] && continue
        [[ "$key" =~ known_hosts ]] && continue
        [[ "$(basename "$key")" =~ ^\..*$ ]] && continue  # Skip hidden files
        
        possible_keys+=("$key")
    done < <(find "$HOME/.ssh" -type f -name "id_*" ! -name "*.pub" ! -name "*~" -print0 2>/dev/null)
    
    # Check username-specific patterns
    for pattern in "$HOME/.ssh/${username}" "$HOME/.ssh/${username}_"*; do
        if [[ -f "$pattern" ]] && [[ ! "$pattern" =~ \.(pub|pem|ppk)$ ]]; then
            possible_keys+=("$pattern")
        fi
    done
    
    # Remove duplicates and output
    if [[ ${#possible_keys[@]} -gt 0 ]]; then
        printf '%s\n' "${possible_keys[@]}" | sort -u
    fi
}

# Check SSH key status with detailed error messages
# Note: This function is ~84 lines, exceeding our 50-line guideline.
# We've reviewed and determined the length is justified by:
# 1. Comprehensive SSH key discovery with multiple search strategies
# 2. Numbered suggestions for alternative SSH keys
# 3. Detailed explanations for each error scenario
# This follows our design principle of being verbose in error states.
check_ssh_key_status() {
    local username="$1"
    local ssh_key="$2"
    
    if [[ -z "$ssh_key" ]]; then
        return 0  # HTTPS is valid
    fi
    
    if [[ ! -f "$ssh_key" ]]; then
        # Find alternative SSH keys
        local unique_keys=()
        while IFS= read -r key; do
            [[ -n "$key" ]] && unique_keys+=("$key")
        done < <(find_ssh_key_alternatives "$username")
        
        # Display error with options
        echo "   ❌ SSH key not found: ${ssh_key/#$HOME/~}"
        echo "      This file no longer exists at the configured location."
        echo
        
        if [[ ${#unique_keys[@]} -eq 0 ]]; then
            echo "      No SSH keys found in ~/.ssh/"
            echo
            echo "      Option 1: Add a new SSH key"
            echo "        ghs edit $username --ssh-key <path-to-key>"
            echo
            echo "      Option 2: Use HTTPS instead of SSH"
            echo "        ghs edit $username --ssh-key none"
            
        elif [[ ${#unique_keys[@]} -eq 1 ]]; then
            echo "      Found 1 SSH key that might work:"
            echo
            echo "      • ${unique_keys[0]/#$HOME/~}"
            echo
            echo "      To use this key:"
            echo "        ghs edit $username --ssh-key '${unique_keys[0]}'"
            echo
            echo "      Or use HTTPS instead:"
            echo "        ghs edit $username --ssh-key none"
            
        else
            echo "      Found ${#unique_keys[@]} SSH keys that might work:"
            echo
            
            local i=1
            for key in "${unique_keys[@]}"; do
                local key_info=""
                if [[ "$key" =~ _${username}$ ]] || [[ "$key" =~ /${username}$ ]]; then
                    key_info=" (matches username)"
                elif [[ "$key" =~ id_ed25519 ]]; then
                    key_info=" (recommended type)"
                fi
                
                echo "      $i. ${key/#$HOME/~}$key_info"
                echo "         ghs edit $username --ssh-key '$key'"
                echo
                i=$((i + 1))
            done
            
            echo "      Or use HTTPS instead:"
            echo "        ghs edit $username --ssh-key none"
        fi
        
        return 1
    fi
    
    # Check permissions
    local perms
    perms=$(stat -f %Lp "$ssh_key" 2>/dev/null || stat -c %a "$ssh_key" 2>/dev/null)
    # Ensure we only get numeric permissions (filter out any extra output)
    perms=$(echo "$perms" | grep -E '^[0-7]+$' | head -1)
    if [[ "$perms" != "600" ]]; then
        echo "   ⚠️  SSH key has incorrect permissions: $perms (should be 600)"
        echo "      SSH requires private keys to be readable only by you."
        echo
        echo "      Fix with:"
        echo "        chmod 600 '$ssh_key'"
        echo
        echo "      This prevents the error: 'Permissions 0644 for key are too open'"
        return 1
    fi
    
    return 0
}

# Check email format for common issues
check_email_status() {
    local username="$1"
    local email="$2"
    
    # Only warn on exact problematic pattern
    if [[ "$email" == "${username}@github.com" ]]; then
        # Skip for obvious exceptions
        case "$username" in
            *bot|*[[]*|*.github.com) return 0 ;;
        esac
        
        echo "   💡 Possible typo in email"
        echo "      Did you mean: ${username}@users.noreply.github.com?"
        echo "      Fix: ghs edit $username --email ${username}@users.noreply.github.com"
        return 1
    fi
    
    return 0
}

# Check active user configuration
check_active_user_status() {
    local username="$1"
    local profile_email="$2"
    
    # Only check if this is the active user
    local current_gh_user
    current_gh_user=$(gh api user -q .login 2>/dev/null) || return 0
    [[ "$current_gh_user" != "$username" ]] && return 0
    
    # Check git config
    local git_email_global git_email_local
    git_email_global=$(git config --global user.email 2>/dev/null)
    git_email_local=$(git config --local user.email 2>/dev/null)
    
    local git_email=${git_email_local:-$git_email_global}
    
    if [[ -n "$git_email" ]] && [[ "$git_email" != "$profile_email" ]]; then
        local scope=$([[ -n "$git_email_local" ]] && echo "local" || echo "global")
        echo "   ⚠️  Git email doesn't match profile ($scope config)"
        echo "      Git: $git_email"
        echo "      Profile: $profile_email"
        echo "      Fix: ghs switch $username  (reapply profile)"
        return 1
    fi
    
    return 0
}

# =============================================================================
# GIT INTEGRATION
# =============================================================================

# Set git configuration
git_set_config() {
    local name="$1"
    local email="$2"
    local scope="${3:-local}"
    
    local git_flags=""
    [[ "$scope" == "global" ]] && git_flags="--global"
    
    if [[ "$scope" == "local" ]] && ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not in a git repository (required for local scope)" >&2
        return 1
    fi
    
    git config $git_flags user.name "$name" || return 1
    git config $git_flags user.email "$email" || return 1
}

# Check if profile has any issues (for status command)
profile_has_issues() {
    local username="$1"
    local profile_data
    
    profile_data=$(profile_get "$username") 2>/dev/null || return 0  # Missing = issue
    
    # Extract fields
    local email ssh_key
    email=$(profile_get_field "$profile_data" "email")
    ssh_key=$(profile_get_field "$profile_data" "ssh_key")
    
    # Quick checks (suppress output)
    check_ssh_key_status "$username" "$ssh_key" >/dev/null 2>&1 || return 0
    check_email_status "$username" "$email" >/dev/null 2>&1 || return 0
    check_active_user_status "$username" "$email" >/dev/null 2>&1 || return 0
    
    return 1  # No issues
}

# Extract a specific field from profile data
profile_get_field() {
    local profile_data="$1"
    local field="$2"
    echo "$profile_data" | grep "^$field:" | cut -d: -f2-
}

# Get current git configuration
git_get_config() {
    local scope="${1:-auto}"
    
    git --version >/dev/null 2>&1 || return 1
    
    local git_flags=""
    [[ "$scope" == "global" ]] && git_flags="--global"
    [[ "$scope" == "local" ]] && git_flags="--local"
    
    local name email
    name=$(git config $git_flags user.name 2>/dev/null)
    email=$(git config $git_flags user.email 2>/dev/null)
    
    [[ -n "$name" && -n "$email" ]] || return 1
    
    echo "name:$name"
    echo "email:$email"
}

# Get current repository name
git_get_repo() {
    git rev-parse --show-toplevel 2>/dev/null | xargs basename
}

# =============================================================================
# GUARD HOOKS
# =============================================================================

# Guard install function
guard_install() {
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not in a git repository" >&2; return 1; }
    
    local hook_file="$(git rev-parse --git-dir)/hooks/pre-commit"
    mkdir -p "$(dirname "$hook_file")"
    
    # Backup existing hook
    [[ -f "$hook_file" ]] && ! grep -q "GHS_GUARD_HOOK" "$hook_file" && {
        cp "$hook_file" "${hook_file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "📦 Backed up existing pre-commit hook"
    }
    
    # Create hook that can find ghs reliably
    # First, try to find where ghs is installed
    local ghs_path=$(command -v ghs 2>/dev/null)
    
    if [[ -z "$ghs_path" ]]; then
        # If not in PATH, check common locations
        for loc in /usr/local/bin/ghs ~/.local/bin/ghs ~/bin/ghs; do
            [[ -x "$loc" ]] && ghs_path="$loc" && break
        done
    fi
    
    # Create self-contained hook
    cat > "$hook_file" << 'EOF'
#!/bin/bash
# GHS_GUARD_HOOK v2 - Self-contained
[[ "$GHS_SKIP_HOOK" == "1" ]] && exit 0

# Configuration paths
GH_PROJECT_CONFIG="${GH_PROJECT_CONFIG:-$HOME/.gh-project-accounts}"
GH_USER_PROFILES="${GH_USER_PROFILES:-$HOME/.gh-user-profiles}"

# Get repository directory
repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)
[[ -z "$repo_dir" ]] && exit 0

# Get repository name
repo_name=$(basename "$repo_dir")

# Check if this repository has an assigned account
[[ ! -f "$GH_PROJECT_CONFIG" ]] && exit 0
assigned_user=$(grep "^${repo_name}=" "$GH_PROJECT_CONFIG" | cut -d= -f2)
[[ -z "$assigned_user" ]] && exit 0

# Get current GitHub user
current_user=""
if command -v gh >/dev/null 2>&1; then
    current_user=$(gh api user -q .login 2>/dev/null || true)
fi

if [[ -z "$current_user" ]]; then
    echo "⚠️  Cannot verify GitHub account - gh CLI not authenticated"
    echo "   Run: gh auth login"
    exit 0
fi

# Compare users
if [[ "$current_user" != "$assigned_user" ]]; then
    echo "❌ Account mismatch detected!"
    echo
    echo "   Repository: $repo_name"
    echo "   Expected:   $assigned_user"
    echo "   Current:    $current_user"
    echo
    echo "   Switch with: ghs switch $assigned_user"
    echo "   Or bypass:   GHS_SKIP_HOOK=1 git commit ..."
    exit 1
fi

# Check git config matches profile
if [[ -f "$GH_USER_PROFILES" ]]; then
    # Look for profile
    profile_line=$(grep "^${assigned_user}	" "$GH_USER_PROFILES" | head -1)
    if [[ -n "$profile_line" ]]; then
        # Parse format: username	name	email	ssh_key	host
        IFS=$'\t' read -r username name email ssh_key host <<< "$profile_line"
        
        # Get current git config
        current_email=$(git config user.email 2>/dev/null || true)
        
        # Verify email matches
        if [[ -n "$email" ]] && [[ "$current_email" != "$email" ]]; then
            echo "⚠️  Git email mismatch"
            echo "   Expected: $email"
            echo "   Current:  $current_email"
            echo "   Fix with: git config user.email \"$email\""
        fi
    fi
fi

exit 0
EOF
    
    chmod +x "$hook_file"
    echo "✅ Guard hooks installed for $(basename "$(git rev-parse --show-toplevel)")"
    echo "📍 Hook location: $hook_file"
}

# Guard uninstall function  
guard_uninstall() {
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not in a git repository" >&2; return 1; }
    
    local hook_file="$(git rev-parse --git-dir)/hooks/pre-commit"
    [[ -f "$hook_file" ]] || { echo "ℹ️  No pre-commit hook found"; return 0; }
    
    grep -q "GHS_GUARD_HOOK" "$hook_file" 2>/dev/null && {
        rm -f "$hook_file"
        echo "✅ Guard hooks removed"
        
        # Restore most recent backup (sorted by timestamp in filename)
        local backup=""
        local newest_time=0
        for f in "${hook_file}.backup."*; do
            if [[ -f "$f" ]]; then
                # Extract timestamp from filename (format: YYYYmmdd_HHMMSS)
                local timestamp="${f##*.backup.}"
                # Convert to comparable number by removing underscore
                local time_num="${timestamp//_/}"
                if [[ "$time_num" =~ ^[0-9]+$ ]] && [[ "$time_num" -gt "$newest_time" ]]; then
                    newest_time="$time_num"
                    backup="$f"
                fi
            fi
        done
        [[ -n "$backup" ]] && mv "$backup" "$hook_file" && echo "♻️  Restored previous pre-commit hook"
    } || echo "ℹ️  No guard hooks found in pre-commit"
}

# Guard status function
guard_status() {
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not in a git repository" >&2; return 1; }
    
    local hook_file="$(git rev-parse --git-dir)/hooks/pre-commit"
    echo "🛡️  Guard Status for $(basename "$(git rev-parse --show-toplevel)")"
    echo
    
    if [[ -f "$hook_file" ]] && grep -q "GHS_GUARD_HOOK" "$hook_file"; then
        echo "✅ Guard hooks: INSTALLED"
        echo "📍 Location: $hook_file"
        echo
        echo "🔍 Validation status:"
        guard_test
    else
        echo "❌ No guard hooks installed"
        echo "💡 Run 'ghs guard install' to enable protection"
    fi
}

# Guard test function
guard_test() {
    local project=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
    local assigned=$(project_get_user "$project")
    local gh_user=$(gh api user -q .login 2>/dev/null || echo "")
    
    # Check GitHub CLI
    [[ -z "$gh_user" ]] && { 
        echo "⚠️  GitHub CLI not authenticated"
        echo "   Run: gh auth login"
        return 0
    }
    
    # Check assignment
    [[ -z "$assigned" ]] && {
        echo "⚠️  No project assignment found"
        echo "   Run: ghs assign <user>"
        return 0
    }
    
    # Validate account
    [[ "$gh_user" != "$assigned" ]] && {
        echo "❌ Account mismatch detected!"
        echo "   Expected: $assigned"
        echo "   Current:  $gh_user"
        echo
        echo "   Fix with: ghs switch $assigned"
        return 1
    }
    
    # If we have a profile, check if it's for a different host
    local profile expected_host
    profile=$(profile_get "$assigned" 2>/dev/null)
    if [[ -n "$profile" ]]; then
        expected_host=$(profile_get_field "$profile" "host")
        if [[ -n "$expected_host" ]] && [[ "$expected_host" != "github.com" ]]; then
            echo "ℹ️  Note: This profile is for host: $expected_host"
            echo "   Ensure you're authenticated: gh auth status --hostname $expected_host"
        fi
    fi
    
    # Check git config
    local name=$(git config user.name)
    local email=$(git config user.email)
    [[ -z "$name" || -z "$email" ]] && {
        echo "❌ Git config incomplete!"
        echo "   Name:  ${name:-<not set>}"
        echo "   Email: ${email:-<not set>}"
        echo
        echo "   Fix with: ghs switch $assigned"
        return 1
    }
    
    echo "✅ Validation would pass"
    echo "   Current GitHub user: $gh_user"
    echo "   Account matches project assignment"
    echo "   Git config: $name <$email>"
    return 0
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Check if user has SSH key configured
user_has_ssh_key() {
    local username="$1"
    local profile
    profile=$(profile_get "$username" 2>/dev/null) || return 1
    local ssh_key=$(profile_get_field "$profile" "ssh_key")
    [[ -n "$ssh_key" ]]
}

# =============================================================================
# COMMAND HANDLERS
# =============================================================================

# Add user command
# Note: This function is ~108 lines, exceeding our 50-line guideline.
# We've reviewed and determined the length is justified by:
# 1. Comprehensive SSH key validation with multiple checks
# 2. SSH authentication testing with network-aware error handling
# 3. Interactive prompts with smart defaults for different scenarios
# Extracting these would reduce clarity without meaningful benefit.
cmd_add() {
    local username="${1:-}"
    local ssh_key=""
    local host="github.com"  # Default
    
    # Parse options
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh-key) ssh_key="$2"; shift 2 ;;
            --host) host="$2"; shift 2 ;;
            *)         
                echo "❌ Unknown option: $1" >&2
                echo "Usage: ghs add <username|current> [--ssh-key <path>] [--host <github.com|github.enterprise.com>]" >&2
                return 1
                ;;
        esac
    done
    
    # Validate input
    if [[ -z "$username" ]]; then
        echo "❌ Username required" >&2
        echo "Usage: ghs add <username|current> [--ssh-key <path>] [--host <github.com|github.enterprise.com>]" >&2
        return 1
    fi
    
    # Handle 'current' - get authenticated GitHub user
    if [[ "$username" == "current" ]]; then
        echo "🔍 Detecting authenticated GitHub user..."
        username=$(gh api user -q .login) || {
            echo "❌ Not authenticated with GitHub CLI" >&2
            echo "   Run: gh auth login" >&2
            return 1
        }
        local detected_host="github.com"
        if [[ "$host" != "github.com" ]]; then
            detected_host="$host"
        fi
        echo "✅ Found: $username ($detected_host)"
    fi
    
    if ! validate_username "$username"; then
        echo "❌ Invalid username format" >&2
        return 1
    fi
    
    # Validate host format
    if ! validate_host "$host"; then
        return 1
    fi
    
    # Check if user already exists
    if user_exists "$username"; then
        echo "⚠️  User $username already exists in the list" >&2
        return 0  # Return success as per test expectations
    fi
    
    # Validate SSH key if provided
    if [[ -n "$ssh_key" ]]; then
        # Expand tilde in path
        ssh_key="${ssh_key/#~/$HOME}"
        
        if [[ ! -f "$ssh_key" ]]; then
            echo "⚠️  SSH key not found: $ssh_key" >&2
            echo "   Continuing with HTTPS mode" >&2
            ssh_key=""  # Clear SSH key to use HTTPS
        elif ! grep -q "BEGIN.*PRIVATE KEY" "$ssh_key" 2>/dev/null; then
            echo "⚠️  Invalid SSH key format: $ssh_key" >&2
            echo "   File doesn't appear to be a private key" >&2
            echo "   Continuing with HTTPS mode" >&2
            ssh_key=""  # Clear SSH key to use HTTPS
        elif [[ $(stat -f "%a" "$ssh_key" 2>/dev/null || stat -c "%a" "$ssh_key" 2>/dev/null) != "600" ]]; then
            echo "⚠️  SSH key has incorrect permissions: $ssh_key" >&2
            echo "   Set permissions to 600 with: chmod 600 $ssh_key" >&2
            chmod 600 "$ssh_key" 2>/dev/null || true
        fi
        
        # Test SSH authentication if key is valid
        if [[ -n "$ssh_key" ]] && [[ -f "$ssh_key" ]]; then
            echo "🔐 Testing SSH authentication..."
            echo "   Host: $host"
            local result exit_code
            
            # Run SSH test and capture both output and exit code
            if result=$(test_ssh_auth "$ssh_key" "$host" 2>&1); then
                exit_code=0
            else
                exit_code=$?
            fi
            
            # Check if it was an auth failure or network issue
            if [[ "$result" == "auth_failed" ]]; then
                exit_code=1
            elif [[ "$result" == "connection_failed" ]]; then
                exit_code=2
            fi
            
            case "$exit_code" in
                0)  # Success
                    echo "✅ SSH key authenticated successfully"
                    ;;
                1)  # Auth failed
                    echo "❌ SSH key not recognized by GitHub"
                    echo
                    echo "   The key exists but GitHub rejected it. This usually means:"
                    echo "   • Key not added to GitHub: https://github.com/settings/keys"
                    echo "   • Key is for a different account"
                    echo
                    echo -n "   Add profile anyway? (y/N) "
                    if [[ -t 0 ]]; then
                        read -r response </dev/tty
                    else
                        read -r response
                    fi
                    [[ ! "$response" =~ ^[Yy]$ ]] && return 1
                    ;;
                2)  # Network issue
                    echo "⚠️  Cannot reach GitHub to test SSH key"
                    echo
                    echo "   Unable to verify authentication due to network issues."
                    echo "   The SSH key configuration looks correct."
                    echo
                    echo "   You can test manually later with: ghs test-ssh $username"
                    echo
                    echo -n "   Continue adding profile? (Y/n) "
                    if [[ -t 0 ]]; then
                        read -r response </dev/tty
                    else
                        read -r response
                    fi
                    [[ "$response" =~ ^[Nn]$ ]] && return 1
                    ;;
            esac
        fi
    fi
    
    # Add user and create profile
    if user_add "$username" && profile_create "$username" "$username" "" "$ssh_key" "$host"; then
        echo "✅ Added $username to user list"
        [[ -n "$ssh_key" ]] && echo "🔐 SSH key: $ssh_key"
        [[ "$host" != "github.com" ]] && echo "🏢 Host: $host"
        echo
        # Show next step suggestion
        local user_num
        user_num=$(user_count)
        echo "💡 Next: ghs switch $user_num"
        return 0
    else
        echo "❌ Failed to add user" >&2
        return 1
    fi
}

# Remove user command
cmd_remove() {
    local input="${1:-}"
    
    if [[ -z "$input" ]]; then
        echo "❌ Username or ID required" >&2
        echo "Usage: ghs remove-user <username_or_id>" >&2
        return 1
    fi
    
    local username
    local is_numeric=false
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        is_numeric=true
        username=$(user_get_by_id "$input") || {
            if [[ ! -f "$GH_USERS_CONFIG" ]] || [[ ! -s "$GH_USERS_CONFIG" ]]; then
                echo "❌ No users configured" >&2
            else
                echo "❌ User ID $input not found" >&2
            fi
            return 1
        }
    else
        username="$input"
    fi
    
    if ! user_exists "$username"; then
        echo "❌ User $username not found" >&2
        return 1
    fi
    
    # Remove user and profile
    user_remove "$username"
    profile_remove "$username" 2>/dev/null || true  # Don't fail if profile doesn't exist
    
    if [[ "$is_numeric" == "true" ]]; then
        echo "🗑️  Removing user #$input: $username"
    fi
    echo "✅ Removed $username from user list"
    return 0
}

# Switch user command
cmd_switch() {
    local input="$1"
    
    if [[ -z "$input" ]]; then
        echo "❌ Username or ID required" >&2
        echo "Usage: ghs switch <username_or_id>" >&2
        return 1
    fi
    
    local username
    local user_id=""
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        user_id="$input"
        username=$(user_get_by_id "$input") || {
            echo "❌ User ID $input not found" >&2
            return 1
        }
    else
        username="$input"
    fi
    
    if ! user_exists "$username"; then
        echo "❌ User $username not found" >&2
        return 1
    fi
    
    # Pre-flight check
    local profile
    profile=$(profile_get "$username") || {
        echo "❌ Cannot switch - no profile"
        echo "   Fix: ghs edit $username --email <email>"
        return 1
    }
    
    # Get target host
    local host
    host=$(profile_get_field "$profile" "host")
    [[ -z "$host" ]] && host="github.com"
    
    # Show what we're switching to
    echo "🔄 Switching to $username on $host"
    
    # Check if different host than github.com
    if [[ "$host" != "github.com" ]]; then
        echo "💡 For enterprise hosts, ensure you're authenticated:"
        echo "   gh auth status --hostname $host"
        echo "   If not: gh auth login --hostname $host"
    fi
    
    # Check SSH key before switching
    local ssh_key
    ssh_key=$(echo "$profile" | grep "^ssh_key:" | cut -d: -f2-)
    if [[ -n "$ssh_key" ]] && [[ ! -f "$ssh_key" ]]; then
        echo "⚠️  Warning: SSH key not found"
        echo "   Git operations may fail over SSH"
        echo -n "   Continue anyway? (y/N) "
        read -r response
        [[ "$response" =~ ^[Yy]$ ]] || return 1
    fi
    
    # Apply profile
    if profile_apply "$username" "local" >/dev/null 2>&1; then
        if [[ -n "$user_id" ]]; then
            echo "✅ Switched to $username (#$user_id)"
        else
            echo "✅ Switched to user: $username"
        fi
    else
        echo "❌ Failed to switch to user: $username" >&2
        return 1
    fi
}

# List all assignments
cmd_assign_list() {
    if [[ ! -f "$GH_PROJECT_CONFIG" ]]; then
        echo "📋 No directory assignments configured"
        return 0
    fi
    
    echo "📋 Directory assignments:"
    echo
    
    # Count assignments first
    local path_count=0
    local project_count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *"|"* ]]; then
            path_count=$((path_count + 1))
        elif [[ -n "$line" ]]; then
            project_count=$((project_count + 1))
        fi
    done < "$GH_PROJECT_CONFIG"
    
    # Show path-based assignments
    if [[ $path_count -gt 0 ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == *"|"* ]]; then
                local dir_path="${line%%|*}"
                dir_path="${dir_path//\\|/|}"
                local user="${line#*|}"
                echo "  $dir_path → $user"
            fi
        done < "$GH_PROJECT_CONFIG" | sort
    fi
    
    # Show legacy project assignments
    if [[ $path_count -gt 0 && $project_count -gt 0 ]]; then
        echo
        echo "Legacy project assignments:"
    fi
    
    if [[ $project_count -gt 0 ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" != *"|"* && -n "$line" ]]; then
                local project="${line%%=*}"
                local user="${line#*=}"
                echo "  $project → $user"
            fi
        done < "$GH_PROJECT_CONFIG" | sort
    fi
    
    if [[ $path_count -eq 0 && $project_count -eq 0 ]]; then
        echo "  (none)"
    fi
}

# Remove assignment for a path
cmd_assign_remove() {
    local dir_path="$1"
    
    # Normalize path
    dir_path=$(cd "$dir_path" 2>/dev/null && pwd) || { echo "❌ Invalid path: $dir_path" >&2; return 1; }
    
    if [[ ! -f "$GH_PROJECT_CONFIG" ]]; then
        echo "❌ No assignments to remove" >&2
        return 1
    fi
    
    # Escape path for grep
    local escaped_path="${dir_path//|/\\|}"
    
    # Check if assignment exists
    if ! grep -q "^${escaped_path}|" "$GH_PROJECT_CONFIG" 2>/dev/null; then
        echo "❌ No assignment found for: $dir_path" >&2
        return 1
    fi
    
    # Remove the assignment
    local temp_file
    temp_file=$(mktemp "${GH_PROJECT_CONFIG}.XXXXXX") || return 1
    
    grep -v "^${escaped_path}|" "$GH_PROJECT_CONFIG" > "$temp_file" || true
    mv -f "$temp_file" "$GH_PROJECT_CONFIG"
    
    echo "✅ Removed assignment for: $dir_path"
    
    # Clear cache
    auto_switch_cache_clear
}

# Clean up non-existent paths
cmd_assign_clean() {
    if [[ ! -f "$GH_PROJECT_CONFIG" ]]; then
        echo "📋 No assignments to clean"
        return 0
    fi
    
    local temp_file
    temp_file=$(mktemp "${GH_PROJECT_CONFIG}.XXXXXX") || return 1
    
    local removed_count=0
    
    # Process each line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *"|"* ]]; then
            # Path-based assignment
            local dir_path="${line%%|*}"
            dir_path="${dir_path//\\|/|}"
            
            if [[ -d "$dir_path" ]]; then
                echo "$line" >> "$temp_file"
            else
                echo "  Removing non-existent path: $dir_path"
                removed_count=$((removed_count + 1))
            fi
        else
            # Keep legacy assignments
            echo "$line" >> "$temp_file"
        fi
    done < "$GH_PROJECT_CONFIG"
    
    if [[ $removed_count -gt 0 ]]; then
        mv -f "$temp_file" "$GH_PROJECT_CONFIG"
        echo
        echo "✅ Cleaned up $removed_count non-existent path(s)"
        
        # Clear cache
        auto_switch_cache_clear
    else
        rm -f "$temp_file"
        echo "✅ All paths are valid"
    fi
}

# Assign user to project command
cmd_assign() {
    local input="$1"
    
    # Handle special flags
    case "$input" in
        --list)
            cmd_assign_list
            return $?
            ;;
        --remove)
            local dir_path="${2:-$PWD}"
            cmd_assign_remove "$dir_path"
            return $?
            ;;
        --clean)
            cmd_assign_clean
            return $?
            ;;
    esac
    
    local project="${2:-$(basename "$PWD")}"
    
    if [[ -z "$input" ]]; then
        echo "❌ Username or ID required" >&2
        echo "Usage: ghs assign <username_or_id>" >&2
        echo "       ghs assign --list" >&2
        echo "       ghs assign --remove [path]" >&2
        echo "       ghs assign --clean" >&2
        return 1
    fi
    
    local username
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        username=$(user_get_by_id "$input") || {
            echo "❌ User ID $input not found" >&2
            return 1
        }
    else
        username="$input"
    fi
    
    if ! user_exists "$username"; then
        echo "❌ User $username not found" >&2
        return 1
    fi
    
    # Assign user to project or path
    if git rev-parse --git-dir >/dev/null 2>&1; then
        # In a git repo - use path-based assignment for auto-switch
        if project_assign_path "$PWD" "$username"; then
            echo "✅ Assigned $username to directory: $PWD"
            
            # Also assign by project name for backwards compatibility
            project_assign "$username" "$project" >/dev/null 2>&1 || true
        else
            echo "❌ Failed to assign user to directory" >&2
            return 1
        fi
    else
        # Not in git repo - use traditional project assignment
        if project_assign "$username" "$project"; then
            echo "✅ Assigned $username to project: $project"
        else
            echo "❌ Failed to assign user to project" >&2
            return 1
        fi
    fi
    
    # Feature discovery
    if ! auto_switch_enabled; then
        echo
        echo "💡 Enable auto-switch to change profiles automatically:"
        echo "   ghs auto-switch enable"
    fi
}

# List users command
cmd_users() {
    if [[ $(user_count) -eq 0 ]]; then
        echo "📋 No users configured yet"
        echo "   Use 'ghs add-user <username>' to add users"
        return 0
    fi
    
    echo "📋 Available users:"
    local i=1
    while IFS= read -r username; do
        if [[ -n "$username" ]]; then
            local profile_info=""
            local host_info=""
            
            # Get profile details
            local profile
            if profile=$(profile_get "$username" 2>/dev/null); then
                local host=$(profile_get_field "$profile" "host")
                if [[ -n "$host" ]] && [[ "$host" != "github.com" ]]; then
                    host_info=" ($host)"
                fi
                
                if user_has_ssh_key "$username"; then
                    profile_info=" [SSH]"
                else
                    profile_info=" [HTTPS]"
                fi
            fi
            
            echo "  $i. $username$profile_info$host_info"
            i=$((i + 1))
        fi
    done < "$GH_USERS_CONFIG"
    return 0
}

# Show user profile details with issue detection
# Note: This function is ~95 lines, exceeding our 50-line guideline.
# We've reviewed and determined the length is justified by:
# 1. Comprehensive status checks (SSH key, email, git config)
# 2. Detailed error reporting with actionable suggestions
# 3. Multiple SSH key alternative suggestions with numbered options
# The verbose output is essential for helping users diagnose issues.
cmd_show() {
    local input="${1:-}"
    
    if [[ -z "$input" ]]; then
        echo "Usage: ghs show <username_or_id>"
        return 1
    fi
    
    # Resolve username from input (ID or name)
    local username
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        username=$(user_get_by_id "$input") || {
            echo "❌ User ID $input not found" >&2
            return 1
        }
    else
        username="$input"
    fi
    
    # Check user exists
    if ! user_exists "$username"; then
        echo "❌ User '$username' not found" >&2
        echo "💡 Run 'ghs users' to see available users" >&2
        return 1
    fi
    
    # Get profile data
    local profile
    profile=$(profile_get "$username" 2>/dev/null) || {
        echo "❌ No profile for $username"
        echo "   Fix: ghs edit $username --email <email>"
        return 1
    }
    
    # Parse profile fields
    local name email ssh_key host
    name=$(profile_get_field "$profile" "name")
    email=$(profile_get_field "$profile" "email")
    ssh_key=$(profile_get_field "$profile" "ssh_key")
    host=$(profile_get_field "$profile" "host")
    [[ -z "$host" ]] && host="github.com"
    
    # Display basic info
    echo "👤 $username"
    [[ "$host" != "github.com" ]] && echo "   Host: $host"
    echo "   Email: $email"
    echo "   Name: $name"
    
    # SSH status
    if [[ -n "$ssh_key" ]]; then
        if [[ -f "$ssh_key" ]]; then
            local perms
            perms=$(stat -f %Lp "$ssh_key" 2>/dev/null || stat -c %a "$ssh_key" 2>/dev/null)
            # Ensure we only get numeric permissions (filter out any extra output)
            perms=$(echo "$perms" | grep -E '^[0-7]+$' | head -1)
            if [[ "$perms" == "600" ]] || [[ "$OSTYPE" == "msys" ]]; then
                echo "   SSH: ${ssh_key/#$HOME/~} ✅"
            else
                echo "   SSH: ${ssh_key/#$HOME/~} ⚠️"
            fi
        else
            echo "   SSH: ${ssh_key/#$HOME/~} ❌"
        fi
    else
        echo "   SSH: Using HTTPS"
    fi
    
    # Check status
    local current_gh_user
    current_gh_user=$(gh api user -q .login 2>/dev/null) || current_gh_user=""
    if [[ "$current_gh_user" == "$username" ]]; then
        echo "   Status: Active ✅"
    elif [[ -n "$current_gh_user" ]]; then
        echo "   Status: Inactive (current: $current_gh_user)"
    else
        echo "   Status: Inactive"
    fi
    
    # Run checks
    echo
    local has_issues=false
    
    # Check SSH key issues
    if [[ -n "$ssh_key" ]]; then
        check_ssh_key_status "$username" "$ssh_key" || has_issues=true
    fi
    
    # Check email issues
    check_email_status "$username" "$email" || has_issues=true
    
    # Check active user issues
    check_active_user_status "$username" "$email" || has_issues=true
    
    # If no issues
    [[ "$has_issues" == false ]] && echo "   ✅ No issues detected"
    
    return 0
}

# Validate edit command arguments
cmd_edit_validate_arg() {
    local option="$1"
    local value="$2"
    
    if [[ -z "$value" ]] || [[ "$value" == --* ]]; then
        echo "❌ $option requires a value" >&2
        return 1
    fi
    
    return 0
}

# Show usage for edit command
cmd_edit_usage() {
    echo "Usage: ghs edit <username> [options]"
    echo
    echo "Options:"
    echo "  --email <email>     Update email address"
    echo "  --name <name>       Update display name"
    echo "  --ssh-key <path>    Update SSH key (use 'none' to remove)"
    echo "  --host <domain>     Update GitHub host (e.g., github.company.com)"
    echo
    echo "Examples:"
    echo "  ghs edit alice --email alice@company.com"
    echo "  ghs edit bob --ssh-key ~/.ssh/id_ed25519_bob"
    echo "  ghs edit work --name 'Work Account' --ssh-key none"
    echo "  ghs edit work --host github.enterprise.com"
}

# Edit user profile (email, name, SSH key)
# Note: This function is ~85 lines, exceeding our 50-line guideline.
# We've reviewed and attempted to simplify it, but determined the current
# structure is the most clear and maintainable. The length comes from
# necessary validation, profile handling, and argument parsing that would
# be awkward to split further.
cmd_edit() {
    local username="${1:-}"
    
    if [[ -z "$username" ]] || [[ "$username" == "--help" ]]; then
        cmd_edit_usage
        return 1
    fi
    
    # Check if user exists
    if ! user_exists "$username"; then
        echo "❌ User '$username' not found"
        echo "💡 Use 'ghs add $username' to create"
        return 1
    fi
    
    # Get current profile or defaults
    local profile current_name current_email current_ssh current_host
    profile=$(profile_get "$username" 2>/dev/null)
    
    if [[ -z "$profile" ]]; then
        current_name="$username"
        current_email="${username}@users.noreply.github.com"
        current_ssh=""
        current_host="github.com"
        echo "ℹ️  No profile found, creating new one"
    else
        current_name=$(profile_get_field "$profile" "name")
        current_email=$(profile_get_field "$profile" "email")
        current_ssh=$(profile_get_field "$profile" "ssh_key")
        current_host=$(profile_get_field "$profile" "host")
        [[ -z "$current_host" ]] && current_host="github.com"
    fi
    
    # Initialize with current values
    local new_name="$current_name"
    local new_email="$current_email"
    local new_ssh="$current_ssh"
    local new_host="$current_host"
    local changes_made=false
    
    # Parse options
    shift # Remove username
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --email)
                cmd_edit_validate_arg "$1" "$2" || return 1
                new_email="$2"
                changes_made=true
                shift 2
                ;;
            --name)
                cmd_edit_validate_arg "$1" "$2" || return 1
                new_name="$2"
                changes_made=true
                shift 2
                ;;
            --ssh-key)
                cmd_edit_validate_arg "$1" "$2" || return 1
                if [[ "$2" == "none" ]]; then
                    new_ssh=""
                else
                    new_ssh="${2/#~/$HOME}"
                fi
                changes_made=true
                shift 2
                ;;
            --host)
                cmd_edit_validate_arg "$1" "$2" || return 1
                new_host="$2"
                if ! validate_host "$new_host"; then
                    return 1
                fi
                changes_made=true
                shift 2
                ;;
            --gpg-key|--signing-key)
                echo "❌ GPG commit signing is not currently supported"
                echo "   gh-switcher focuses on authentication (SSH/HTTPS)"
                echo "   File an issue if needed: https://github.com/seconds-0/gh-switcher/issues"
                return 1
                ;;
            *)
                echo "❌ Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Delegate to update function
    cmd_edit_update_profile "$username" "$new_email" "$new_name" "$new_ssh" "$new_host" "$current_email" "$current_name" "$current_ssh" "$current_host" "$changes_made"
}

# Update user profile with provided changes
cmd_edit_update_profile() {
    local username="$1"
    local new_email="$2"
    local new_name="$3"
    local new_ssh="$4"
    local new_host="$5"
    local current_email="$6"
    local current_name="$7"
    local current_ssh="$8"
    local current_host="$9"
    local changes_made="${10}"
    
    # Check if any changes requested
    if [[ "$changes_made" == false ]]; then
        echo "ℹ️  No changes specified"
        cmd_show "$username"
        return 0
    fi
    
    # Validate email if changed
    if [[ "$new_email" != "$current_email" ]]; then
        if ! _validate_email "$new_email"; then
            return 1
        fi
    fi
    
    # Validate name if changed
    if [[ "$new_name" != "$current_name" ]]; then
        if ! _validate_field_length "$new_name" "Name" 200; then
            return 1
        fi
    fi
    
    # Validate SSH key if changed
    if [[ -n "$new_ssh" ]] && [[ "$new_ssh" != "$current_ssh" ]]; then
        if [[ ! -f "$new_ssh" ]]; then
            echo "❌ SSH key not found: $new_ssh"
            return 1
        fi
        if ! validate_ssh_key "$new_ssh"; then
            return 1
        fi
    fi
    
    # Apply changes
    if ! profile_create "$username" "$new_name" "$new_email" "$new_ssh" "$new_host"; then
        echo "❌ Failed to update profile"
        return 1
    fi
    
    echo "✅ Profile updated"
    echo
    
    # Show updated profile
    cmd_show "$username"
    
    # Suggest reapply if active
    local current_gh_user
    current_gh_user=$(gh api user -q .login 2>/dev/null) || current_gh_user=""
    
    if [[ "$current_gh_user" == "$username" ]]; then
        echo
        echo "💡 Run 'ghs switch $username' to apply changes"
    fi
    
    return 0
}

# =============================================================================
# AUTO-SWITCH FEATURE
# =============================================================================

# Cache for auto-switch to improve performance
AUTO_SWITCH_CACHE_DIR="/tmp/.ghs-auto-switch-cache-$USER"
AUTO_SWITCH_CACHE_TTL=300  # 5 minutes

# Get cache file for a given path
auto_switch_cache_file() {
    local dir_path="$1"
    local hash
    hash=$(echo -n "$dir_path" | sha256sum | cut -c1-16)
    echo "$AUTO_SWITCH_CACHE_DIR/path-$hash"
}

# Read from cache if valid
auto_switch_cache_read() {
    local dir_path="$1"
    local cache_file
    cache_file=$(auto_switch_cache_file "$dir_path")
    
    [[ -f "$cache_file" ]] || return 1
    
    # Check if cache is still valid (modified within TTL)
    local now cache_time age
    now=$(date +%s)
    cache_time=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)
    age=$((now - cache_time))
    
    [[ $age -lt $AUTO_SWITCH_CACHE_TTL ]] || return 1
    
    cat "$cache_file"
}

# Write to cache
auto_switch_cache_write() {
    local dir_path="$1"
    local user="$2"
    
    mkdir -p "$AUTO_SWITCH_CACHE_DIR" 2>/dev/null || return 0
    
    local cache_file
    cache_file=$(auto_switch_cache_file "$dir_path")
    echo "$user" > "$cache_file" 2>/dev/null || true
}

# Clear cache (when assignments change)
auto_switch_cache_clear() {
    rm -rf "$AUTO_SWITCH_CACHE_DIR" 2>/dev/null || true
}

# Check if auto-switch is enabled
auto_switch_enabled() {
    [[ -f "$HOME/.ghs-auto-switch-enabled" ]]
}

# Auto-switch main command
cmd_auto_switch() {
    local subcmd="${1:-status}"
    shift 2>/dev/null || true
    
    case "$subcmd" in
        enable)
            auto_switch_enable "$@"
            ;;
        disable)
            auto_switch_disable "$@"
            ;;
        status)
            auto_switch_status "$@"
            ;;
        test)
            auto_switch_test "$@"
            ;;
        check)
            # Support --debug flag
            if [[ "${1:-}" == "--debug" ]]; then
                shift
                auto_switch_check_debug "$@"
            else
                auto_switch_check "$@"
            fi
            ;;
        *)
            echo "Usage: ghs auto-switch <enable|disable|status|test>"
            echo
            echo "Automatic profile switching based on directory"
            echo
            echo "Commands:"
            echo "  enable    Turn on automatic profile switching"
            echo "  disable   Turn off automatic profile switching"
            echo "  status    Show current auto-switch configuration"
            echo "  test      Preview what would happen in current directory"
            return 1
            ;;
    esac
}

# Enable auto-switching
auto_switch_enable() {
    # Create flag file
    touch "$HOME/.ghs-auto-switch-enabled"
    
    echo "✅ Auto-switch enabled!"
    echo
    echo "Next steps:"
    
    # Detect shell and provide instructions
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "1. Restart your shell or run: source ~/.zshrc"
        
        # Check if hook already installed
        if ! grep -q "ghs_auto_switch" ~/.zshrc 2>/dev/null; then
            echo "2. Add to your ~/.zshrc:"
            echo
            echo '# gh-switcher auto-switch'
            echo 'ghs_auto_switch() {'
            echo '    [[ -f ~/.ghs-auto-switch-enabled ]] || return'
            echo '    command -v ghs >/dev/null 2>&1 || return'
            echo '    ghs auto-switch check --quiet'
            echo '}'
            echo 'autoload -U add-zsh-hook'
            echo 'add-zsh-hook chpwd ghs_auto_switch'
        fi
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "1. Restart your shell or run: source ~/.bashrc"
        
        # Check if hook already installed
        if ! grep -q "ghs_auto_switch" ~/.bashrc 2>/dev/null; then
            echo "2. Add to your ~/.bashrc:"
            echo
            echo '# gh-switcher auto-switch'
            echo 'ghs_auto_switch() {'
            echo '    [[ -f ~/.ghs-auto-switch-enabled ]] || return'
            echo '    command -v ghs >/dev/null 2>&1 || return'
            # shellcheck disable=SC2016
            echo '    [[ "$PWD" != "$GHS_LAST_DIR" ]] || return'
            # shellcheck disable=SC2016
            echo '    export GHS_LAST_DIR="$PWD"'
            echo '    ghs auto-switch check --quiet'
            echo '}'
            # shellcheck disable=SC2016,SC2028
            echo 'PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'"'"'\n'"'"'}ghs_auto_switch"'
        fi
    else
        echo "1. Add the auto-switch hook to your shell configuration"
    fi
    
    echo "3. Your profile will automatically switch when entering assigned directories"
    echo "4. Run 'ghs auto-switch test' to preview behavior"
    echo
    echo "💡 Tip: Auto-switch respects parent directories. Assign to ~/work to cover all subdirectories."
}

# Disable auto-switching
auto_switch_disable() {
    rm -f "$HOME/.ghs-auto-switch-enabled"
    echo "✅ Auto-switch disabled"
    echo
    echo "Note: The shell hook remains installed but inactive."
    echo "To fully remove, delete the ghs_auto_switch function from your shell config."
}

# Show auto-switch status
auto_switch_status() {
    echo "🔄 Auto-Switch Status"
    echo
    
    if auto_switch_enabled; then
        echo "Status: ENABLED ✅"
        
        # Count assignments
        if [[ -f "$GH_PROJECT_CONFIG" ]]; then
            local path_count=0
            local project_count=0
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ "$line" == *"|"* ]]; then
                    path_count=$((path_count + 1))
                else
                    project_count=$((project_count + 1))
                fi
            done < "$GH_PROJECT_CONFIG"
            
            echo "Assigned directories: $path_count"
            [[ $project_count -gt 0 ]] && echo "Legacy projects: $project_count"
        else
            echo "Assigned directories: 0"
        fi
        
        # Check shell hook
        local shell_config=""
        [[ -n "${ZSH_VERSION:-}" ]] && shell_config="$HOME/.zshrc"
        [[ -n "${BASH_VERSION:-}" ]] && shell_config="$HOME/.bashrc"
        
        if [[ -n "$shell_config" ]] && grep -q "ghs_auto_switch" "$shell_config" 2>/dev/null; then
            echo "Shell hook: Installed ✅"
        else
            echo "Shell hook: Not installed ⚠️"
            echo "             Run 'ghs auto-switch enable' for instructions"
        fi
    else
        echo "Status: DISABLED ⭕"
        echo
        echo "Enable with: ghs auto-switch enable"
    fi
}

# Test what auto-switch would do
auto_switch_test() {
    local current_dir="$PWD"
    local current_repo
    current_repo=$(git_get_repo 2>/dev/null) || current_repo=$(basename "$PWD")
    
    echo "🔍 Auto-switch test for: $current_dir"
    echo
    
    # Check if enabled
    if auto_switch_enabled; then
        echo "✓ Auto-switch is enabled"
    else
        echo "✗ Auto-switch is disabled"
        echo "  Enable with: ghs auto-switch enable"
        return 0
    fi
    
    # Check for assignment using new path-based lookup
    local assigned_user=""
    local assigned_from=""
    
    # Try path-based lookup first
    if assigned_user=$(project_get_user_by_path "$PWD" 2>/dev/null); then
        # Find which path it was assigned from
        local check_path="$PWD"
        while [[ -n "$check_path" && "$check_path" != "/" ]]; do
            if grep -q "^${check_path//|/\\|}|" "$GH_PROJECT_CONFIG" 2>/dev/null; then
                assigned_from="$check_path"
                break
            fi
            check_path=$(dirname "$check_path")
        done
        
        if [[ "$assigned_from" != "$PWD" ]]; then
            echo "✓ Found assignment: $assigned_user (inherited from $assigned_from)"
        else
            echo "✓ Found assignment: $assigned_user"
        fi
    else
        # Fall back to old project-based lookup
        assigned_user=$(project_get_user "$current_repo" 2>/dev/null) || true
        [[ -n "$assigned_user" ]] && echo "✓ Found assignment: $assigned_user (project: $current_repo)"
    fi
    
    if [[ -z "$assigned_user" ]]; then
        echo "✗ No assignment found for this directory"
        echo "  Assign with: ghs assign <user>"
        return 0
    fi
    
    # Check current profile
    local current_email
    current_email=$(git config user.email 2>/dev/null || git config --global user.email 2>/dev/null)
    
    local profile
    if profile=$(profile_get "$assigned_user" 2>/dev/null); then
        local profile_email
        profile_email=$(profile_get_field "$profile" "email")
        
        if [[ "$profile_email" == "$current_email" ]]; then
            echo "✓ Current profile: $assigned_user (already active)"
            echo
            echo "Result: No switch needed"
        else
            echo "✓ Current profile: Different from assigned"
            echo
            echo "Result: Would switch to $assigned_user"
            echo "Run 'cd .' to trigger actual switch"
        fi
    else
        echo "✗ Profile missing for $assigned_user"
        echo "  Create with: ghs edit $assigned_user"
    fi
    
    # Check for git operations
    if git rev-parse --git-dir >/dev/null 2>&1; then
        if [[ -f ".git/rebase-merge/interactive" || -f ".git/MERGE_HEAD" || -f ".git/CHERRY_PICK_HEAD" ]]; then
            echo "✓ Git operation in progress - switch would be delayed"
        else
            echo "✓ No git operations in progress"
        fi
    fi
}

# Debug version of auto-switch check
auto_switch_check_debug() {
    echo "[DEBUG] Auto-switch check started"
    echo "[DEBUG] Current dir: $PWD"
    echo "[DEBUG] Environment:"
    echo "[DEBUG]   GHS_LAST_DIR: ${GHS_LAST_DIR:-<not set>}"
    echo "[DEBUG]   Auto-switch enabled: $(auto_switch_enabled && echo "yes" || echo "no")"
    
    # Check if enabled
    if ! auto_switch_enabled; then
        echo "[DEBUG] Auto-switch is not enabled, exiting"
        return 0
    fi
    
    # Check PWD change for Bash
    if [[ -n "${GHS_LAST_DIR:-}" && "$PWD" == "$GHS_LAST_DIR" ]]; then
        echo "[DEBUG] PWD hasn't changed (Bash optimization), exiting"
        return 0
    fi
    
    # Check git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "[DEBUG] Not in a git repository, exiting"
        return 0
    fi
    
    echo "[DEBUG] In git repository"
    
    # Check for git operations
    if [[ -f ".git/rebase-merge/interactive" || -f ".git/MERGE_HEAD" || -f ".git/CHERRY_PICK_HEAD" ]]; then
        echo "[DEBUG] Git operation in progress:"
        [[ -f ".git/rebase-merge/interactive" ]] && echo "[DEBUG]   - Interactive rebase"
        [[ -f ".git/MERGE_HEAD" ]] && echo "[DEBUG]   - Merge"
        [[ -f ".git/CHERRY_PICK_HEAD" ]] && echo "[DEBUG]   - Cherry-pick"
        echo "⚠️  Auto-switch delayed: git operation in progress"
        return 0
    fi
    
    echo "[DEBUG] No git operations in progress"
    
    # Look for assignment
    echo "[DEBUG] Looking for assignment..."
    local assigned_user=""
    
    # Try cache first
    local cached_user
    if cached_user=$(auto_switch_cache_read "$PWD" 2>/dev/null); then
        echo "[DEBUG]   Cache hit: $cached_user"
        assigned_user="$cached_user"
    else
        echo "[DEBUG]   Cache miss, checking config file"
        
        # Try path-based lookup
        if assigned_user=$(project_get_user_by_path "$PWD" 2>/dev/null); then
            echo "[DEBUG]   Found path-based assignment: $assigned_user"
            
            # Find which path it came from
            local check_path="$PWD"
            while [[ -n "$check_path" && "$check_path" != "/" ]]; do
                if grep -q "^${check_path//|/\\|}|" "$GH_PROJECT_CONFIG" 2>/dev/null; then
                    echo "[DEBUG]   Assigned from: $check_path"
                    break
                fi
                check_path=$(dirname "$check_path")
            done
        else
            # Try project-based lookup
            local current_repo
            current_repo=$(git_get_repo 2>/dev/null) || current_repo=$(basename "$PWD")
            echo "[DEBUG]   Checking project-based assignment for: $current_repo"
            
            if assigned_user=$(project_get_user "$current_repo" 2>/dev/null); then
                echo "[DEBUG]   Found project assignment: $assigned_user"
            else
                echo "[DEBUG]   No assignment found"
            fi
        fi
    fi
    
    if [[ -z "$assigned_user" ]]; then
        echo "[DEBUG] No user assigned to this directory"
        return 0
    fi
    
    # Check current profile
    echo "[DEBUG] Assigned user: $assigned_user"
    local current_email
    current_email=$(git config user.email 2>/dev/null || git config --global user.email 2>/dev/null)
    echo "[DEBUG] Current git email: ${current_email:-<not set>}"
    
    # Get profile
    local profile
    if ! profile=$(profile_get "$assigned_user" 2>/dev/null); then
        echo "[DEBUG] Profile not found for user: $assigned_user"
        echo "❌ Auto-switch failed: missing profile for $assigned_user"
        return 1
    fi
    
    local profile_email
    profile_email=$(profile_get_field "$profile" "email")
    echo "[DEBUG] Profile email: $profile_email"
    
    # Check if already on correct profile
    if [[ "$profile_email" == "$current_email" ]]; then
        echo "[DEBUG] Already on correct profile"
        return 0
    fi
    
    # Check for manual override
    if git config --local user.email >/dev/null 2>&1; then
        local manual_email
        manual_email=$(git config --local user.email)
        echo "[DEBUG] Found local git config: $manual_email"
        
        if [[ "$manual_email" != "$profile_email" ]]; then
            echo "[DEBUG] Manual override detected, not switching"
            echo "ℹ️  Skipping auto-switch: manual git config detected"
            echo "   Run 'ghs switch $assigned_user' to override"
            return 0
        fi
    fi
    
    # Perform the switch
    echo "[DEBUG] Performing switch to: $assigned_user"
    if profile_apply "$assigned_user" "local" >/dev/null 2>&1; then
        echo "[DEBUG] Switch successful"
        echo "🔄 Switched to $assigned_user (auto)"
    else
        echo "[DEBUG] Switch failed"
        echo "❌ Auto-switch failed for $assigned_user"
        return 1
    fi
}

# Perform the actual check and switch (called by shell hook)
auto_switch_check() {
    local quiet=false
    [[ "${1:-}" == "--quiet" ]] && quiet=true
    
    # Fast path: not enabled
    auto_switch_enabled || return 0
    
    # Fast path: Bash PWD hasn't changed (set by shell hook)
    if [[ -n "${GHS_LAST_DIR:-}" && "$PWD" == "$GHS_LAST_DIR" ]]; then
        return 0
    fi
    
    # Fast path: not in git repo
    git rev-parse --git-dir >/dev/null 2>&1 || return 0
    
    # Check for active git operations
    if [[ -f ".git/rebase-merge/interactive" || -f ".git/MERGE_HEAD" || -f ".git/CHERRY_PICK_HEAD" ]]; then
        [[ "$quiet" == "true" ]] || echo "⚠️  Auto-switch delayed: git operation in progress"
        return 0
    fi
    
    # Find assigned user using path-based lookup first
    local assigned_user=""
    assigned_user=$(project_get_user_by_path "$PWD" 2>/dev/null) || {
        # Fall back to old project-based lookup for backwards compatibility
        local current_repo
        current_repo=$(git_get_repo 2>/dev/null) || current_repo=$(basename "$PWD")
        assigned_user=$(project_get_user "$current_repo" 2>/dev/null) || true
    }
    
    # No assignment found
    [[ -z "$assigned_user" ]] && return 0
    
    # Check if already on correct profile
    local current_email
    current_email=$(git config user.email 2>/dev/null || git config --global user.email 2>/dev/null)
    
    local profile
    profile=$(profile_get "$assigned_user" 2>/dev/null) || return 0
    
    local profile_email
    profile_email=$(profile_get_field "$profile" "email")
    
    # Already on correct profile
    [[ "$profile_email" == "$current_email" ]] && return 0
    
    # Check for manual override
    if git config --local user.email >/dev/null 2>&1; then
        local manual_email
        manual_email=$(git config --local user.email)
        if [[ "$manual_email" != "$profile_email" ]]; then
            [[ "$quiet" == "true" ]] || {
                echo "ℹ️  Skipping auto-switch: manual git config detected"
                echo "   Run 'ghs switch $assigned_user' to override"
            }
            return 0
        fi
    fi
    
    # Perform the switch
    if profile_apply "$assigned_user" "local" >/dev/null 2>&1; then
        [[ "$quiet" == "true" ]] || echo "🔄 Switched to $assigned_user (auto)"
    else
        [[ "$quiet" == "true" ]] || echo "❌ Auto-switch failed for $assigned_user"
        return 1
    fi
}

# Status command
# Note: This function is ~67 lines, exceeding our 50-line guideline.
# We've reviewed and determined the length is justified by:
# 1. Multiple status checks (project, user, profile, git config)
# 2. Detailed mismatch reporting with current vs expected values
# 3. Helpful suggestions for fixing detected issues
# Each check provides distinct value and splitting would reduce clarity.
cmd_status() {
    # Check if any users are configured
    if [[ $(user_count) -eq 0 ]]; then
        echo "🎯 GitHub Project Switcher (ghs)"
        echo
        echo "Lightning-fast GitHub account switcher for developers"
        echo
        echo "📝 Quick start (3 steps):"
        echo "  1. ghs add current          # Auto-detect your GitHub account"
        echo "  2. ghs assign 1             # Use this account in current directory"
        echo "  3. ghs guard install        # Protect against wrong-account commits"
        echo
        echo "✨ Features:"
        echo "  • Guard hooks - Block commits with wrong GitHub account"
        echo "  • SSH key management - Auto-detect and validate SSH keys"
        echo "  • Quick switching - Change accounts in <100ms"
        echo "  • Project memory - Auto-switch by directory"
        echo "  • GitHub Enterprise - Full support for custom hosts"
        echo
        echo "Type 'ghs help' for all commands"
        return 0
    fi
    
    # Get current project and GitHub CLI user
    local project
    project=$(git_get_repo 2>/dev/null) || project=$(basename "$PWD")
    
    local gh_user
    gh_user=$(gh api user -q .login 2>/dev/null) || gh_user="Not authenticated"
    
    # Get current git config
    local current_git_email
    current_git_email=$(git config user.email 2>/dev/null || git config --global user.email 2>/dev/null)
    
    # Get assigned user for project
    local assigned_user=""
    assigned_user=$(project_get_user "$project" 2>/dev/null) || true
    
    # Display header
    echo "📍 Current project: $project"
    echo "🔐 GitHub CLI user: $gh_user"
    if auto_switch_enabled; then
        echo "🔄 Auto-switch: ENABLED"
    fi
    echo
    
    # Display users with flags
    echo "👥 Users:"
    local i=1
    local user_count=0
    while IFS= read -r username; do
        if [[ -n "$username" ]]; then
            user_count=$((user_count + 1))
            local flags=""
            
            # Check if this user is active (git config matches)
            local profile
            if profile=$(profile_get "$username" 2>/dev/null); then
                local profile_email
                profile_email=$(profile_get_field "$profile" "email")
                if [[ "$profile_email" == "$current_git_email" ]]; then
                    flags="$flags <active>"
                fi
                
                # Check for host
                local host
                host=$(profile_get_field "$profile" "host")
                if [[ -n "$host" && "$host" != "github.com" ]]; then
                    flags="$flags ($host)"
                fi
            fi
            
            # Check if assigned to this project
            if [[ "$username" == "$assigned_user" ]]; then
                flags="$flags <assigned>"
            fi
            
            printf "  %d. %-20s%s\n" "$i" "$username" "$flags"
            i=$((i + 1))
        fi
    done < "$GH_USERS_CONFIG"
    
    echo
    echo "⚡ Quick actions:"
    
    # Show contextual switch suggestion (don't suggest current active user)
    if [[ $user_count -gt 1 ]]; then
        # Find a user that isn't currently active
        local switch_suggestion=""
        local j=1
        while IFS= read -r other_user; do
            if [[ -n "$other_user" ]]; then
                local other_profile
                if other_profile=$(profile_get "$other_user" 2>/dev/null); then
                    local other_email
                    other_email=$(profile_get_field "$other_profile" "email")
                    if [[ "$other_email" != "$current_git_email" ]]; then
                        switch_suggestion="$j"
                        break
                    fi
                fi
                j=$((j + 1))
            fi
        done < "$GH_USERS_CONFIG"
        
        if [[ -n "$switch_suggestion" ]]; then
            echo "  ghs switch $switch_suggestion        # Switch to different account"
        fi
    elif [[ $user_count -eq 1 ]]; then
        echo "  ghs add current     # Add another GitHub account"
    fi
    
    # Show assign command if in a git repo and no assignment
    if git rev-parse --git-dir >/dev/null 2>&1 && [[ $user_count -gt 0 ]] && [[ -z "$assigned_user" ]]; then
        echo "  ghs assign <1-$user_count>    # Always use account X in this directory"
    fi
    
    # Show guard install only if in git repo and guards not installed
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local hook_file=".git/hooks/pre-commit"
        if [[ ! -f "$hook_file" ]] || ! grep -q "GHS_GUARD_HOOK" "$hook_file" 2>/dev/null; then
            echo "  ghs guard install   # Protect this repo from wrong-account commits"
        fi
    fi
    
    echo "  ghs help            # Show all commands"
    echo
    echo "Type 'ghs help' for all commands"
    
    return 0
}

# Doctor command - diagnostics for troubleshooting
cmd_doctor() {
    echo "🏥 gh-switcher diagnostics"
    echo "Shell: ${SHELL##*/} ${ZSH_VERSION:+v$ZSH_VERSION}${BASH_VERSION:+v$BASH_VERSION}"
    echo ""
    
    # Test critical commands
    echo "Critical commands:"
    for cmd in grep sed mktemp mv cp rm; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  ✅ $cmd: $(command -v "$cmd")"
        else
            echo "  ❌ $cmd: not found"
        fi
    done
    
    # Test for zsh path variable issue
    if [[ -n "$ZSH_VERSION" ]]; then
        echo ""
        echo "Zsh PATH safety check:"
        (
            local dir_path="/tmp"
            if command -v grep >/dev/null 2>&1; then
                echo "  ✅ PATH survives 'local dir_path' assignment"
            else
                echo "  ❌ PATH corrupted by local variable assignment!"
                echo "     This should be fixed in gh-switcher"
            fi
        )
    fi
    
    # Check configuration files
    echo ""
    echo "Configuration files:"
    for file in "$GH_USERS_CONFIG" "$GH_USER_PROFILES" "$GH_PROJECT_CONFIG"; do
        if [[ -f "$file" ]]; then
            echo "  ✅ $file exists"
        else
            echo "  ⚠️  $file missing (will be created on first use)"
        fi
    done
}

# Test SSH authentication command
# Note: This function is ~101 lines, exceeding our 50-line guideline.
# We've reviewed and determined the length is justified by:
# 1. Comprehensive option parsing for flexibility
# 2. Multiple validation steps with specific error handling
# 3. Detailed, actionable error messages for each failure mode
# The verbosity serves user experience, not complexity.
cmd_test_ssh() {
    local username=""
    local quiet=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quiet|-q)   
                quiet=true
                shift 
                ;;
            -*)
                echo "❌ Unknown option: $1" >&2
                echo "Usage: ghs test-ssh [<user>] [--quiet|-q]" >&2
                return 1
                ;;
            *)           
                if [[ -z "$username" ]]; then
                    username="$1"
                else
                    echo "❌ Too many arguments" >&2
                    echo "Usage: ghs test-ssh [<user>] [--quiet|-q]" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    # Default to current user if not specified
    if [[ -z "$username" ]]; then
        username=$(gh api user -q .login 2>/dev/null) || {
            [[ "$quiet" == "true" ]] && return 1
            echo "❌ No current user set"
            echo "   Use 'ghs switch <user>' to set current user"
            return 1
        }
    fi
    
    # Get profile and host
    local profile ssh_key host
    profile=$(profile_get "$username") || {
        [[ "$quiet" == "true" ]] && return 1
        echo "❌ User not found: $username"
        return 1
    }
    
    ssh_key=$(profile_get_field "$profile" "ssh_key")
    host=$(profile_get_field "$profile" "host")
    [[ -z "$host" ]] && host="github.com"
    
    if [[ -z "$ssh_key" ]]; then
        [[ "$quiet" == "true" ]] && return 0
        echo "ℹ️  No SSH key configured for $username"
        echo "   This profile uses HTTPS authentication"
        return 0
    fi
    
    # Check if SSH key exists
    if [[ ! -f "$ssh_key" ]]; then
        [[ "$quiet" == "true" ]] && return 1
        echo "❌ SSH key not found: ${ssh_key/#$HOME/~}"
        echo "   Run 'ghs show $username' for suggestions"
        return 1
    fi
    
    [[ "$quiet" != "true" ]] && {
        echo "🔐 Testing SSH authentication for $username..."
        echo "   Host: $host"
        echo "   Key: ${ssh_key/#$HOME/~}"
    }
    
    local exit_code
    test_ssh_auth "$ssh_key" "$host"
    exit_code=$?
    
    [[ "$quiet" == "true" ]] && return $exit_code
    
    case "$exit_code" in
        0)
            echo "✅ SSH authentication successful"
            echo "   GitHub recognizes this key"
            ;;
        1)
            echo "❌ SSH authentication failed"
            echo
            echo "   GitHub rejected this SSH key. To fix:"
            echo "   1. Copy your public key: cat ${ssh_key}.pub | pbcopy"
            echo "   2. Add it to GitHub: https://github.com/settings/keys"
            echo "   3. Test again: ghs test-ssh $username"
            ;;
        2)
            echo "⚠️  Network issue - cannot reach GitHub"
            echo
            echo "   Possible causes:"
            echo "   • No internet connection"
            echo "   • GitHub is down (check https://githubstatus.com)"
            echo "   • Firewall blocking SSH port 22"
            echo
            echo "   Try: ssh -T git@github.com -p 443 (uses HTTPS port)"
            ;;
    esac
    
    return $exit_code
}

# Guard hooks command
cmd_guard() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        install)
            guard_install
            ;;
        uninstall)
            guard_uninstall
            ;;
        status)
            guard_status
            ;;
        test)
            guard_test
            ;;
        *)
            echo "🛡️  GitHub Guard Hooks - Prevent Wrong-Account Commits"
            echo
            echo "Guard hooks protect you from accidentally committing with the wrong GitHub"
            echo "account. When installed, they check before each commit that your current"
            echo "git config matches the GitHub account assigned to this project."
            echo
            echo "Usage: ghs guard <subcommand>"
            echo
            echo "Subcommands:"
            echo "  install     Install pre-commit hook for this repository"
            echo "              The hook will verify your GitHub account before each commit"
            echo "  uninstall   Remove guard hooks from current repository"
            echo "              Disables account verification for this repo"
            echo "  status      Check if guard hooks are installed and working"
            echo "              Shows current protection status for this repo"
            echo "  test        Simulate what would happen on commit"
            echo "              Useful for debugging without actually committing"
            echo
            echo "How it works:"
            echo "  1. You assign a GitHub account to a project: ghs assign alice"
            echo "  2. You install guard hooks: ghs guard install"
            echo "  3. Before each commit, the hook verifies you're using account 'alice'"
            echo "  4. If there's a mismatch, the commit is blocked with a helpful message"
            echo
            echo "Examples:"
            echo "  ghs guard install   # Start protecting this repo"
            echo "  ghs guard test      # Check if your next commit would be allowed"
            echo "  ghs guard status    # See current protection status"
            echo
            echo "💡 Tip: Install guards on all work repos to prevent personal commits!"
            return 0
            ;;
    esac
}

# Help command
cmd_help() {
    cat << 'EOF'
🎯 GitHub Project Switcher (ghs)

USAGE:
  ghs <command> [options]

COMMANDS:
  add <user|current>  Add GitHub account ('current' auto-detects from gh CLI)
  remove <user>       Remove account by name or number
  switch <user>       Change active git config to different account
  assign <user>       Auto-switch to this account in current directory
  assign --list       List all directory assignments
  assign --remove     Remove assignment for current or specified path
  assign --clean      Clean up non-existent paths
  users               List all accounts with SSH/HTTPS status
  show <user>         View account details and diagnose issues      [NEW]
  edit <user>         Update email, SSH key, or host settings      [NEW]
  test-ssh [<user>]   Verify SSH key works with GitHub            [NEW]
  status              Show current account and project state (default)
  doctor              Show diagnostics for troubleshooting
  guard               Prevent wrong-account commits (see 'ghs guard')
  auto-switch         Automatic profile switching by directory      [NEW]
  fish-setup          Set up gh-switcher for Fish shell            [NEW]
  help                Show this help message

OPTIONS:
  --ssh-key <path>      Specify SSH key for add command
  --host <domain>       Specify GitHub host (default: github.com)

EXAMPLES:
  ghs add current                             Add currently authenticated GitHub user
  ghs add alice                               Add specific user  
  ghs add bob --ssh-key ~/.ssh/id_rsa_work    Add user with SSH key
  ghs add work --host github.company.com      Add enterprise user
  ghs edit alice --host github.enterprise.com
  ghs switch 1
  ghs assign alice
  ghs status

AUTO-SWITCHING:
  ghs auto-switch enable     Turn on automatic profile switching
  ghs auto-switch test       Preview what would happen in current directory
  ghs auto-switch status     Check configuration and assigned directories
EOF
    return 0
}

# Fish shell setup command
cmd_fish_setup() {
    echo "🐟 Setting up gh-switcher for Fish shell..."
    echo
    
    # Get the actual path to this script
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    # Check if Fish is installed
    if ! command -v fish >/dev/null 2>&1; then
        echo "❌ Fish shell is not installed"
        echo "   Install Fish first: https://fishshell.com"
        return 1
    fi
    
    # Create the Fish function
    local fish_functions_dir="$HOME/.config/fish/functions"
    mkdir -p "$fish_functions_dir"
    
    cat > "$fish_functions_dir/ghs.fish" << EOF
function ghs
    set -l script_path '$script_path'
    if not test -f "\$script_path"
        echo "Error: gh-switcher.sh not found at \$script_path" >&2
        echo "Please run 'ghs fish-setup' again to update the path" >&2
        return 1
    end
    bash -c "source '\$script_path' && ghs \\\$argv"
end
EOF
    
    echo "✅ Fish function created at: $fish_functions_dir/ghs.fish"
    echo "   Using gh-switcher at: $script_path"
    echo
    echo "📋 Next steps:"
    echo "   1. Start a new Fish session or run: source $fish_functions_dir/ghs.fish"
    echo "   2. Test with: ghs --help"
    echo
    echo "For tab completions and more info, see: docs/FISH_SETUP.md"
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

# Main entry point - pure dispatcher
ghs() {
    local cmd="${1:-status}"
    shift 2>/dev/null || true
    
    # Strip out anything that isn't alphanumeric, dash, or underscore
    cmd="${cmd//[^a-zA-Z0-9_-]/}"
    
    # Initialize configuration
    init_config
    
    # VS Code terminal detection and warning (skip in test environments)
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]] && [[ -z "${GHS_VSCODE_WARNING_SHOWN:-}" ]] && [[ -z "${BATS_TEST_FILENAME:-}" ]]; then
        export GHS_VSCODE_WARNING_SHOWN=1
        echo "ℹ️  VS Code Terminal Detected"
        echo "   gh-switcher cannot be fully tested in VS Code's integrated terminal."
        echo "   If you experience issues, please report them at:"
        echo "   https://github.com/seconds-0/gh-switcher/issues"
        echo
    fi
    
    case "$cmd" in
        add)              cmd_add "$@" ;;
        remove|rm)        cmd_remove "$@" ;;
        switch|sw)        cmd_switch "$@" ;;
        assign)           cmd_assign "$@" ;;
        users|list)       cmd_users "$@" ;;
        show|profile)     cmd_show "$@" ;;      # NEW
        edit)             cmd_edit "$@" ;;       # NEW
        test-ssh)         cmd_test_ssh "$@" ;;   # NEW
        auto-switch)      cmd_auto_switch "$@" ;; # NEW
        status)           cmd_status "$@" ;;
        doctor)           cmd_doctor ;;
        guard)            cmd_guard "$@" ;;
        fish-setup)       cmd_fish_setup ;;      # NEW - Fish shell setup
        help|--help|-h)   cmd_help ;;
        *)                
            echo "❌ Unknown command: $cmd"
            echo "Try 'ghs help' for usage information"
            return 1 
            ;;
    esac
}



# Export main function
# Export function for bash (zsh doesn't support export -f)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f ghs
fi

# If script is executed directly, run with all arguments
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
    ghs "$@"
fi