#!/bin/bash

# 🎯 Simple GitHub Project Switcher
# Lightweight, secure project-specific GitHub account switching
# 
# Usage: 
#   ghs                    # Switch to project account or show status
#   ghs set <username>     # Set account for current project
#   ghs list              # Show configured projects
#   ghs status            # Show current status
#
# Installation:
#   1. Source this file in your ~/.zshrc or ~/.bashrc:
#      echo "source $(realpath "$0")" >> ~/.zshrc
#   2. Restart terminal or run: source ~/.zshrc
#   3. Use 'ghs' command in your projects
#
# TESTING STRATEGY:
# Comprehensive test comments are embedded throughout this codebase 
# to guide future test implementation. See Documentation/Plans/TEST-ComprehensiveTestPlan.md
# for complete testing requirements. Key areas requiring tests:
# Total: 15+ test functions covering 100+ test cases

# Configuration paths
GH_PROJECT_CONFIG="$HOME/.gh-project-accounts"
GH_USERS_CONFIG="$HOME/.gh-users"
GH_USER_PROFILES="$HOME/.gh-user-profiles"

# =====================
# V3 PROFILE HELPERS (Simplified plain-text format)
# Format: username:name:email[:gpg_key][:auto_sign]
# =====================

# Validate individual field against minimal rules (see plan)
validate_profile_field() {
    local field_name="$1"; local value="$2"
    
    # Reject control characters in all fields
    if [[ "$value" =~ [[:cntrl:]] ]]; then
        return 1
    fi
    
    case "$field_name" in
        username)
            [[ "$value" =~ ^[A-Za-z0-9-]{1,39}$ ]] || return 1
            ;;
        name)
            [[ "$value" != *":"* && ${#value} -le 255 ]] || return 1
            ;;
        email)
            [[ "$value" == *"@"* && "$value" == *"."* && "$value" != *":"* && "$value" != *" "* ]] || return 1
            ;;
        gpg_key)
            [[ -z "$value" || "$value" =~ ^[A-F0-9]{8,40}$ ]] || return 1
            ;;
        auto_sign)
            [[ -z "$value" || "$value" == "true" || "$value" == "false" ]] || return 1
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# Parse a single v3 profile line and emit key:value pairs
parse_profile_line_v3() {
    local line="$1"
    IFS=':' read -r username name email gpg_key auto_sign <<<"$line"
    # Basic sanity check
    if [[ -z "$username" || -z "$name" || -z "$email" ]]; then
        return 1
    fi
    echo "username:$username"
    echo "name:$name"
    echo "email:$email"
    echo "gpg_key:${gpg_key:-}"
    echo "auto_sign:${auto_sign:-}"
    echo "version:3"
}

# Atomic writer for v3 format (wrapper around simplified validation)
write_profile_entry_v3() {
    local username="$1"; local name="$2"; local email="$3"; local gpg_key="${4:-}"; local auto_sign="${5:-}"

    # Validate fields
    for f in username name email gpg_key auto_sign; do
        local val="${!f}"
        if ! validate_profile_field "$f" "$val"; then
            echo "❌ Invalid $f value"
            return 1
        fi
    done

    # Ensure profile dir exists
    mkdir -p "$(dirname "$GH_USER_PROFILES")" 2>/dev/null || true

    local temp="${GH_USER_PROFILES}.tmp.$$"
    trap 'rm -f "$temp"' EXIT

    # Remove old entry if exists, write others untouched
    if [[ -f "$GH_USER_PROFILES" ]]; then
        grep -v "^$username:" "$GH_USER_PROFILES" > "$temp" || true
    fi

    # Build line (maintain 5 colon positions even for missing optional fields)
    local line="$username:$name:$email:$gpg_key:$auto_sign"
    echo "$line" >> "$temp"

    chmod 600 "$temp"
    mv "$temp" "$GH_USER_PROFILES"
    trap - EXIT
    return 0
}

# Minimal base64 encode shim for legacy v1/v2 profiles (ensures no colons in output)
encode_profile_value() {
    # Encode value into Base64 **without** any line wrapping so that profile lines remain single-line across platforms.
    # We pipe through tr -d '\n' to strip the trailing newline as well as any internal wraps (BSD and GNU base64 compatibility).
    printf '%s' "$1" | base64 | tr -d '\n'
}

# Minimal base64 decode shim for legacy v1/v2 profiles
decode_profile_value() {
    printf '%s' "$1" | base64 --decode 2>/dev/null
}

# Helper function to add a user to the global list
add_user() {
    local username=""; local ssh_key=""

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh-key)
                ssh_key="$2"; shift 2;;
            --*)
                echo "❌ Unknown option: $1" >&2; return 1;;
            *)
                if [[ -z "$username" ]]; then
                    username="$1"; shift;
                else
                    echo "❌ Unknown argument: $1" >&2; return 1;
                fi;;
        esac
    done

    if [[ -z "$username" ]]; then
        echo "❌ Usage: ghs add-user <username> [--ssh-key <path>]" >&2
        return 1
    fi

    # Validate username format
    if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "❌ Invalid username format" >&2
        return 1
    fi

    # Handle special "current" keyword (unchanged)
    if [[ "$username" == "current" ]]; then
        if check_gh_auth; then
            username=$(get_current_github_user)
            if [[ -z "$username" ]]; then
                echo "❌ Could not detect current GitHub user" >&2
                return 1
            fi
            echo "💡 Adding current GitHub user: $username"
        else
            echo "❌ GitHub CLI not authenticated or not installed" >&2
            return 1
        fi
    fi

    # Deduplicate
    if [[ -f "$GH_USERS_CONFIG" ]] && grep -q "^$username$" "$GH_USERS_CONFIG" 2>/dev/null; then
        echo "⚠️  User $username already exists in the list"
    else
        echo "$username" >> "$GH_USERS_CONFIG"
        echo "✅ Added $username to user list"
    fi

    # Validate SSH key (warnings allowed)
    if [[ -n "$ssh_key" ]]; then
        if ! validate_ssh_key "$ssh_key" "true"; then
            echo "⚠️  SSH key validation failed but continuing"
            ssh_key="" # Clear invalid key
        fi
    fi

    # Create or update profile
    create_user_profile "$username" "" "" "false" "$ssh_key"

    # Show list
    list_users
}

# Helper function to extract field from profile data (reduces duplication)
field() {
    local data="$1"
    local field_name="$2"
    echo "$data" | grep "^$field_name:" | cut -d':' -f2-
}

# Helper function to get current GitHub username (cached for performance)
get_current_github_user() {
    # Use global cache if available and recent
    if [[ -n "${_GH_CURRENT_USER_CACHE:-}" ]]; then
        echo "$_GH_CURRENT_USER_CACHE"
        return 0
    fi
    
    # Fetch and cache
    if check_gh_auth; then
        _GH_CURRENT_USER_CACHE=$(gh api user --jq '.login' 2>/dev/null || echo "")
        echo "$_GH_CURRENT_USER_CACHE"
        return 0
    else
        echo ""
        return 1
    fi
}

# Helper function to clear GitHub user cache (call when switching users)
clear_github_user_cache() {
    unset _GH_CURRENT_USER_CACHE
}

# Helper function to list all users with numbers
list_users() {
    if [[ ! -f "$GH_USERS_CONFIG" || ! -s "$GH_USERS_CONFIG" ]]; then
        echo "📋 No users configured yet"
        echo "   Use 'ghs add-user <username>' to add users"
        return 0
    fi
    
    echo "📋 Available users:"
    local i=1
    
    # Get current user once for the entire loop
    local current_user=""
    if check_gh_auth; then
        current_user=$(get_current_github_user)
    fi
    
    while IFS= read -r username; do
        if [[ -n "$username" ]]; then
            # Determine SSH/HTTPS status
            local profile_status=""
            local profile_line="$(get_user_profile "$username" 2>/dev/null)"
            if [[ -n "$profile_line" ]]; then
                local ssh_key_field=$(echo "$profile_line" | grep "^ssh_key:" | cut -d':' -f2-)
                if [[ -n "$ssh_key_field" ]]; then
                    profile_status=" [SSH: $ssh_key_field]"
                else
                    profile_status=" [HTTPS]"
                fi
            fi

            if [[ "$username" == "$current_user" ]]; then
                echo "  ✅ $i. $username$profile_status (current)"
            else
                echo "     $i. $username$profile_status"
            fi
            ((i++))
        fi
    done < "$GH_USERS_CONFIG"
}

# Helper function to get username by ID number
get_user_by_id() {
    local user_id="$1"
    
    if [[ ! "$user_id" =~ ^[0-9]+$ ]]; then
        echo "❌ Invalid user ID. Must be a number."
        return 1
    fi
    
    if [[ ! -f "$GH_USERS_CONFIG" || ! -s "$GH_USERS_CONFIG" ]]; then
        echo "❌ No users configured. Use 'ghs users' to see available users."
        return 1
    fi
    
    local username=$(sed -n "${user_id}p" "$GH_USERS_CONFIG")
    if [[ -z "$username" ]]; then
        echo "❌ User ID $user_id not found. Use 'ghs users' to see available users."
        return 1
    fi
    
    echo "$username"
}

