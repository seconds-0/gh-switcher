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

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly GH_USERS_CONFIG="${GH_USERS_CONFIG:-$HOME/.gh-users}"
readonly GH_USER_PROFILES="${GH_USER_PROFILES:-$HOME/.gh-user-profiles}"
readonly GH_PROJECT_CONFIG="${GH_PROJECT_CONFIG:-$HOME/.gh-project-accounts}"

# Initialize configuration files
init_config() {
    [[ -f "$GH_USERS_CONFIG" ]] || touch "$GH_USERS_CONFIG"
    [[ -f "$GH_USER_PROFILES" ]] || touch "$GH_USER_PROFILES"
    [[ -f "$GH_PROJECT_CONFIG" ]] || touch "$GH_PROJECT_CONFIG"
}

# =============================================================================
# FILE UTILITIES
# =============================================================================

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
    local temp_file="${filepath}.tmp.$$"
    
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
        echo "❌ Email must contain @" >&2
        return 1
    fi
    
    return 0
}

# Validate no pipes in field (pipes are field separators)
_validate_no_pipes() {
    local field="$1"
    local field_name="$2"
    
    if [[ "$field" == *"|"* ]]; then
        echo "❌ Pipes (|) not allowed in $field_name" >&2
        echo "   Pipes are used as field separators in profile storage" >&2
        echo "   If you need pipes in your data, please open an issue:" >&2
        echo "   https://github.com/seconds-0/gh-switcher/issues" >&2
        return 1
    fi
    return 0
}

# Validate SSH key file
validate_ssh_key() {
    local key_path="$1"
    local fix_perms="${2:-false}"
    
    # Empty path is valid (HTTPS mode)
    [[ -z "$key_path" ]] && return 0
    
    # Expand tilde first
    key_path="${key_path/#~/$HOME}"
    
    # Check for directory traversal and suspicious patterns
    if [[ "$key_path" =~ \.\. ]] || [[ "$key_path" =~ /\.\./ ]] || [[ "$key_path" =~ ^/ && "$key_path" =~ /\. ]]; then
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
    
    file_append_line "$GH_USERS_CONFIG" "$username"
    return 0
}

# Remove user from configuration
user_remove() {
    local username="$1"
    
    validate_username "$username" || return 1
    user_exists "$username" || return 1
    
    file_remove_line "$GH_USERS_CONFIG" "$username"
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
    
    # Format: username|v3|name|email|ssh_key
    printf "%s|v3|%s|%s|%s\n" "$username" "$name" "$email" "$ssh_key" >> "$file"
}

# Write a profile entry (compatibility wrapper)
write_profile_entry() {
    local username="$1"
    local name="$2"
    local email="$3"
    local ssh_key="${4:-}"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$GH_USER_PROFILES")"
    
    # Write to global profile file
    _write_profile_entry_to_file "$GH_USER_PROFILES" "$username" "$name" "$email" "$ssh_key"
}

# Create user profile
profile_create() {
    local username="$1"
    local name="${2:-$username}"
    local email="${3:-$username@users.noreply.github.com}"
    local ssh_key="${4:-}"
    
    # Validate inputs
    validate_username "$username" || return 1
    _validate_field_length "$name" "Name" 200 || return 1
    _validate_email "$email" || return 1
    
    # Validate no pipes in fields (pipes are field separators)
    _validate_no_pipes "$name" "name" || return 1
    _validate_no_pipes "$email" "email" || return 1
    [[ -n "$ssh_key" ]] && { _validate_no_pipes "$ssh_key" "SSH key path" || return 1; }
    
    # Note: SSH key path validation happens in validate_ssh_key later
    
    # Create temp file for atomic update
    local temp_file
    temp_file=$(mktemp "${GH_USER_PROFILES}.XXXXXX") || return 1
    
    # Copy existing profiles except the one we're updating
    if [[ -f "$GH_USER_PROFILES" ]]; then
        grep -v "^${username}|" "$GH_USER_PROFILES" > "$temp_file" || true
    fi
    
    # Add new profile entry
    _write_profile_entry_to_file "$temp_file" "$username" "$name" "$email" "$ssh_key"
    
    # Atomic replace
    mv -f "$temp_file" "$GH_USER_PROFILES"
    
    return 0
}