# Helper function to check if git is available and working
check_git_availability() {
    if ! command -v git >/dev/null 2>&1; then
        return 1
    fi
    
    # Test if git works by checking version
    if ! git --version >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Helper function to check GitHub CLI authentication (DRY)
check_gh_auth() {
    command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

# Helper function to detect shell profile (DRY)
detect_shell_profile() {
    if [[ "$SHELL" == *zsh* ]] || [[ -n "$ZSH_VERSION" ]]; then
        echo "$HOME/.zshrc"
        return 0
    elif [[ "$SHELL" == *bash* ]] || [[ -n "$BASH_VERSION" ]]; then
        echo "$HOME/.bashrc"
        return 0
    else
        return 1
    fi
}

# Helper function to check if input is a numeric user ID (focused validation)
is_numeric_user_id() {
    local input="$1"
    [[ "$input" =~ ^[0-9]+$ ]]
}

# Helper function to resolve current user (focused current user logic)
resolve_current_user() {
    if check_gh_auth; then
        get_current_github_user
    else
        echo "❌ GitHub CLI not authenticated or not installed" >&2
        return 1
    fi
}

# Helper function to resolve user input to username (clean orchestration)
resolve_user_by_input() {
    local user_input="$1"
    
    if [[ "$user_input" == "current" ]]; then
        resolve_current_user
    elif is_numeric_user_id "$user_input"; then
        get_user_by_id "$user_input"
    else
        echo "$user_input"
    fi
}

# Helper function to detect current git configuration with comprehensive fallbacks
detect_git_config() {
    local scope="${1:-local}"  # 'local', 'global', or 'auto'
    
    if ! check_git_availability; then
        return 1
    fi
    
    local git_name=""
    local git_email=""
    
    if [[ "$scope" == "global" ]]; then
        # Only check global config
        git_name=$(git config --global --get user.name 2>/dev/null || echo "")
        git_email=$(git config --global --get user.email 2>/dev/null || echo "")
    elif [[ "$scope" == "local" ]]; then
        # Only check local config (repository-specific)
        git_name=$(git config --local --get user.name 2>/dev/null || echo "")
        git_email=$(git config --local --get user.email 2>/dev/null || echo "")
    else
        # Auto mode: check local first, then global, then system
        git_name=$(git config --get user.name 2>/dev/null || echo "")
        git_email=$(git config --get user.email 2>/dev/null || echo "")
    fi
    
    # Validate that we got actual values (not just empty strings)
    if [[ -z "$git_name" && -z "$git_email" ]]; then
        # If nothing found and we were looking for local, try global as fallback
        if [[ "$scope" == "local" ]]; then
            git_name=$(git config --global --get user.name 2>/dev/null || echo "")
            git_email=$(git config --global --get user.email 2>/dev/null || echo "")
        fi
    fi
    
    echo "name:$git_name"
    echo "email:$git_email"
    return 0
}

# Helper function to detect git configuration (consolidated)
detect_git_config_extended() {
    local scope="${1:-auto}"  # 'local', 'global', or 'auto'
    
    if ! check_git_availability; then
        return 1
    fi
    
    local git_flags=""
    
    if [[ "$scope" == "global" ]]; then
        git_flags="--global"
    elif [[ "$scope" == "local" ]]; then
        git_flags="--local"
    # else auto mode - no flags, git uses its own precedence
    fi
    
    # Get all relevant config in one go
    local name=$(git config $git_flags --get user.name 2>/dev/null || echo "")
    local email=$(git config $git_flags --get user.email 2>/dev/null || echo "")
    local gpg_key=$(git config $git_flags --get user.signingkey 2>/dev/null || echo "")
    local auto_sign=$(git config $git_flags --get commit.gpgsign 2>/dev/null || echo "")
    
    # Convert auto_sign to boolean
    if [[ "$auto_sign" == "true" ]]; then
        auto_sign="true"
    else
        auto_sign="false"
    fi
    
    # Output structured data
    echo "name:$name"
    echo "email:$email"
    echo "gpg_key:$gpg_key"
    echo "auto_sign:$auto_sign"
    
    return 0
}

# Helper function to detect GPG signing key (backward compatibility wrapper)
detect_gpg_key() {
    local scope="${1:-auto}"
    local config=$(detect_git_config_extended "$scope")
    if [[ $? -eq 0 ]]; then
        echo "$config" | grep "^gpg_key:" | cut -d':' -f2-
        return 0
    fi
    return 1
}

# Helper function to detect auto-sign preference (backward compatibility wrapper)
detect_auto_sign() {
    local scope="${1:-auto}"
    local config=$(detect_git_config_extended "$scope")
    if [[ $? -eq 0 ]]; then
        echo "$config" | grep "^auto_sign:" | cut -d':' -f2-
        return 0
    fi
    return 1
}

# Helper function to validate GPG key
validate_gpg_key() {
    local gpg_key="$1"
    
    if [[ -z "$gpg_key" ]]; then
        return 0  # Empty is valid (no GPG)
    fi
    
    # Check if gpg command is available
    if ! command -v gpg >/dev/null 2>&1; then
        return 1  # GPG not available
    fi
    
    # Check if key exists in keyring
    if gpg --list-secret-keys "$gpg_key" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# (DELETED: validate_profile_input removed in v3 simplification)

# (DELETED: encode/decode functions removed in v3 simplification)

# Helper function to write profile safely
write_profile_entry() {
    local username="$1"; local name="$2"; local email="$3"; local ssh_key="${4:-}"

    # Basic validations (keep lightweight)
    if [[ -z "$username" || -z "$name" || -z "$email" ]]; then
        echo "❌ write_profile_entry: username, name, and email required" >&2
        return 1
    fi

    # Encode name/email to avoid colons & special chars
    local enc_name enc_email
    enc_name=$(encode_profile_value "$name")
    enc_email=$(encode_profile_value "$email")

    # Build v2 5-field line: username:2:<enc_name>:<enc_email>:<ssh_key>
    local line="$username:2:$enc_name:$enc_email:$ssh_key"

    # Ensure directory exists & write atomically
    mkdir -p "$(dirname "$GH_USER_PROFILES")" 2>/dev/null || true
    local tmp="${GH_USER_PROFILES}.tmp.$$"
    trap 'rm -f "$tmp"' EXIT

    if [[ -f "$GH_USER_PROFILES" ]]; then
        grep -v "^$username:" "$GH_USER_PROFILES" > "$tmp" || true
    fi
    echo "$line" >> "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$GH_USER_PROFILES"
    trap - EXIT
    return 0
}

# Helper function to create a user profile with enhanced data capture
create_user_profile() {
    local username="$1"
    local name="$2"
    local email="$3"
    local auto_capture="${4:-false}"  # Whether to auto-capture from current git config
    local ssh_key="${5:-}"
    local auto_sign="${6:-}"
    
    if [[ -z "$username" ]]; then
        echo "❌ Username required for profile creation"
        return 1
    fi
    
    # Auto-capture current git config if requested
    if [[ "$auto_capture" == "true" ]]; then
        local current_config=$(detect_git_config "local")
        if [[ $? -eq 0 ]]; then
            local current_name=$(echo "$current_config" | grep "^name:" | cut -d':' -f2-)
            local current_email=$(echo "$current_config" | grep "^email:" | cut -d':' -f2-)
            
            # Use current config if available
            if [[ -n "$current_name" ]]; then
                name="$current_name"
            fi
            if [[ -n "$current_email" ]]; then
                email="$current_email"
            fi
        fi
        
        # If still empty, try global config
        if [[ -z "$name" || -z "$email" ]]; then
            local global_config=$(detect_git_config "global")
            if [[ $? -eq 0 ]]; then
                local global_name=$(echo "$global_config" | grep "^name:" | cut -d':' -f2-)
                local global_email=$(echo "$global_config" | grep "^email:" | cut -d':' -f2-)
                
                if [[ -z "$name" && -n "$global_name" ]]; then
                    name="$global_name"
                fi
                if [[ -z "$email" && -n "$global_email" ]]; then
                    email="$global_email"
                fi
            fi
        fi
        
        # Auto-detect SSH key if not provided
        if [[ -z "$ssh_key" ]]; then
            # ssh_key auto-detection disabled
            :  # auto-detection disabled
        fi
        
        # Auto-detect auto-sign preference if not provided
        if [[ -z "$auto_sign" ]]; then
            auto_sign=$(detect_auto_sign "auto")
        fi
    fi
    
    # Use defaults if still empty
    if [[ -z "$name" ]]; then
        name="$username"
    fi
    if [[ -z "$email" ]]; then
        email="${username}@users.noreply.github.com"
    fi
    if [[ -z "$auto_sign" ]]; then
        auto_sign="false"
    fi
    
    # Write the profile (ssh_key used in place of gpg_key for v2 compatibility)
    if write_profile_entry "$username" "$name" "$email" "$ssh_key"; then
        echo "✅ Created profile for $username: $name <$email>"
        if [[ -n "$ssh_key" ]]; then
            echo "   🔑 SSH key: $ssh_key"
        fi
        return 0
    else
        echo "❌ Failed to create profile for $username"
        return 1
    fi
}

# (DELETED: migrate_old_profile_format removed in v3 simplification)

# Helper function to get user profile (returns enhanced git config for a GitHub username)
get_user_profile() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        return 1
    fi
    
    if [[ ! -f "$GH_USER_PROFILES" ]]; then
        return 1
    fi
    
    # V3-only profile reading (no migration)
    
    # Look for profile (username:version:...)
    local profile_line=$(grep "^$username:" "$GH_USER_PROFILES" 2>/dev/null | head -1)
    
    if [[ -n "$profile_line" ]]; then
        local version=$(echo "$profile_line" | cut -d':' -f2)
        
        if [[ "$version" == "2" ]]; then
            # Check if it's new format (5 fields) or old format (7+ fields)
            local field_count=$(echo "$profile_line" | tr ':' '\n' | wc -l)
            
            if [[ $field_count -eq 5 ]]; then
                # Simplified v2 format: username:2:base64(name):base64(email):ssh_key
                local encoded_name=$(echo "$profile_line" | cut -d':' -f3)
                local encoded_email=$(echo "$profile_line" | cut -d':' -f4)
                local ssh_key_field=$(echo "$profile_line" | cut -d':' -f5)

                local name=$(decode_profile_value "$encoded_name")
                local email=$(decode_profile_value "$encoded_email")

                if [[ -n "$name" && -n "$email" ]]; then
                    echo "name:$name"
                    echo "email:$email"
                    echo "ssh_key:$ssh_key_field"
                    echo "version:2"
                    return 0
                fi
            elif [[ $field_count -eq 6 ]]; then
                # New version 2 format: username:2:base64(name):base64(email):base64(gpg_key):auto_sign
                local encoded_name=$(echo "$profile_line" | cut -d':' -f3)
                local encoded_email=$(echo "$profile_line" | cut -d':' -f4)
                local encoded_gpg_key=$(echo "$profile_line" | cut -d':' -f5)
                local auto_sign=$(echo "$profile_line" | cut -d':' -f6)
                
                if [[ -n "$encoded_name" && -n "$encoded_email" ]]; then
                    local name=$(decode_profile_value "$encoded_name")
                    local email=$(decode_profile_value "$encoded_email")
                    local gpg_key=$(decode_profile_value "$encoded_gpg_key")
                    
                    if [[ -n "$name" && -n "$email" ]]; then
                        echo "name:$name"
                        echo "email:$email"
                        echo "gpg_key:$gpg_key"
                        echo "auto_sign:$auto_sign"
                        echo "version:2"
                        return 0
                    fi
                fi
            else
                # Old version 2 format: username:2:base64(name):base64(email):base64(gpg_key):base64(ssh_key):auto_sign:last_used
                local encoded_name=$(echo "$profile_line" | cut -d':' -f3)
                local encoded_email=$(echo "$profile_line" | cut -d':' -f4)
                local encoded_gpg_key=$(echo "$profile_line" | cut -d':' -f5)
                local auto_sign=$(echo "$profile_line" | cut -d':' -f7)
                
                if [[ -n "$encoded_name" && -n "$encoded_email" ]]; then
                    local name=$(decode_profile_value "$encoded_name")
                    local email=$(decode_profile_value "$encoded_email")
                    local gpg_key=$(decode_profile_value "$encoded_gpg_key")
                    
                    if [[ -n "$name" && -n "$email" ]]; then
                        echo "name:$name"
                        echo "email:$email"
                        echo "gpg_key:$gpg_key"
                        echo "auto_sign:$auto_sign"
                        echo "version:2"
                        return 0
                    fi
                fi
            fi
        elif [[ "$version" == "1" ]]; then
            # Version 1 format: username:1:base64(name):base64(email)
            local encoded_name=$(echo "$profile_line" | cut -d':' -f3)
            local encoded_email=$(echo "$profile_line" | cut -d':' -f4)
            
            if [[ -n "$encoded_name" && -n "$encoded_email" ]]; then
                local name=$(decode_profile_value "$encoded_name")
                local email=$(decode_profile_value "$encoded_email")
                
                if [[ -n "$name" && -n "$email" ]]; then
                    echo "name:$name"
                    echo "email:$email"
                    echo "gpg_key:"
                    echo "auto_sign:false"
                    echo "version:1"
                    return 0
                fi
            fi
        else
            # Treat as v3 (no explicit version)
            parse_profile_line_v3 "$profile_line"
            return $?
        fi
    fi
    
    # Fallback: try old format for compatibility (username=name|email)
    local old_profile=$(grep "^$username=" "$GH_USER_PROFILES" 2>/dev/null | cut -d'=' -f2)
    if [[ -n "$old_profile" ]]; then
        local name=$(echo "$old_profile" | cut -d'|' -f1)
        local email=$(echo "$old_profile" | cut -d'|' -f2)
        
        if [[ -n "$name" && -n "$email" ]]; then
            echo "name:$name"
            echo "email:$email"
            echo "gpg_key:"
            echo "auto_sign:false"
            echo "version:0"
            return 0
        fi
    fi
    
    return 1
}

# Helper function to validate profile completeness (simplified)
# Currently uses mix of echo statements and return codes - consider structured error format
validate_profile_completeness() {
    local username="$1"
    local profile=$(get_user_profile "$username")
    local issues=()
    
    if [[ $? -ne 0 ]]; then
        echo "❌ No profile found for $username"
        return 1
    fi
    
    local name=$(field "$profile" "name")
    local email=$(field "$profile" "email")
    local gpg_key=$(field "$profile" "gpg_key")
    
    # Check required fields
    if [[ -z "$name" ]]; then
        issues+=("name")
    fi
    if [[ -z "$email" ]]; then
        issues+=("email")
    fi
    
    # Check GitHub authentication
    if command -v gh >/dev/null 2>&1; then
        if ! gh auth status --hostname github.com >/dev/null 2>&1; then
            issues+=("authentication")
        else
            # Check if this specific user is authenticated
            local current_user=$(get_current_github_user)
            if [[ "$current_user" != "$username" ]]; then
                issues+=("authentication")
            fi
        fi
    else
        issues+=("authentication")
    fi
    
    # Return results
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "✅ Complete"
        return 0
    else
        echo "⚠️ Missing: $(IFS=', '; echo "${issues[*]}")"
        return 1
    fi
}

# Helper function to display simple profile information
display_simple_profile() {
    local username="$1"
    local current_user="${2:-}"
    local profile=$(get_user_profile "$username")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ No profile found for $username"
        return 1
    fi
    
    # Get basic info
    local name=$(field "$profile" "name")
    local email=$(field "$profile" "email")
    local gpg_key=$(field "$profile" "gpg_key")
    
    # Find user ID and current status
    local user_id=$(get_user_id "$username")
    local is_current=""
    [[ "$username" == "$current_user" ]] && is_current=" (current)"
    
    # Simple completeness check
    local status="✅"
    local status_note=""
    if [[ -z "$name" || -z "$email" ]]; then
        status="⚠️"
        status_note=" [Incomplete]"
    fi
    
    # Display compact format
    echo "$status $user_id. $username$status_note$is_current"
    echo "     $name <$email>"
    
    # GPG status (simplified)
    if [[ -n "$gpg_key" ]]; then
        echo "     GPG: $gpg_key"
    else
        echo "     GPG: Not configured"
    fi
    
    # Auth status (simplified)
    if check_gh_auth; then
        local auth_user=$(get_current_github_user)
        if [[ "$auth_user" == "$username" ]]; then
            echo "     Auth: Authenticated"
        else
            echo "     Auth: Different user"
        fi
    else
        echo "     Auth: Not authenticated"
    fi
}

# Helper function to extract and parse profile data
extract_profile_data() {
    local username="$1"
    local current_user="${2:-}"
    
    local profile=$(get_user_profile "$username")
    if [[ $? -ne 0 ]]; then
        echo "error:No profile found for $username"
        return 1
    fi
    
    local name=$(field "$profile" "name")
    local email=$(field "$profile" "email")
    local gpg_key=$(field "$profile" "gpg_key")
    local auto_sign=$(field "$profile" "auto_sign")
    
    # Find user ID
    local user_id=$(get_user_id "$username")
    
    # Check if current user
    local is_current=""
    [[ "$username" == "$current_user" ]] && is_current="true"
    
    # Output structured data
    echo "username:$username"
    echo "name:$name"
    echo "email:$email"
    echo "gpg_key:$gpg_key"
    echo "auto_sign:$auto_sign"
    echo "user_id:$user_id"
    echo "is_current:$is_current"
}

# Helper function to format profile header with status
format_profile_header() {
    local data="$1"
    
    local username=$(field "$data" "username")
    local user_id=$(field "$data" "user_id")
    local is_current=$(field "$data" "is_current")
    
    # Check profile completeness
    local completeness_icon="✅"
    local completeness_note=""
    validate_profile_completeness "$username" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        completeness_icon="⚠️"
        completeness_note=" [⚠️ Incomplete]"
    fi
    
    # Current user indicator
    local current_indicator=""
    [[ "$is_current" == "true" ]] && current_indicator=" (current)"
    
    # Display header
    if [[ -n "$user_id" ]]; then
        echo "$completeness_icon $user_id. $username$completeness_note$current_indicator"
    else
        echo "$completeness_icon $username$completeness_note$current_indicator"
    fi
}

# Helper function to format profile details
format_profile_details() {
    local data="$1"
    
    local name=$(field "$data" "name")
    local email=$(field "$data" "email")
    local gpg_key=$(field "$data" "gpg_key")
    local auto_sign=$(field "$data" "auto_sign")
    
    echo "     Name: $name"
    echo "     Email: $email"
    
    # GPG information
    if [[ -n "$gpg_key" ]]; then
        if validate_gpg_key "$gpg_key"; then
            echo "     GPG: $gpg_key ✅"
        else
            echo "     GPG: $gpg_key ❌"
        fi
        echo "     Auto-sign: $auto_sign"
    else
        echo "     GPG: Not configured"
    fi
}

# Helper function to format authentication status
format_auth_status() {
    local username="$1"
    
    if command -v gh >/dev/null 2>&1; then
        if gh auth status --hostname github.com >/dev/null 2>&1; then
            local authenticated_user=$(get_current_github_user)
            if [[ "$authenticated_user" == "$username" ]]; then
                echo "     Auth: ✅ Authenticated"
            else
                echo "     Auth: ⚠️ Different user ($authenticated_user)"
            fi
        else
            echo "     Auth: ❌ Not authenticated"
        fi
    else
        echo "     Auth: ❌ GitHub CLI not available"
    fi
}

# Helper function to display rich profile information (orchestrator)
display_rich_profile() {
    local username="$1"
    local current_user="${2:-}"
    
    # Extract profile data
    local profile_data=$(extract_profile_data "$username" "$current_user")
    if echo "$profile_data" | grep -q "^error:"; then
        echo "❌ $(echo "$profile_data" | grep "^error:" | cut -d':' -f2-)"
        return 1
    fi
    
    # Format and display components
    format_profile_header "$profile_data"
    format_profile_details "$profile_data"
    format_auth_status "$username"
    
    return 0
}

# Helper function to resolve "current" username
resolve_current_username() {
    if check_gh_auth; then
        local username=$(get_current_github_user)
        if [[ -z "$username" ]]; then
            echo "❌ Could not detect current GitHub user"
            return 1
        fi
        echo "$username"
        return 0
    else
        echo "❌ GitHub CLI not authenticated or not installed"
        return 1
    fi
}

# Helper function to check if user exists and handle duplication
check_user_existence() {
    local username="$1"
    
    if [[ -f "$GH_USERS_CONFIG" ]] && grep -q "^$username$" "$GH_USERS_CONFIG" 2>/dev/null; then
        echo "⚠️  User $username already exists"
        return 0  # Proceed with adding/updating
    else
        # Add to user list
        echo "$username" >> "$GH_USERS_CONFIG"
        echo "✅ Added $username to user list"
        return 0
    fi
}

# Helper function to run auto-detection workflow
run_autodetection_workflow() {
    # Deprecated interactive workflow removed in v3 cleanup
    echo "⚠️  run_autodetection_workflow is deprecated. Use flag-based 'ghs add-user' instead." 
    return 1
}

# Helper function to run manual entry workflow
run_manual_entry_workflow() {
    # Deprecated manual entry workflow removed – non-interactive flags required
    echo "⚠️  run_manual_entry_workflow is deprecated. Provide --name and --email flags instead."
    return 1
}

# Helper function to update profile field
update_profile_field() {
    local user_input="$1"
    local field="$2" 
    local value="$3"
    
    # Resolve user input to username (handle number, username, or "current")
    local username=$(resolve_user_by_input "$user_input")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Get current profile
    local profile=$(get_user_profile "$username")
    if [[ $? -ne 0 ]]; then
        echo "❌ No profile found for $username"
        return 1
    fi
    
    # Extract current values
    # Current string parsing is embedded throughout codebase - works well but tightly coupled
    local name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local gpg_key=$(echo "$profile" | grep "^gpg_key:" | cut -d':' -f2-)
    local auto_sign=$(echo "$profile" | grep "^auto_sign:" | cut -d':' -f2-)
    
    # Update specific field
    case "$field" in
        "name") name="$value" ;;
        "email") email="$value" ;;
        "gpg") gpg_key="$value" ;;
        *) echo "❌ Invalid field: $field (use: name, email, gpg)"; return 1 ;;
    esac
    
    # Validate and save
    if write_profile_entry "$username" "$name" "$email" "$gpg_key" "$auto_sign"; then
        echo "✅ Updated $field for $username"
    else
        echo "❌ Failed to update $field"
        return 1
    fi
}