# Get user profile
profile_get() {
    local username="$1"
    
    validate_username "$username" || return 1
    [[ -f "$GH_USER_PROFILES" ]] || return 1
    
    local profile_line
    profile_line=$(grep "^${username}|" "$GH_USER_PROFILES" | head -1)
    [[ -n "$profile_line" ]] || return 1
    
    # Parse v3 profile line: username|v3|name|email|ssh_key
    local field_count
    field_count=$(echo "$profile_line" | tr '|' '\n' | wc -l)
    if [[ "$field_count" -ne 5 ]]; then
        echo "❌ Invalid profile format for $username" >&2
        return 1
    fi
    
    local name email ssh_key
    IFS='|' read -r _ _ name email ssh_key <<< "$profile_line"
    
    echo "name:$name"
    echo "email:$email"
    echo "ssh_key:$ssh_key"
}

# Apply profile to git config
profile_apply() {
    local username="$1"
    local scope="${2:-local}"
    
    
    local profile
    profile=$(profile_get "$username") || return 1
    
    # Parse profile once using single read
    local name email ssh_key
    while IFS=: read -r key value; do
        case "$key" in
            name) name="$value" ;;
            email) email="$value" ;;
            ssh_key) ssh_key="$value" ;;
        esac
    done <<< "$profile"
    
    git_set_config "$name" "$email" "$scope" || return 1
    
    if [[ -n "$ssh_key" ]]; then
        ssh_apply_config "$ssh_key" "$scope" || return 1
        echo "✅ Configured SSH key: $ssh_key"
    fi
    
    echo "✅ Updated ${scope} git config for $username"
    return 0
}

# Remove user profile
profile_remove() {
    local username="$1"
    
    validate_username "$username" || return 1
    
    
    [[ -f "$GH_USER_PROFILES" ]] || return 1
    
    # Create temp file for atomic update
    local temp_file
    temp_file=$(mktemp "${GH_USER_PROFILES}.XXXXXX") || return 1
    
    # Copy all profiles except the one being removed
    grep -v "^${username}|" "$GH_USER_PROFILES" > "$temp_file" || true
    
    # Atomic replace
    mv -f "$temp_file" "$GH_USER_PROFILES"
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
    
    # Create hook with explicit path or search strategy
    cat > "$hook_file" << EOF
#!/bin/bash
# GHS_GUARD_HOOK
[[ "\$GHS_SKIP_HOOK" == "1" ]] && exit 0

# Try to find ghs in common locations
GHS_CMD=""
if command -v ghs >/dev/null 2>&1; then
    GHS_CMD="ghs"
elif [[ -x "$ghs_path" ]]; then
    GHS_CMD="$ghs_path"
elif [[ -x /usr/local/bin/ghs ]]; then
    GHS_CMD="/usr/local/bin/ghs"
elif [[ -x ~/.local/bin/ghs ]]; then
    GHS_CMD=~/.local/bin/ghs
elif [[ -x ~/bin/ghs ]]; then
    GHS_CMD=~/bin/ghs
fi

if [[ -z "\$GHS_CMD" ]]; then
    echo "⚠️  ghs not found in PATH or common locations"
    echo "   Please ensure ghs is installed and in your PATH"
    exit 0
fi

"\$GHS_CMD" guard test || { echo; echo "💡 To bypass: GHS_SKIP_HOOK=1 git commit ..."; exit 1; }
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
    local ssh_key=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    [[ -n "$ssh_key" ]]
}

# =============================================================================
# COMMAND HANDLERS
# =============================================================================

# Add user command
cmd_add() {
    local username="${1:-}"
    local ssh_key=""
    
    # Parse options
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh-key) ssh_key="$2"; shift 2 ;;
            *)         
                echo "❌ Unknown option: $1" >&2
                echo "Usage: ghs add-user <username> [--ssh-key <path>]" >&2
                return 1
                ;;
        esac
    done
    
    # Validate input
    if [[ -z "$username" ]]; then
        echo "❌ Username required" >&2
        echo "Usage: ghs add-user <username> [--ssh-key <path>]" >&2
        return 1
    fi
    
    if ! validate_username "$username"; then
        echo "❌ Invalid username format" >&2
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
    fi
    
    # Add user and create profile
    if user_add "$username" && profile_create "$username" "$username" "${username}@users.noreply.github.com" "$ssh_key"; then
        echo "✅ Added $username to user list"
        [[ -n "$ssh_key" ]] && echo "🔐 SSH key: $ssh_key"
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