# Helper function to show help (DRY - single source of truth)
show_help() {
    echo "🎯 GitHub Project Switcher (ghs)"
    echo ""
    echo "Global GitHub account switching with numbered users and project memory."
    echo ""
    echo "INSTALLATION:"
    echo "  ghs install                Install to shell profile (auto-detects zsh/bash)"
    echo "  ghs uninstall              Remove from shell profile"
    echo ""
    echo "SETUP:"
    echo "  ghs add-user <username>    Add user with profile fields"
    echo "  ghs add-user current       Add currently authenticated GitHub user"
    echo "  ghs add-user <user> --name \"Name\" --email \"email@domain\" --gpg <key> --auto-sign true --force"
    echo ""
    echo "DAILY WORKFLOW:"
    echo "  ghs                        Show smart dashboard"
    echo "  ghs switch <number>        Switch to user by number"
    echo "  ghs assign <number>        Assign user as project default"
    echo ""
    echo "USER MANAGEMENT:"
    echo "  ghs users                  Show numbered list of users"
    echo "  ghs remove-user <user>     Remove user by name or number"
    echo "  ghs profiles               Show user profiles (add --verbose for rich view)"
    echo "  ghs update <user> <field> \"<value>\"  Update profile field (name, email, gpg)"
    echo "  ghs validate [user]        Run profile validation check (all users or specific)"
    echo ""
    echo "PROJECT & STATUS:"
    echo "  ghs status                 Show detailed current status"
    echo "  ghs list                   List all configured projects"
    echo ""
    echo "PROTECTION:"
    echo "  ghs guard install          Install commit validation hooks"
    echo "  ghs guard uninstall        Remove commit validation hooks"  
    echo "  ghs guard status           Show guard status and validation state"
    echo "  ghs guard test             Test validation without installing"
}