# Assign user to project command
cmd_assign() {
    local input="$1"
    local project="${2:-$(basename "$PWD")}"
    
    if [[ -z "$input" ]]; then
        echo "❌ Username or ID required" >&2
        echo "Usage: ghs assign <username_or_id>" >&2
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
    
    # Assign user to project
    if project_assign "$username" "$project"; then
        echo "✅ Assigned $username to project: $project"
    else
        echo "❌ Failed to assign user to project" >&2
        return 1
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
            if user_has_ssh_key "$username"; then
                profile_info=" [SSH]"
            else
                profile_info=" [HTTPS]"
            fi
            echo "  $i. $username$profile_info"
            ((i++))
        fi
    done < "$GH_USERS_CONFIG"
    return 0
}

# Status command
cmd_status() {
    local project
    project=$(git_get_repo 2>/dev/null) || project=$(basename "$PWD")
    
    echo "📍 Current project: $project"
    
    # Show assigned user for project
    local assigned_user
    if assigned_user=$(project_get_user "$project" 2>/dev/null); then
        echo "👤 Assigned user: $assigned_user"
        
        # Check if git config matches profile
        if profile=$(profile_get "$assigned_user" 2>/dev/null); then
            local profile_name profile_email current_config
            profile_name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
            profile_email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
            
            if current_config=$(git_get_config "local" 2>/dev/null); then
                local current_name current_email
                current_name=$(echo "$current_config" | grep "^name:" | cut -d':' -f2-)
                current_email=$(echo "$current_config" | grep "^email:" | cut -d':' -f2-)
                
                if [[ "$current_name" == "$profile_name" && "$current_email" == "$profile_email" ]]; then
                    echo "✅ Git config matches assigned user"
                else
                    echo "⚠️  Git config mismatch"
                    echo "   Current: $current_name <$current_email>"
                    echo "   Expected: $profile_name <$profile_email>"
                fi
            else
                echo "❌ Git config not set"
            fi
        fi
    else
        echo "👤 No user assigned to this project"
        echo "   Use 'ghs assign <user>' to assign a user"
    fi
    return 0
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
            echo "🛡️  GitHub Guard Hooks"
            echo
            echo "Usage: ghs guard <subcommand>"
            echo
            echo "Subcommands:"
            echo "  install     Install guard hooks for current repository"
            echo "  uninstall   Remove guard hooks from current repository"
            echo "  status      Check guard hook installation status"
            echo "  test        Test guard validation without installing"
            echo
            echo "Examples:"
            echo "  ghs guard install   # Install protection for this repo"
            echo "  ghs guard test      # Test if validation would pass"
            echo "  ghs guard status    # Check current protection status"
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
  add <username>        Add a new user
  remove <user>         Remove user by name or ID
  switch <user>         Switch to user by name or ID
  assign <user>         Assign user to current project
  users                 List all configured users
  status                Show current project status
  guard <subcommand>    Manage guard hooks for account validation
  help                  Show this help

OPTIONS:
  --ssh-key <path>      Specify SSH key for add command

EXAMPLES:
  ghs add alice
  ghs add bob --ssh-key ~/.ssh/id_rsa_work
  ghs switch 1
  ghs assign alice
  ghs status
EOF
    return 0
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

# Main entry point - pure dispatcher
ghs() {
    local cmd="${1:-status}"
    shift 2>/dev/null || true
    
    # Initialize configuration
    init_config
    
    case "$cmd" in
        add)              cmd_add "$@" ;;
        remove|rm)        cmd_remove "$@" ;;
        switch|sw)        cmd_switch "$@" ;;
        assign)           cmd_assign "$@" ;;
        users|list)       cmd_users "$@" ;;
        status)           cmd_status "$@" ;;
        guard)            cmd_guard "$@" ;;
        help|--help|-h)   cmd_help ;;
        *)                cmd_help; return 1 ;;
    esac
}



# Export main function
export -f ghs

# If script is executed directly, run with all arguments
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
    ghs "$@"
fi