# Helper function to run profile validation check for all users
run_profile_health_check() {
    echo "🔍 Profile Validation"
    echo ""
    
    if [[ ! -f "$GH_USERS_CONFIG" || ! -s "$GH_USERS_CONFIG" ]]; then
        echo "📋 No users configured yet"
        return 0
    fi
    
    local all_valid=true
    
    while IFS= read -r username; do
        if [[ -n "$username" ]]; then
            local user_id=""
            user_id=$(get_user_id "$username")
            
            echo -n "Checking $username"
            if [[ -n "$user_id" ]]; then
                echo -n " (#$user_id)"
            fi
            echo "..."
            
            # Run validation
            local validation_result=$(validate_profile_completeness "$username" 2>&1)
            if [[ $? -eq 0 ]]; then
                echo "$validation_result"
            else
                echo "$validation_result"
                all_valid=false
                
                # Suggest fixes
                if echo "$validation_result" | grep -q "GitHub authentication"; then
                    echo "   💡 Fix: Run 'gh auth login' and switch to $username"
                fi
                if echo "$validation_result" | grep -q "GPG key not found"; then
                    echo "   💡 Fix: Import GPG key or update profile"
                fi
            fi
            echo ""
        fi
    done < "$GH_USERS_CONFIG"
    
    if [[ "$all_valid" == "true" ]]; then
        echo "✅ All profiles are valid!"
    else
        echo "⚠️  Some profiles need attention. See suggestions above."
    fi
    
    return 0
}

# Helper function to apply user profile (set git config from stored profile)
apply_user_profile() {
    local username="$1"
    local scope="${2:-local}"  # 'local' or 'global'
    
    if [[ -z "$username" ]]; then
        echo "❌ Username required for profile application"
        return 1
    fi
    
    local profile=$(get_user_profile "$username")
    if [[ $? -ne 0 ]]; then
        echo "❌ No profile found for user: $username"
        return 1
    fi
    
    local name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local gpg_key=$(echo "$profile" | grep "^gpg_key:" | cut -d':' -f2-)
    local auto_sign=$(echo "$profile" | grep "^auto_sign:" | cut -d':' -f2-)
    local ssh_key=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    
    if [[ -z "$name" || -z "$email" ]]; then
        echo "❌ Invalid profile data for user: $username"
        return 1
    fi
    
    # Apply basic git config
    if ! apply_git_config "$name" "$email" "$scope"; then
        echo "❌ Failed to apply profile for user: $username"
        return 1
    fi
    
    # Apply SSH configuration
    if ! apply_ssh_config "$ssh_key" "$scope"; then
        echo "⚠️  SSH configuration failed or not applied"
    fi
    
    # Apply GPG configuration if available
    if [[ -n "$gpg_key" && "$gpg_key" != "" ]]; then
        local git_flags=""
        if [[ "$scope" == "global" ]]; then
            git_flags="--global"
        else
            git_flags="--local"
        fi
        
        # Set GPG signing key
        if git config $git_flags user.signingkey "$gpg_key" 2>/dev/null; then
            echo "✅ Applied GPG key: $gpg_key"
            
            # Set auto-sign preference
            if [[ "$auto_sign" == "true" ]]; then
                if git config $git_flags commit.gpgsign true 2>/dev/null; then
                    echo "✍️  Enabled auto-signing"
                else
                    echo "⚠️  Could not enable auto-signing"
                fi
            else
                # Explicitly disable auto-signing
                git config $git_flags commit.gpgsign false 2>/dev/null
            fi
        else
            echo "⚠️  Could not apply GPG key configuration"
        fi
    else
        # No GPG key configured, ensure auto-signing is disabled
        local git_flags=""
        if [[ "$scope" == "global" ]]; then
            git_flags="--global"
        else
            git_flags="--local"
        fi
        git config $git_flags commit.gpgsign false 2>/dev/null
    fi
    
    return 0
}

# Helper function to apply git configuration with validation
apply_git_config() {
    local name="$1"
    local email="$2"
    local scope="${3:-local}"  # 'local' or 'global'
    
    # Minimal validation (colon safety & basic email check)
    if ! validate_profile_field name "$name" || ! validate_profile_field email "$email"; then
        echo "❌ Invalid name or email"
        return 1
    fi
    
    # Check git availability
    if ! check_git_availability; then
        echo "❌ Git is not available or not working"
        return 1
    fi
    
    # Validate scope
    if [[ "$scope" != "local" && "$scope" != "global" ]]; then
        echo "❌ Invalid scope: $scope (must be 'local' or 'global')"
        return 1
    fi
    
    local git_flags=""
    if [[ "$scope" == "global" ]]; then
        git_flags="--global"
    else
        git_flags="--local"
        
        # Check if we're in a git repository for local config
        if ! git rev-parse --git-dir >/dev/null 2>&1; then
            echo "❌ Not in a git repository (required for local config)"
            return 1
        fi
    fi
    
    # Apply the configuration with individual error checking
    local name_result=true
    local email_result=true
    
    if ! git config $git_flags user.name "$name" 2>/dev/null; then
        echo "❌ Failed to set git user.name"
        name_result=false
    fi
    
    if ! git config $git_flags user.email "$email" 2>/dev/null; then
        echo "❌ Failed to set git user.email" 
        email_result=false
    fi
    
    # Check results
    if [[ "$name_result" == "true" && "$email_result" == "true" ]]; then
        # Verify the configuration was actually set
        local verify_name=$(git config $git_flags --get user.name 2>/dev/null || echo "")
        local verify_email=$(git config $git_flags --get user.email 2>/dev/null || echo "")
        
        if [[ "$verify_name" == "$name" && "$verify_email" == "$email" ]]; then
            if [[ "$scope" == "global" ]]; then
                echo "✅ Updated global git config: $name <$email>"
            else
                echo "✅ Updated local git config: $name <$email>"
            fi
            return 0
        else
            echo "❌ Git config verification failed (values not set correctly)"
            return 1
        fi
    else
        echo "❌ Failed to update git config"
        return 1
    fi
}

# Helper function to apply SSH configuration with validation
apply_ssh_config() {
    local key_path="$1"; local scope="${2:-local}"

    # Validate scope
    if [[ "$scope" != "local" && "$scope" != "global" ]]; then
        echo "❌ Invalid scope" >&2
        return 1
    fi

    local git_flags=""
    if [[ "$scope" == "global" ]]; then
        git_flags="--global"
    else
        git_flags="--local"
        # Must be inside git repo for local
        if ! git rev-parse --git-dir >/dev/null 2>&1; then
            echo "❌ Not in a git repository" >&2
            return 1
        fi
    fi

    if [[ -z "$key_path" ]]; then
        # Remove existing config
        git config $git_flags --unset core.sshCommand 2>/dev/null || true
        echo "✅ Removed SSH config"
        return 0
    fi

    # Ensure key is valid (do NOT auto-fix perms here)
    if ! validate_ssh_key "$key_path" "false"; then
        return 1
    fi

    key_path="${key_path/#\~\//${HOME}/}"
    if git config $git_flags core.sshCommand "ssh -i '$key_path' -o IdentitiesOnly=yes"; then
        echo "✅ Configured SSH key: $key_path"
        return 0
    else
        echo "❌ Failed to configure SSH key" >&2
        return 1
    fi
}

# Helper function to validate SSH key
validate_ssh_key() {
    local key_path="$1"; local fix_perms="${2:-false}"

    # Empty path is acceptable (HTTPS mode)
    if [[ -z "$key_path" ]]; then
        return 0
    fi

    # Expand ~ and make absolute
    key_path="${key_path/#\~\//${HOME}/}"

    # Block directory-traversal attempts
    if [[ "$key_path" == *".."* ]]; then
        echo "❌ directory traversal detected" >&2
        return 1
    fi

    if [[ ! -f "$key_path" ]]; then
        echo "❌ SSH key not found: $key_path" >&2
        return 1
    fi

    # Basic private-key header check
    if ! grep -q "BEGIN .*PRIVATE KEY" "$key_path" 2>/dev/null; then
        echo "❌ doesn't appear to be a private key" >&2
        return 1
    fi

    # Permission check (must be 600)
    local perms
    perms=$(stat -c %a "$key_path" 2>/dev/null || stat -f %Lp "$key_path" 2>/dev/null)
    if [[ "$perms" != "600" ]]; then
        if [[ "$fix_perms" == "true" ]]; then
            if chmod 600 "$key_path" 2>/dev/null; then
                echo "✅ Set permissions to 600"
            else
                echo "❌ Failed to set permissions on $key_path" >&2
                return 1
            fi
        else
            echo "❌ SSH key has incorrect permissions ($perms). Expected 600." >&2
            return 1
        fi
    fi

    return 0
}

# Command functions for cleaner dispatcher

cmd_profiles() {
    local verbose_flag="$1"
    
    if [[ ! -f "$GH_USER_PROFILES" || ! -s "$GH_USER_PROFILES" ]]; then
        echo "📋 No user profiles configured yet"
        echo "   Profiles are created automatically when you add/switch users"
        return 0
    fi
    
    # Check for verbose flag (accepts old --detailed for backward compatibility)
    local use_verbose=false
    if [[ "$verbose_flag" == "--verbose" || "$verbose_flag" == "--detailed" ]]; then
        use_verbose=true
    fi
    
    echo "📋 User Profiles:"
    echo ""
    
    # Get current user for highlighting
    local current_user=""
    if check_gh_auth; then
        current_user=$(get_current_github_user)
    fi
    
    # Display each user
    if [[ -f "$GH_USERS_CONFIG" ]]; then
        while IFS= read -r username; do
            if [[ -n "$username" ]]; then
                if [[ "$use_verbose" == "true" ]]; then
                    display_rich_profile "$username" "$current_user"
                else
                    display_simple_profile "$username" "$current_user"
                fi
                echo ""
            fi
        done < "$GH_USERS_CONFIG"
    fi
}

cmd_add_user() {
    shift # Remove 'add-user' from args
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "❌ Usage: ghs add-user <username> [--name \"Full Name\"] [--email \"email@domain\"] [--gpg <key>] [--auto-sign true|false] [--force]"
        return 1
    fi

    # Resolve 'current' shortcut
    if [[ "$username" == "current" ]]; then
        username=$(resolve_current_username) || return 1
        echo "💡 Detected current GitHub user: $username"
    fi

    # Shift past username
    shift
    local provided_name="" provided_email="" provided_gpg="" provided_auto_sign="" force=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                provided_name="$2"; shift 2;;
            --email)
                provided_email="$2"; shift 2;;
            --gpg)
                provided_gpg="$2"; shift 2;;
            --auto-sign)
                provided_auto_sign="$2"; shift 2;;
            --force)
                force=true; shift;;
            *) echo "⚠️  Unknown option: $1"; return 1;;
        esac
    done

    # Abort if exists and no --force
    if [[ -f "$GH_USERS_CONFIG" ]] && grep -q "^$username$" "$GH_USERS_CONFIG" && [[ "$force" == false ]]; then
        echo "⚠️  User $username already exists. Use --force to overwrite."
        return 1
    fi

    # Auto-detect git config for missing fields
    if [[ -z "$provided_name" || -z "$provided_email" ]]; then
        if auto_cfg=$(detect_git_config "auto"); then
            [[ -z "$provided_name" ]] && provided_name=$(field "$auto_cfg" "name")
            [[ -z "$provided_email" ]] && provided_email=$(field "$auto_cfg" "email")
        fi
    fi

    # Defaults
    [[ -z "$provided_name" ]] && provided_name="$username"
    [[ -z "$provided_email" ]] && provided_email="${username}@users.noreply.github.com"

    # Write profile (V3)
    if write_profile_entry_v3 "$username" "$provided_name" "$provided_email" "$provided_gpg" "$provided_auto_sign"; then
        mkdir -p "$(dirname "$GH_USERS_CONFIG")" 2>/dev/null || true
        touch "$GH_USERS_CONFIG"
        if ! grep -q "^$username$" "$GH_USERS_CONFIG"; then
            echo "$username" >> "$GH_USERS_CONFIG"
        fi
        echo "✅ Added/updated profile for $username"
    else
        echo "❌ Failed to add profile for $username"
        return 1
    fi
}

cmd_switch() {
    local user_id="$1"
    
    if [[ -z "$user_id" ]]; then
        echo "❌ Usage: ghs switch <user_number>"
        echo "   Use 'ghs users' to see available users"
        return 1
    fi
    
    local username=$(get_user_by_id "$user_id")
    if [[ $? -eq 0 ]]; then
        # Switch to the user first
        if gh auth switch --user "$username" 2>/dev/null; then
            # Clear cached user since we just switched
            clear_github_user_cache
            echo "✅ Switched to $username (#$user_id)"
            
            # Check if user has a profile
            local profile=$(get_user_profile "$username")
            if [[ $? -eq 0 ]]; then
                # Profile exists - apply it automatically
                if apply_user_profile "$username" "local"; then
                    local name=$(field "$profile" "name")
                    local email=$(field "$profile" "email")
                    echo "✅ Applied git config: $name <$email>"
                else
                    echo "⚠️  Could not apply git config profile (continuing with GitHub switch)"
                fi
            else
                # No profile exists - create one from current config
                echo "💡 Creating profile for $username from current git config"
                if create_user_profile "$username" "" "" "true"; then
                    # Now apply the newly created profile
                    if apply_user_profile "$username" "local"; then
                        echo "✅ Applied newly created git config profile"
                    else
                        echo "⚠️  Created profile but could not apply git config"
                    fi
                else
                    echo "⚠️  Could not create git config profile (continuing with GitHub switch)"
                fi
            fi
        else
            echo "❌ Failed to switch to $username"
            echo "   Account may not be authenticated. Run: gh auth login"
            return 1
        fi
    fi
}

cmd_assign() {
    local input="$1"
    local project="$2"
    
    if [[ -z "$input" ]]; then
        echo "❌ Usage: ghs assign <username_or_number>"
        echo "   Use 'ghs users' to see available users"
        return 1
    fi
    
    local username=""
    # Check if input is a number (user ID) or username  
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        username=$(get_user_by_id "$input")
        if [[ $? -ne 0 ]]; then
            return 1
        fi
        echo "💡 Using user #$input: $username"
    else
        username="$input"
        # Validate username format (basic security)
        if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            echo "❌ Invalid username format"
            return 1
        fi
    fi
    
    # Remove any existing entry for this project and add new one
    touch "$GH_PROJECT_CONFIG"
    grep -v "^$project=" "$GH_PROJECT_CONFIG" > "${GH_PROJECT_CONFIG}.tmp" 2>/dev/null || true
    echo "$project=$username" >> "${GH_PROJECT_CONFIG}.tmp"
    mv "${GH_PROJECT_CONFIG}.tmp" "$GH_PROJECT_CONFIG"
    
    echo "✅ Assigned $username as default account for $project"
}

cmd_status() {
    local project="$1"
    
    echo "📍 Current project: $project"
    if check_gh_auth; then
        local current_user=$(get_current_github_user)
        if [[ -z "$current_user" ]]; then
            current_user="unknown"
        fi
        
        # Try to find current user ID
        local current_user_id=$(get_user_id "$current_user")
        
        if [[ -n "$current_user_id" ]]; then
            echo "👤 Current GitHub user: $current_user (#$current_user_id)"
        else
            echo "👤 Current GitHub user: $current_user"
        fi
        
        local project_user=""
        if [[ -f "$GH_PROJECT_CONFIG" ]]; then
            project_user=$(grep "^$project=" "$GH_PROJECT_CONFIG" 2>/dev/null | cut -d'=' -f2)
        fi
        
        if [[ -n "$project_user" ]]; then
            # Try to find project user ID
            local project_user_id=$(get_user_id "$project_user")
            
            if [[ "$current_user" == "$project_user" ]]; then
                echo "✅ Correct account for this project!"
            else
                local project_user_display="$project_user"
                if [[ -n "$project_user_id" ]]; then
                    project_user_display="$project_user (#$project_user_id)"
                fi
                echo "⚠️  This project should use: $project_user_display"
                if [[ -n "$project_user_id" ]]; then
                    echo "   Run 'ghs switch $project_user_id' to switch"
                else
                    echo "   Run 'ghs switch <number>' to switch"
                fi
            fi
        else
            echo "💡 No account configured for this project"
            echo "   Run 'ghs assign <username_or_number>' to configure"
        fi
    else
        echo "❌ GitHub CLI not authenticated or not installed"
        echo "   Run 'gh auth login' to get started"
    fi
}

# Guard command implementation
cmd_guard() {
    local subcommand="${1:-}"
    local project="$(basename "$PWD")"
    
    case "$subcommand" in
        "install")
            cmd_guard_install
            ;;
        "uninstall")
            cmd_guard_uninstall
            ;;
        "status")
            cmd_guard_status "$project"
            ;;
        "test")
            cmd_guard_test "$project"
            ;;
        *)
            echo "❌ Usage: ghs guard <subcommand>"
            echo ""
            echo "Available subcommands:"
            echo "  install     Install commit validation hooks"
            echo "  uninstall   Remove commit validation hooks"
            echo "  status      Show guard status and validation state"
            echo "  test        Test validation without installing"
            echo ""
            echo "Examples:"
            echo "  ghs guard install        # Enable protection for this repo"
            echo "  ghs guard status         # Check if protection is active"
            echo "  ghs guard test           # Dry run validation"
            return 1
            ;;
    esac
}

cmd_guard_install() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ Not in a git repository"
        echo "   Navigate to a git repository to install guard hooks"
        return 1
    fi

    local hook_script="$(git rev-parse --show-toplevel)/scripts/guard-hook.sh"
    local hook_target="$(git rev-parse --show-toplevel)/.git/hooks/pre-commit"
    
    if [[ ! -f "$hook_script" ]]; then
        echo "❌ Guard hook script not found at $hook_script"
        echo "   Make sure gh-switcher is properly installed"
        return 1
    fi
    
    # Check if hook already exists
    if [[ -f "$hook_target" ]]; then
        if [[ -L "$hook_target" ]] && [[ "$(readlink "$hook_target")" == *"guard-hook.sh" ]]; then
            echo "✅ Guard hooks already installed"
            return 0
        else
            echo "⚠️  Existing pre-commit hook found"
            echo "   Backup and replace? (y/N):"
            read -r response
            if [[ "$response" != "y" && "$response" != "Y" ]]; then
                echo "❌ Installation cancelled"
                return 1
            fi
            mv "$hook_target" "${hook_target}.backup.$(date +%s)"
            echo "💾 Backed up existing hook"
        fi
    fi
    
    # Install the hook
    ln -sf "$hook_script" "$hook_target"
    chmod +x "$hook_target"
    
    echo "✅ Guard hooks installed successfully"
    echo "   Commits will now be validated for account mismatches"
    echo ""
    echo "💡 To bypass validation when needed:"
    echo "   GHS_SKIP_HOOK=1 git commit -m \"message\""
}

cmd_guard_uninstall() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ Not in a git repository"
        return 1
    fi

    local hook_target="$(git rev-parse --show-toplevel)/.git/hooks/pre-commit"
    
    if [[ ! -f "$hook_target" ]]; then
        echo "✅ No guard hooks to remove"
        return 0
    fi
    
    if [[ -L "$hook_target" ]] && [[ "$(readlink "$hook_target")" == *"guard-hook.sh" ]]; then
        rm -f "$hook_target"
        echo "✅ Guard hooks removed"
        
        # Check for backup
        local backup_file=$(find "$(dirname "$hook_target")" -name "pre-commit.backup.*" -type f 2>/dev/null | head -1)
        if [[ -n "$backup_file" ]]; then
            echo "💡 Previous hook backup found: $backup_file"
            echo "   Restore it? (y/N):"
            read -r response
            if [[ "$response" == "y" || "$response" == "Y" ]]; then
                mv "$backup_file" "$hook_target"
                echo "✅ Previous hook restored"
            fi
        fi
    else
        echo "⚠️  Pre-commit hook exists but is not a guard hook"
        echo "   Not removing unknown hook"
        return 1
    fi
}

cmd_guard_status() {
    local project="$1"
    
    echo "🛡️  Guard Status for $project"
    echo ""
    
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ Not in a git repository"
        return 1
    fi

    local hook_target="$(git rev-parse --show-toplevel)/.git/hooks/pre-commit"
    
    # Check hook installation
    if [[ -f "$hook_target" ]]; then
        if [[ -L "$hook_target" ]] && [[ "$(readlink "$hook_target")" == *"guard-hook.sh" ]]; then
            echo "✅ Guard hooks installed and active"
        else
            echo "⚠️  Different pre-commit hook installed"
            echo "   Run 'ghs guard install' to enable gh-switcher protection"
        fi
    else
        echo "❌ No guard hooks installed"
        echo "   Run 'ghs guard install' to enable protection"
        echo ""
        return 0
    fi
    
    echo ""
    echo "🔍 Current validation state:"
    cmd_guard_test "$project"
}

cmd_guard_test() {
    local project="$1"
    
    # Run the validation logic from guard-hook.sh without installing
    if ! check_gh_auth; then
        echo "⚠️  GitHub CLI not authenticated"
        echo "   Validation would be skipped"
        return 0
    fi

    local current_user=$(get_current_github_user)
    if [[ -z "$current_user" ]]; then
        echo "⚠️  Could not determine current GitHub user"
        echo "   Validation would be skipped"
        return 0
    fi

    echo "👤 Current GitHub user: $current_user"

    # Check project assignment
    local project_user=""
    if [[ -f "$GH_PROJECT_CONFIG" ]]; then
        project_user=$(grep "^$project=" "$GH_PROJECT_CONFIG" 2>/dev/null | cut -d'=' -f2 || echo "")
    fi

    if [[ -n "$project_user" ]]; then
        echo "🔗 Project assigned to: $project_user"
        
        if [[ "$current_user" != "$project_user" ]]; then
            echo "❌ Account mismatch detected!"
            echo "   Commits would be blocked"
            return 1
        else
            echo "✅ Account matches project assignment"
        fi
    else
        echo "💡 No project assignment found"
        echo "   Validation would show warning but allow commit"
    fi

    # Check git config
    local git_config_output=$(detect_git_config "local" 2>/dev/null)
    local git_name=$(echo "$git_config_output" | grep "^name:" | cut -d':' -f2- || echo "")
    local git_email=$(echo "$git_config_output" | grep "^email:" | cut -d':' -f2- || echo "")

    # If no local config, check global
    if [[ -z "$git_name" || -z "$git_email" ]]; then
        git_config_output=$(detect_git_config "global" 2>/dev/null)
        git_name=$(echo "$git_config_output" | grep "^name:" | cut -d':' -f2- || echo "")
        git_email=$(echo "$git_config_output" | grep "^email:" | cut -d':' -f2- || echo "")
    fi

    echo "📧 Git config: $git_name <$git_email>"

    if [[ -z "$git_name" || -z "$git_email" ]]; then
        echo "❌ Git config incomplete!"
        echo "   Commits would be blocked"
        return 1
    else
        echo "✅ Git config is complete"
    fi

    echo ""
    echo "🎯 Overall status: Validation would pass"
    return 0
}

# Simple GitHub project switcher function
ghs() {
    local cmd="${1:-dashboard}"
    local project="$(basename "$PWD")"
    
    case "$cmd" in
        "remove-user"|"rm-user")
            remove_user "$2"
            ;;
        "users"|"list-users")
            list_users
            ;;
        "profiles")
            cmd_profiles "$2"
            ;;
        "edit"|"update-profile")
            echo "💡 The edit command has been replaced with update for better CLI experience"
            echo ""
            echo "To update profile fields:"
            echo "  ghs update <user> name \"Full Name\""
            echo "  ghs update <user> email \"user@email.com\""
            echo "  ghs update <user> gpg \"GPG_KEY_ID\""
            echo ""
            echo "Examples:"
            echo "  ghs update 1 name \"John Smith\""
            echo "  ghs update current email \"john@newcompany.com\""
            echo "  ghs update johndoe gpg \"ABC123DEF\""
            echo ""
            echo "Use 'ghs profiles --verbose' to see current values"
            ;;
        "update")
            local user_input="$2"
            local field="$3"
            local value="$4"
            
            if [[ -z "$user_input" || -z "$field" || -z "$value" ]]; then
                echo "❌ Usage: ghs update <user> <field> \"<value>\""
                echo ""
                echo "Fields: name, email, gpg"
                echo ""
                echo "Examples:"
                echo "  ghs update 1 name \"John Smith\""
                echo "  ghs update current email \"john@email.com\""
                echo "  ghs update johndoe gpg \"ABC123DEF\""
                return 1
            fi
            
            update_profile_field "$user_input" "$field" "$value"
            ;;
        "validate")
            if [[ -n "$2" ]]; then
                # Validate specific user
                local username=$(resolve_user_by_input "$2")
                if [[ $? -ne 0 ]]; then
                    return 1
                fi
                
                echo "🔍 Validating profile: $username"
                echo ""
                validate_profile_completeness "$username"
            else
                # Validate all users
                run_profile_health_check
            fi
            ;;
        "add-user")
            cmd_add_user "$@"
            ;;
        "switch")
            cmd_switch "$2"
            ;;
        "assign")
            cmd_assign "$2" "$project"
            ;;
        "list")
            if [[ -f "$GH_PROJECT_CONFIG" && -s "$GH_PROJECT_CONFIG" ]]; then
                echo "📋 Configured project accounts:"
                while IFS='=' read -r proj user; do
                    if [[ -n "$proj" && -n "$user" ]]; then
                        # Try to find user ID if it exists in users list
                        local user_id=$(get_user_id "$user")
                        
                        local user_display="$user"
                        if [[ -n "$user_id" ]]; then
                            user_display="$user (#$user_id)"
                        fi
                        
                        if [[ "$proj" == "$project" ]]; then
                            echo "  ✅ $proj → $user_display (current project)"
                        else
                            echo "     $proj → $user_display"
                        fi
                    fi
                done < "$GH_PROJECT_CONFIG"
            else
                echo "📋 No project accounts configured yet"
                echo "   Use 'ghs assign <username_or_number>' to configure current project"
            fi
            ;;
        "status")
            cmd_status "$project"
            ;;
        "install")
            # Install the switcher to shell profile
            local shell_profile=$(detect_shell_profile)
            if [[ $? -ne 0 ]]; then
                echo "❌ Unsupported shell ($SHELL). Please manually add to your shell profile:"
                echo "   echo 'source $(realpath "$0")' >> ~/.zshrc"
                return 1
            fi
            
            local script_path="$(realpath "$0")"
            
            # Check if already installed
            if grep -q "gh-switcher.sh" "$shell_profile" 2>/dev/null; then
                echo "✅ GitHub switcher is already installed in $shell_profile"
                echo "   Restart your terminal or run: source $shell_profile"
                return 0
            fi
            
            # Add to shell profile
            echo "source $script_path" >> "$shell_profile"
            echo "✅ Installed GitHub switcher to $shell_profile"
            echo "   Restart your terminal or run: source $shell_profile"
            echo "   Then use 'ghs' anywhere!"
            ;;
        "uninstall")
            # Remove from shell profile
            local shell_profile=$(detect_shell_profile)
            if [[ $? -ne 0 ]]; then
                echo "❌ Unsupported shell ($SHELL). Please manually remove from your shell profile."
                return 1
            fi
            
            if [[ -f "$shell_profile" ]]; then
                # Remove lines containing gh-switcher.sh
                grep -v "gh-switcher.sh" "$shell_profile" > "${shell_profile}.tmp" 2>/dev/null || true
                mv "${shell_profile}.tmp" "$shell_profile"
                echo "✅ Removed GitHub switcher from $shell_profile"
                echo "   Restart your terminal to complete uninstall"
            else
                echo "⚠️  Shell profile $shell_profile not found"
            fi
            ;;
        "guard")
            cmd_guard "$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            # Default action: show smart dashboard
            # Check for first-time setup
            if [[ ! -f "$GH_USERS_CONFIG" || ! -s "$GH_USERS_CONFIG" ]]; then
                first_time_setup
                if [[ $? -ne 0 ]]; then
                    return 1
                fi
            fi
            
            echo "🎯 GitHub Project Switcher"
            echo ""
            
            # Show current project and user status
            echo "📍 Current project: $project"
            
            if check_gh_auth; then
                local current_user=$(get_current_github_user)
                if [[ -z "$current_user" ]]; then
                    current_user="unknown"
                fi
                
                # Try to find current user ID
                local current_user_id=$(get_user_id "$current_user")
                local user_in_list=false
                if [[ -n "$current_user_id" ]]; then
                    user_in_list=true
                fi
                
                if [[ "$user_in_list" == true ]]; then
                    echo "👤 Current user: $current_user (#$current_user_id)"
                    
                    # Show git config status
                    local profile=$(get_user_profile "$current_user")
                    if [[ $? -eq 0 ]]; then
                        local current_git_config=$(detect_git_config "auto")
                        if [[ $? -eq 0 ]]; then
                            local current_git_name=$(field "$current_git_config" "name")
                            local current_git_email=$(field "$current_git_config" "email")
                            
                            local profile_name=$(field "$profile" "name")
                            local profile_email=$(field "$profile" "email")
                            
                            if [[ -n "$current_git_name" && -n "$current_git_email" ]]; then
                                if [[ "$current_git_name" == "$profile_name" && "$current_git_email" == "$profile_email" ]]; then
                                    echo "✅ Git config matches profile"
                                else
                                    echo "⚠️ Git config mismatch ($current_git_name <$current_git_email>)"
                                fi
                            else
                                echo "❌ Git config not configured"
                            fi
                        else
                            echo "❌ Git not available"
                        fi
                    else
                        echo "👤 No profile configured"
                    fi
                else
                    echo "👤 Current user: $current_user"
                    # Show onboarding prompt if user is not in list
                    if [[ "$current_user" != "unknown" && "$current_user" != "" ]]; then
                        echo ""
                        echo "💡 Looks like you're logged into a GitHub account not configured in ghswitch."
                        echo "   To add it, type: ghs add-user current"
                        echo ""
                    fi
                fi
                
                # Show project preference
                local project_user=""
                if [[ -f "$GH_PROJECT_CONFIG" ]]; then
                    project_user=$(grep "^$project=" "$GH_PROJECT_CONFIG" 2>/dev/null | cut -d'=' -f2)
                fi
                
                if [[ -n "$project_user" ]]; then
                    local project_user_id=$(get_user_id "$project_user")
                    
                    if [[ "$current_user" == "$project_user" ]]; then
                        echo "✅ Using correct account for this project!"
                    else
                        local project_user_display="$project_user"
                        if [[ -n "$project_user_id" ]]; then
                            project_user_display="$project_user (#$project_user_id)"
                        fi
                        echo "⚠️  Project should use: $project_user_display"
                    fi
                else
                    echo "💡 No account configured for this project"
                fi
            else
                echo "❌ GitHub CLI not authenticated or not installed"
                echo "   Run 'gh auth login' to get started"
            fi
            
            echo ""
            
            # Show available users
            if has_users; then
                echo "📋 Available users:"
                local i=1
                
                # Get current user once for the entire loop
                local dashboard_current_user=""
                if check_gh_auth; then
                    dashboard_current_user=$(get_current_github_user)
                fi
                
                while IFS= read -r username; do
                    if [[ -n "$username" ]]; then
                        if [[ "$username" == "$dashboard_current_user" ]]; then
                            echo "  ✅ $i. $username (current)"
                        else
                            echo "     $i. $username"
                        fi
                        ((i++))
                    fi
                done < "$GH_USERS_CONFIG"
                
                echo ""
                echo "⚡ Quick actions:"
                
                # Generate actual commands with real user numbers
                i=1
                while IFS= read -r username; do
                    if [[ -n "$username" ]]; then
                        echo "  ghs switch $i    # Switch to $username"
                        echo "  ghs assign $i    # Assign $username to project"
                        ((i++))
                    fi
                done < "$GH_USERS_CONFIG"
            else
                echo "📋 No users configured yet"
                echo ""
                echo "⚡ Get started:"
                echo "  ghs add-user <username>    # Add your first user"
            fi
            
            echo ""
            echo "📚 More commands: ghs help"
            ;;
    esac
}

# If script is run directly (not sourced), execute the ghs function
#
#
# For global package distribution, this structure would change to:
#
# PACKAGE STRUCTURE:
# ```
# gh-switcher/
# ├── bin/
# │   └── gh-switcher                 # Main executable (replaces this section)
# ├── lib/
# │   ├── gh-switcher-core.sh         # Core API functions
# │   ├── gh-switcher-ui.sh           # UI/formatting functions  
# │   └── gh-switcher-compat.sh       # Compatibility/migration
# ├── share/
# │   ├── man/man1/gh-switcher.1      # Man page
# │   └── completions/
# │       ├── gh-switcher.bash        # Bash completion
# │       ├── gh-switcher.zsh         # Zsh completion  
# │       └── gh-switcher.fish        # Fish completion
# ├── etc/
# │   └── gh-switcher/
# │       └── config.example          # Example configuration
# └── LICENSE, README.md, CHANGELOG.md
# ```
#
# INSTALLATION METHODS:
# 1. npm: npm install -g gh-switcher
# 2. Homebrew: brew install gh-switcher  
# 3. APT: apt install gh-switcher
# 4. Manual: curl -sSL install-script | bash
#
# MIGRATION STRATEGY:
#
# CONFIGURATION HIERARCHY (library version):
# 1. Command line flags: --config-dir, --namespace
# 2. Environment variables: GH_SWITCHER_DIR, GH_SWITCHER_NAMESPACE  
# 3. Config file: ~/.config/gh-switcher/config
# 4. System defaults: /etc/gh-switcher/config
#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for help flag specifically
    if [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
        # Show usage context for direct execution
        echo "🎯 GitHub Project Switcher"
        echo ""
        echo "This script can be used in two ways:"
        echo ""
        echo "1. Source it in your shell profile (recommended):"
        echo "   echo \"source $(realpath "$0")\" >> ~/.zshrc"
        echo "   source ~/.zshrc"
        echo "   Then use: ghs [command] anywhere"
        echo ""
        echo "2. Run directly (one-time):"
        echo "   ./gh-switcher.sh [command]"
        echo ""
        # Use the centralized help function
        show_help
    else
        # Execute the ghs function with all arguments (or no arguments for default switch)
        ghs "$@"
    fi
fi

#═══════════════════════════════════════════════════════════════════════════════
# END OF LIBRARY TRANSFORMATION NOTES
#═══════════════════════════════════════════════════════════════════════════════
#
# SUMMARY OF CHANGES NEEDED FOR LIBRARY DISTRIBUTION:
#
# 1. Configuration: Move from hard-coded paths to configurable system
# 2. Namespacing: Isolate different tools from each other  
# 3. API Separation: Split core logic from UI presentation
# 4. Error Handling: Return codes instead of direct output
# 5. Package Structure: Standard distribution layout
# 6. Installation: Multiple package managers + migration
# 7. Documentation: Man pages, completion scripts
# 8. Testing: Comprehensive test suite for library functions
# 9. Versioning: Semantic versioning + migration system
# 10. Security: Enhanced validation + sandboxing options
#
# ESTIMATED EFFORT: 2-3 weeks for library transformation + packaging
# CURRENT STATUS: Perfect for personal/team use, detailed roadmap for library use
#═══════════════════════════════════════════════════════════════════════════════ 

# (V3 profile helpers moved to top of file for proper function ordering)

# Helper function to get user ID from username (DRY - 9 instances)
get_user_id() {
    local username="$1"
    if [[ -f "$GH_USERS_CONFIG" ]]; then
        grep -n "^$username$" "$GH_USERS_CONFIG" | cut -d: -f1
    fi
}

# Helper function to check if users config exists and has content (DRY)
has_users() {
    [[ -f "$GH_USERS_CONFIG" && -s "$GH_USERS_CONFIG" ]]
}

# =====================
# User removal helper (v2 tests rely on this)
# =====================

remove_user() {
    local input="$1"

    # Usage check
    if [[ -z "$input" ]]; then
        echo "❌ Usage: ghs remove-user <username_or_number>"
        return 1
    fi

    # No users configured?
    if [[ ! -s "$GH_USERS_CONFIG" ]]; then
        echo "❌ No users configured" >&2
        return 1
    fi

    local username=""; local user_id=""

    if [[ "$input" =~ ^[0-9]+$ ]]; then
        # Numeric ID
        user_id="$input"
        username=$(get_user_by_id "$user_id" 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            echo "❌ User ID $user_id not found in user list" >&2
            return 1
        fi
        echo "Removing user #$user_id: $username"
    else
        username="$input"
        # Locate ID for display (optional)
        user_id=$(grep -n "^$username$" "$GH_USERS_CONFIG" | cut -d':' -f1 | head -1)
    fi

    # Confirm existence
    if ! grep -q "^$username$" "$GH_USERS_CONFIG" 2>/dev/null; then
        echo "❌ $username not found in user list" >&2
        return 1
    fi

    # Remove from list
    grep -v "^$username$" "$GH_USERS_CONFIG" > "${GH_USERS_CONFIG}.tmp" || true
    mv "${GH_USERS_CONFIG}.tmp" "$GH_USERS_CONFIG"

    echo "✅ Removed $username from user list"
}