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

#═══════════════════════════════════════════════════════════════════════════════
# LIBRARY TRANSFORMATION NOTES
#═══════════════════════════════════════════════════════════════════════════════
# 
# TO MAKE THIS A DISTRIBUTABLE LIBRARY, THE FOLLOWING CHANGES ARE NEEDED:
#
# 1. CONFIGURATION SYSTEM:
#    Current: Hard-coded ~/.gh-* paths
#    Library: Configurable base directory with environment variable support
#    ```bash
#    GH_SWITCHER_DIR="${GH_SWITCHER_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/gh-switcher}"
#    GH_SWITCHER_NAMESPACE="${GH_SWITCHER_NAMESPACE:-default}"
#    GH_PROJECT_CONFIG="$GH_SWITCHER_DIR/$GH_SWITCHER_NAMESPACE/projects"
#    GH_USERS_CONFIG="$GH_SWITCHER_DIR/$GH_SWITCHER_NAMESPACE/users"
#    ```
#
# 2. XDG COMPLIANCE:
#    Current: Uses ~/.gh-* regardless of OS
#    Library: Follow OS conventions
#    ```bash
#    if [[ "$OSTYPE" == "darwin"* ]]; then
#        CONFIG_DIR="$HOME/Library/Application Support/gh-switcher"
#    else
#        CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gh-switcher"
#    fi
#    ```
#
# 3. NAMESPACE ISOLATION:
#    Current: All tools share same user list and project mappings
#    Library: Each consuming tool gets its own namespace
#    Example: my-tool uses ~/.config/gh-switcher/my-tool/{users,projects}
#
# 4. API EXTRACTION:
#    Current: Direct function calls mixed with UI
#    Library: Clean separation between core logic and presentation
#    ```bash
#    # Core API functions (return data, no direct output)
#    gh_switcher_list_users() { ... }
#    gh_switcher_add_user() { ... }
#    gh_switcher_get_project_user() { ... }
#    
#    # UI/presentation functions
#    gh_switcher_show_dashboard() { ... }
#    gh_switcher_show_user_list() { ... }
#    ```
#
# 5. ERROR HANDLING:
#    Current: Prints errors and exits
#    Library: Return error codes, let caller handle presentation
#    ```bash
#    # Instead of: echo "❌ Error" && return 1
#    # Library: return error codes, provide error messages separately
#    ```
#
# 6. INITIALIZATION/CLEANUP:
#    Current: No setup/teardown
#    Library: Explicit initialization and cleanup functions
#    ```bash
#    gh_switcher_init() { # Create directories, validate dependencies }
#    gh_switcher_cleanup() { # Remove config, uninstall }
#    ```
#
# 7. PACKAGE MANAGEMENT:
#    Current: Manual script sourcing
#    Library: Proper package structure for npm/brew/apt distribution
#    - bin/gh-switcher (main executable)
#    - lib/gh-switcher-core.sh (core functions)
#    - share/man/gh-switcher.1 (man page)
#    - etc/gh-switcher/config (default config)
#
# 8. CONFIGURATION FILE:
#    Current: Environment variables only
#    Library: Support config file + environment variables
#    ~/.config/gh-switcher/config with INI or TOML format
#
# 9. MIGRATION SYSTEM:
#    Current: No versioning or migration
#    Library: Handle config format changes between versions
#    Detect old ~/.gh-* files and migrate to new structure
#
# 10. SECURITY HARDENING:
#     Current: Basic input validation
#     Library: More comprehensive validation, sandboxing options
#
#═══════════════════════════════════════════════════════════════════════════════

# CURRENT SIMPLE IMPLEMENTATION (perfect for personal/team use)
# Hard-coded paths - works great for single-user scenarios
GH_PROJECT_CONFIG="$HOME/.gh-project-accounts"
GH_USERS_CONFIG="$HOME/.gh-users"
GH_USER_PROFILES="$HOME/.gh-user-profiles"

# NOTE: For library version, these would become:
# GH_PROJECT_CONFIG="$GH_SWITCHER_DIR/$GH_SWITCHER_NAMESPACE/projects"  
# GH_USERS_CONFIG="$GH_SWITCHER_DIR/$GH_SWITCHER_NAMESPACE/users"

# Helper function to add a user to the global list
#
# LIBRARY TRANSFORMATION NOTES:
# - Would become: gh_switcher_add_user() with return codes instead of direct output
# - Error messages would be returned via separate function: gh_switcher_get_last_error()
# - UI output would be handled by caller: gh_switcher_show_add_user_result()
# - Would need namespace support: check $GH_SWITCHER_NAMESPACE/users instead of global file
# - Would need initialization check: ensure config directory exists before writing
add_user() {
    local username="$1"
    if [[ -z "$username" ]]; then
        echo "❌ Usage: ghs add-user <username>"
        return 1
    fi
    
    # Validate username format
    # LIBRARY NOTE: This validation would be extracted to gh_switcher_validate_username()
    if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "❌ Invalid username format"
        return 1
    fi
    
    # Handle special "current" keyword
    if [[ "$username" == "current" ]]; then
        if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
            username=$(gh api user --jq '.login' 2>/dev/null || echo "")
            if [[ -z "$username" ]]; then
                echo "❌ Could not detect current GitHub user"
                echo "   Make sure you're authenticated with: gh auth login"
                return 1
            fi
            echo "💡 Adding current GitHub user: $username"
        else
            echo "❌ GitHub CLI not authenticated or not installed"
            echo "   Run 'gh auth login' to get started"
            return 1
        fi
    fi
    
    # Check if user already exists
    # LIBRARY NOTE: Would need to ensure config directory exists first
    # mkdir -p "$(dirname "$GH_USERS_CONFIG")" 2>/dev/null
    if [[ -f "$GH_USERS_CONFIG" ]] && grep -q "^$username$" "$GH_USERS_CONFIG" 2>/dev/null; then
        echo "⚠️  User $username already exists in the list"
        return 0
    fi
    
    # Add user to the list
    # LIBRARY NOTE: Would need atomic write operation with proper error handling
    echo "$username" >> "$GH_USERS_CONFIG"
    echo "✅ Added $username to user list"
    
    # Auto-create profile from current git config
    create_user_profile "$username" "" "" "true"
    
    # Show current list with numbers
    # LIBRARY NOTE: This UI coupling would be removed - caller decides what to show
    list_users
}

# Helper function to list all users with numbers
#
# LIBRARY TRANSFORMATION NOTES:
# - Would become: gh_switcher_get_users() returning structured data (JSON/array)
# - Current user detection would be separate: gh_switcher_get_current_user()
# - UI formatting would be separate: gh_switcher_format_user_list()
# - Would support filtering/sorting options
# - Would handle namespace isolation automatically
list_users() {
    if [[ ! -f "$GH_USERS_CONFIG" || ! -s "$GH_USERS_CONFIG" ]]; then
        echo "📋 No users configured yet"
        echo "   Use 'ghs add-user <username>' to add users"
        return 0
    fi
    
    echo "📋 Available users:"
    local i=1
    while IFS= read -r username; do
        if [[ -n "$username" ]]; then
            # Check if this is the current user
            # LIBRARY NOTE: This external dependency check would be abstracted
            # gh_switcher_is_gh_available() && gh_switcher_get_current_user()
            if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                local current_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
                if [[ "$username" == "$current_user" ]]; then
                    echo "  🟢 $i. $username (current)"
                else
                    echo "  ⚪ $i. $username"
                fi
            else
                echo "  ⚪ $i. $username"
            fi
            ((i++))
        fi
    done < "$GH_USERS_CONFIG"
    
    # LIBRARY NOTE: Would return structured data instead of printing:
    # {
    #   "users": [
    #     {"id": 1, "username": "personal-acct", "is_current": true},
    #     {"id": 2, "username": "work-account", "is_current": false}
    #   ],
    #   "current_user": "personal-acct",
    #   "gh_available": true
    # }
}

# Helper function to get username by ID number
get_user_by_id() {
    local user_id="$1"
    
    if [[ ! "$user_id" =~ ^[0-9]+$ ]]; then
        echo "❌ Invalid user ID. Must be a number."
        return 1
    fi
    
    if [[ ! -f "$GH_USERS_CONFIG" || ! -s "$GH_USERS_CONFIG" ]]; then
        echo "❌ No users configured. Use 'ghs add-user <username>' first."
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

# Helper function to detect GPG signing key
detect_gpg_key() {
    local scope="${1:-auto}"  # 'local', 'global', or 'auto'
    
    if ! check_git_availability; then
        return 1
    fi
    
    local gpg_key=""
    
    if [[ "$scope" == "global" ]]; then
        gpg_key=$(git config --global --get user.signingkey 2>/dev/null || echo "")
    elif [[ "$scope" == "local" ]]; then
        gpg_key=$(git config --local --get user.signingkey 2>/dev/null || echo "")
    else
        # Auto mode: check local first, then global
        gpg_key=$(git config --get user.signingkey 2>/dev/null || echo "")
        
        # If nothing found and we were looking for local, try global as fallback
        if [[ -z "$gpg_key" && "$scope" == "local" ]]; then
            gpg_key=$(git config --global --get user.signingkey 2>/dev/null || echo "")
        fi
    fi
    
    echo "$gpg_key"
    return 0
}

# Helper function to detect auto-sign preference
detect_auto_sign() {
    local scope="${1:-auto}"  # 'local', 'global', or 'auto'
    
    if ! check_git_availability; then
        return 1
    fi
    
    local auto_sign=""
    
    if [[ "$scope" == "global" ]]; then
        auto_sign=$(git config --global --get commit.gpgsign 2>/dev/null || echo "")
    elif [[ "$scope" == "local" ]]; then
        auto_sign=$(git config --local --get commit.gpgsign 2>/dev/null || echo "")
    else
        # Auto mode: check local first, then global
        auto_sign=$(git config --get commit.gpgsign 2>/dev/null || echo "")
        
        # If nothing found and we were looking for local, try global as fallback
        if [[ -z "$auto_sign" && "$scope" == "local" ]]; then
            auto_sign=$(git config --global --get commit.gpgsign 2>/dev/null || echo "")
        fi
    fi
    
    # Convert to boolean
    if [[ "$auto_sign" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
    return 0
}

# Helper function to detect SSH key for user
detect_ssh_key() {
    local username="$1"
    
    # Common SSH key paths
    local ssh_keys=(
        "$HOME/.ssh/id_rsa"
        "$HOME/.ssh/id_ed25519"
        "$HOME/.ssh/id_ecdsa"
        "$HOME/.ssh/id_rsa_$username"
        "$HOME/.ssh/id_ed25519_$username"
    )
    
    # Return first existing key
    for key in "${ssh_keys[@]}"; do
        if [[ -f "$key" ]]; then
            echo "$key"
            return 0
        fi
    done
    
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

# Helper function to validate input for profile creation
validate_profile_input() {
    local username="$1"
    local name="$2" 
    local email="$3"
    local gpg_key="$4"
    local ssh_key="$5"
    
    # Username validation
    if [[ -z "$username" ]]; then
        echo "❌ Username cannot be empty"
        return 1
    fi
    
    if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "❌ Username contains invalid characters (only letters, numbers, dots, underscores, and hyphens allowed)"
        return 1
    fi
    
    # Name validation
    if [[ -z "$name" ]]; then
        echo "❌ Name cannot be empty"
        return 1
    fi
    
    if [[ ${#name} -gt 255 ]]; then
        echo "❌ Name too long (max 255 characters)"
        return 1
    fi
    
    # Email validation
    if [[ -z "$email" ]]; then
        echo "❌ Email cannot be empty"
        return 1
    fi
    
    if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        echo "❌ Invalid email format"
        return 1
    fi
    
    if [[ ${#email} -gt 255 ]]; then
        echo "❌ Email too long (max 255 characters)"
        return 1
    fi
    
    # GPG key validation (optional)
    if [[ -n "$gpg_key" ]]; then
        if [[ ${#gpg_key} -gt 255 ]]; then
            echo "❌ GPG key too long (max 255 characters)"
            return 1
        fi
    fi
    
    # SSH key validation (optional)
    if [[ -n "$ssh_key" ]]; then
        if [[ ${#ssh_key} -gt 255 ]]; then
            echo "❌ SSH key path too long (max 255 characters)"
            return 1
        fi
        # Check if path exists (if specified)
        if [[ "$ssh_key" != "" && ! -f "$ssh_key" ]]; then
            echo "⚠️  SSH key file does not exist: $ssh_key"
        fi
    fi
    
    return 0
}

# Helper function to encode profile data safely
encode_profile_value() {
    local value="$1"
    # Use base64 encoding to handle any special characters
    echo "$value" | base64 | tr -d '\n'
}

# Helper function to decode profile data safely
decode_profile_value() {
    local encoded_value="$1"
    echo "$encoded_value" | base64 -d 2>/dev/null || echo ""
}

# Helper function to write profile safely
write_profile_entry() {
    local username="$1"
    local name="$2"
    local email="$3"
    local gpg_key="${4:-}"
    local ssh_key="${5:-}"
    local auto_sign="${6:-false}"
    local last_used="${7:-}"
    
    # Set defaults
    if [[ -z "$last_used" ]]; then
        last_used=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    fi
    
    # Validate inputs
    if ! validate_profile_input "$username" "$name" "$email" "$gpg_key" "$ssh_key"; then
        return 1
    fi
    
    # Encode values safely
    local encoded_name=$(encode_profile_value "$name")
    local encoded_email=$(encode_profile_value "$email")
    local encoded_gpg_key=$(encode_profile_value "$gpg_key")
    local encoded_ssh_key=$(encode_profile_value "$ssh_key")
    
    if [[ -z "$encoded_name" || -z "$encoded_email" ]]; then
        echo "❌ Failed to encode profile data"
        return 1
    fi
    
    # Create profile directory if it doesn't exist
    local profile_dir=$(dirname "$GH_USER_PROFILES")
    if [[ ! -d "$profile_dir" ]]; then
        mkdir -p "$profile_dir" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "❌ Failed to create profile directory: $profile_dir"
            return 1
        fi
    fi
    
    # Create/update the profile with atomic write
    touch "$GH_USER_PROFILES" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "❌ Cannot create profile file: $GH_USER_PROFILES"
        return 1
    fi
    
    # Remove existing profile for this user
    if [[ -f "$GH_USER_PROFILES" ]]; then
        grep -v "^$username:" "$GH_USER_PROFILES" > "${GH_USER_PROFILES}.tmp" 2>/dev/null || true
    else
        touch "${GH_USER_PROFILES}.tmp"
    fi
    
    # Add new profile (format: username:2:base64(name):base64(email):base64(gpg_key):base64(ssh_key):auto_sign:last_used)
    echo "$username:2:$encoded_name:$encoded_email:$encoded_gpg_key:$encoded_ssh_key:$auto_sign:$last_used" >> "${GH_USER_PROFILES}.tmp"
    
    # Atomic move
    if mv "${GH_USER_PROFILES}.tmp" "$GH_USER_PROFILES" 2>/dev/null; then
        return 0
    else
        echo "❌ Failed to update profile file"
        rm -f "${GH_USER_PROFILES}.tmp" 2>/dev/null
        return 1
    fi
}

# Helper function to create a user profile with enhanced data capture
create_user_profile() {
    local username="$1"
    local name="$2"
    local email="$3"
    local auto_capture="${4:-false}"  # Whether to auto-capture from current git config
    local gpg_key="${5:-}"
    local ssh_key="${6:-}"
    local auto_sign="${7:-}"
    
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
        
        # Auto-detect GPG key if not provided
        if [[ -z "$gpg_key" ]]; then
            gpg_key=$(detect_gpg_key "auto")
        fi
        
        # Auto-detect auto-sign preference if not provided
        if [[ -z "$auto_sign" ]]; then
            auto_sign=$(detect_auto_sign "auto")
        fi
        
        # Auto-detect SSH key if not provided
        if [[ -z "$ssh_key" ]]; then
            ssh_key=$(detect_ssh_key "$username")
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
    
    # Write the profile
    if write_profile_entry "$username" "$name" "$email" "$gpg_key" "$ssh_key" "$auto_sign"; then
        echo "✅ Created profile for $username: $name <$email>"
        if [[ -n "$gpg_key" ]]; then
            echo "   🔑 GPG key: $gpg_key (auto-sign: $auto_sign)"
        fi
        if [[ -n "$ssh_key" ]]; then
            echo "   🔐 SSH key: $ssh_key"
        fi
        return 0
    else
        echo "❌ Failed to create profile for $username"
        return 1
    fi
}

# Helper function to migrate old profile format to new format
migrate_old_profile_format() {
    if [[ ! -f "$GH_USER_PROFILES" ]]; then
        return 0
    fi
    
    # Check if file contains old format (has = instead of :)
    if grep -q "=" "$GH_USER_PROFILES" 2>/dev/null; then
        echo "🔄 Migrating profiles to new format..."
        local backup_file="${GH_USER_PROFILES}.backup.$(date +%s)"
        
        # Create backup
        if ! cp "$GH_USER_PROFILES" "$backup_file" 2>/dev/null; then
            echo "⚠️  Could not create profile backup"
            return 1
        fi
        
        # Create temporary file for new format
        local temp_file="${GH_USER_PROFILES}.migrating"
        > "$temp_file"
        
        # Migrate each line
        local migration_failed=false
        while IFS='=' read -r username profile_data; do
            if [[ -n "$username" && -n "$profile_data" ]]; then
                local name=$(echo "$profile_data" | cut -d'|' -f1)
                local email=$(echo "$profile_data" | cut -d'|' -f2)
                
                if [[ -n "$name" && -n "$email" ]]; then
                    # Encode safely
                    local encoded_name=$(encode_profile_value "$name")
                    local encoded_email=$(encode_profile_value "$email")
                    
                    if [[ -n "$encoded_name" && -n "$encoded_email" ]]; then
                        echo "$username:1:$encoded_name:$encoded_email" >> "$temp_file"
                    else
                        echo "⚠️  Failed to migrate profile for $username"
                        migration_failed=true
                    fi
                fi
            fi
        done < "$GH_USER_PROFILES"
        
        if [[ "$migration_failed" == "false" ]]; then
            # Migration successful, replace original
            if mv "$temp_file" "$GH_USER_PROFILES" 2>/dev/null; then
                echo "✅ Profile migration completed (backup: $backup_file)"
                return 0
            else
                echo "❌ Failed to replace profile file"
                rm -f "$temp_file" 2>/dev/null
                return 1
            fi
        else
            echo "❌ Profile migration failed, keeping original format"
            rm -f "$temp_file" 2>/dev/null
            return 1
        fi
    fi
    
    return 0
}

# Helper function to get user profile (returns enhanced git config for a GitHub username)
get_user_profile() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        return 1
    fi
    
    if [[ ! -f "$GH_USER_PROFILES" ]]; then
        return 1
    fi
    
    # Try migration if needed
    migrate_old_profile_format
    
    # Look for profile (username:version:...)
    local profile_line=$(grep "^$username:" "$GH_USER_PROFILES" 2>/dev/null | head -1)
    
    if [[ -n "$profile_line" ]]; then
        local version=$(echo "$profile_line" | cut -d':' -f2)
        
        if [[ "$version" == "2" ]]; then
            # Version 2 format: username:2:base64(name):base64(email):base64(gpg_key):base64(ssh_key):auto_sign:last_used
            local encoded_name=$(echo "$profile_line" | cut -d':' -f3)
            local encoded_email=$(echo "$profile_line" | cut -d':' -f4)
            local encoded_gpg_key=$(echo "$profile_line" | cut -d':' -f5)
            local encoded_ssh_key=$(echo "$profile_line" | cut -d':' -f6)
            local auto_sign=$(echo "$profile_line" | cut -d':' -f7)
            local last_used=$(echo "$profile_line" | cut -d':' -f8)
            
            if [[ -n "$encoded_name" && -n "$encoded_email" ]]; then
                local name=$(decode_profile_value "$encoded_name")
                local email=$(decode_profile_value "$encoded_email")
                local gpg_key=$(decode_profile_value "$encoded_gpg_key")
                local ssh_key=$(decode_profile_value "$encoded_ssh_key")
                
                if [[ -n "$name" && -n "$email" ]]; then
                    echo "name:$name"
                    echo "email:$email"
                    echo "gpg_key:$gpg_key"
                    echo "ssh_key:$ssh_key"
                    echo "auto_sign:$auto_sign"
                    echo "last_used:$last_used"
                    echo "version:2"
                    return 0
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
                    echo "ssh_key:"
                    echo "auto_sign:false"
                    echo "last_used:"
                    echo "version:1"
                    return 0
                fi
            fi
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
            echo "ssh_key:"
            echo "auto_sign:false"
            echo "last_used:"
            echo "version:0"
            return 0
        fi
    fi
    
    return 1
}

# Helper function to validate profile completeness
validate_profile_completeness() {
    local username="$1"
    local profile=$(get_user_profile "$username")
    local issues=()
    
    if [[ $? -ne 0 ]]; then
        echo "❌ No profile found for $username"
        return 1
    fi
    
    local name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local gpg_key=$(echo "$profile" | grep "^gpg_key:" | cut -d':' -f2-)
    local ssh_key=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    
    # Check required fields
    if [[ -z "$name" ]]; then
        issues+=("Missing name")
    fi
    if [[ -z "$email" ]]; then
        issues+=("Missing email")
    fi
    
    # Check GitHub authentication
    if command -v gh >/dev/null 2>&1; then
        if ! gh auth status --hostname github.com >/dev/null 2>&1; then
            issues+=("GitHub authentication required")
        else
            # Check if this specific user is authenticated
            local current_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
            if [[ "$current_user" != "$username" ]]; then
                issues+=("Not currently authenticated as $username")
            fi
        fi
    else
        issues+=("GitHub CLI not installed")
    fi
    
    # Check GPG key validity
    if [[ -n "$gpg_key" ]]; then
        if ! validate_gpg_key "$gpg_key"; then
            issues+=("GPG key not found in keyring")
        fi
    fi
    
    # Check SSH key existence
    if [[ -n "$ssh_key" ]]; then
        if [[ ! -f "$ssh_key" ]]; then
            issues+=("SSH key file not found")
        fi
    fi
    
    # Return results
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "✅ Profile complete"
        return 0
    else
        echo "⚠️  Issues found:"
        for issue in "${issues[@]}"; do
            echo "   - $issue"
        done
        return 1
    fi
}

# Helper function to display rich profile information
display_rich_profile() {
    local username="$1"
    local current_user="${2:-}"  # Optional: current GitHub user for highlighting
    local profile=$(get_user_profile "$username")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ No profile found for $username"
        return 1
    fi
    
    local name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local gpg_key=$(echo "$profile" | grep "^gpg_key:" | cut -d':' -f2-)
    local ssh_key=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    local auto_sign=$(echo "$profile" | grep "^auto_sign:" | cut -d':' -f2-)
    local last_used=$(echo "$profile" | grep "^last_used:" | cut -d':' -f2-)
    local version=$(echo "$profile" | grep "^version:" | cut -d':' -f2-)
    
    # Find user ID
    local user_id=""
    if [[ -f "$GH_USERS_CONFIG" ]]; then
        user_id=$(grep -n "^$username$" "$GH_USERS_CONFIG" | cut -d: -f1)
    fi
    
    # Check if current user
    local is_current=""
    if [[ "$username" == "$current_user" ]]; then
        is_current=" (current)"
    fi
    
    # Check profile completeness
    local completeness_icon="✅"
    local completeness_note=""
    validate_profile_completeness "$username" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        completeness_icon="⚠️"
        completeness_note=" [⚠️ Incomplete]"
    fi
    
    # Display header
    if [[ -n "$user_id" ]]; then
        echo "$completeness_icon $user_id. $username$completeness_note$is_current"
    else
        echo "$completeness_icon $username$completeness_note$is_current"
    fi
    
    # Display details with indentation
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
    
    # SSH information
    if [[ -n "$ssh_key" ]]; then
        if [[ -f "$ssh_key" ]]; then
            echo "     SSH: $ssh_key ✅"
        else
            echo "     SSH: $ssh_key ❌"
        fi
    else
        echo "     SSH: Not configured"
    fi
    
    # GitHub auth status
    if command -v gh >/dev/null 2>&1; then
        if gh auth status --hostname github.com >/dev/null 2>&1; then
            local authenticated_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
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
    
    # Last used
    if [[ -n "$last_used" ]]; then
        echo "     Last used: $last_used"
    fi
    
    # Version info for debugging
    if [[ "$version" != "2" ]]; then
        echo "     Profile version: $version (consider updating)"
    fi
    
    return 0
}

# Helper function to run profile health check for all users
run_profile_health_check() {
    echo "🏥 Profile Health Check"
    echo ""
    
    if [[ ! -f "$GH_USERS_CONFIG" || ! -s "$GH_USERS_CONFIG" ]]; then
        echo "📋 No users configured yet"
        return 0
    fi
    
    local all_healthy=true
    
    while IFS= read -r username; do
        if [[ -n "$username" ]]; then
            local user_id=""
            if [[ -f "$GH_USERS_CONFIG" ]]; then
                user_id=$(grep -n "^$username$" "$GH_USERS_CONFIG" | cut -d: -f1)
            fi
            
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
                all_healthy=false
                
                # Suggest fixes
                if echo "$validation_result" | grep -q "GitHub authentication"; then
                    echo "   💡 Fix: Run 'gh auth login' and switch to $username"
                fi
                if echo "$validation_result" | grep -q "GPG key not found"; then
                    echo "   💡 Fix: Import GPG key or update profile"
                fi
                if echo "$validation_result" | grep -q "SSH key file not found"; then
                    echo "   💡 Fix: Create SSH key or update profile"
                fi
            fi
            echo ""
        fi
    done < "$GH_USERS_CONFIG"
    
    if [[ "$all_healthy" == "true" ]]; then
        echo "🎉 All profiles are healthy!"
    else
        echo "⚠️  Some profiles need attention. See suggestions above."
    fi
    
    return 0
}

# Helper function to update last used timestamp
update_profile_last_used() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        return 1
    fi
    
    local profile=$(get_user_profile "$username")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Extract current profile data
    local name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local gpg_key=$(echo "$profile" | grep "^gpg_key:" | cut -d':' -f2-)
    local ssh_key=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    local auto_sign=$(echo "$profile" | grep "^auto_sign:" | cut -d':' -f2-)
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    
    # Rewrite profile with updated timestamp
    write_profile_entry "$username" "$name" "$email" "$gpg_key" "$ssh_key" "$auto_sign" "$current_time" >/dev/null 2>&1
    return $?
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
    
    if [[ -z "$name" || -z "$email" ]]; then
        echo "❌ Invalid profile data for user: $username"
        return 1
    fi
    
    # Apply basic git config
    if ! apply_git_config "$name" "$email" "$scope"; then
        echo "❌ Failed to apply profile for user: $username"
        return 1
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
            echo "🔑 Applied GPG key: $gpg_key"
            
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
    
    # Update last used timestamp
    update_profile_last_used "$username"
    
    return 0
}

# Helper function to apply git configuration with validation
apply_git_config() {
    local name="$1"
    local email="$2"
    local scope="${3:-local}"  # 'local' or 'global'
    
    # Validate inputs
    if ! validate_profile_input "temp" "$name" "$email" "" ""; then
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

# Helper function to perform first-time setup
first_time_setup() {
    # Check if GitHub CLI is available and authenticated
    if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
        echo "⚠️  GitHub CLI not authenticated"
        echo "   Run 'gh auth login' to get started, then try again"
        return 1
    fi
    
    # Get current GitHub user
    local current_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
    if [[ -z "$current_user" ]]; then
        echo "❌ Could not detect current GitHub user"
        return 1
    fi
    
    echo "🎯 First-time setup detected!"
    echo "📝 Current GitHub user: $current_user"
    echo "💾 Creating profile from current git config..."
    
    # Add current user to the list (this will auto-create profile)
    add_user "$current_user" >/dev/null 2>&1
    
    # Assign current user to current project
    local project="$(basename "$PWD")"
    touch "$GH_PROJECT_CONFIG"
    grep -v "^$project=" "$GH_PROJECT_CONFIG" > "${GH_PROJECT_CONFIG}.tmp" 2>/dev/null || true
    echo "$project=$current_user" >> "${GH_PROJECT_CONFIG}.tmp"
    mv "${GH_PROJECT_CONFIG}.tmp" "$GH_PROJECT_CONFIG"
    
    echo "✅ Setup complete!"
    echo "   • Added $current_user to user list"
    echo "   • Created git config profile"
    echo "   • Assigned $current_user to project: $project"
    echo ""
    
    return 0
}

# Helper function to remove a user from the global list
#
# LIBRARY TRANSFORMATION NOTES:
# - Would become: gh_switcher_remove_user() with return codes instead of direct output
# - Cleanup operations would be separate functions: gh_switcher_cleanup_projects()
# - Would support dry-run mode to show what would be removed
# - Would handle namespace isolation automatically 
# - Would provide detailed removal report (what projects were affected)
remove_user() {
    local input="$1"
    if [[ -z "$input" ]]; then
        echo "❌ Usage: ghs remove-user <username_or_number>"
        echo "   Use 'ghs users' to see available users"
        return 1
    fi
    
    # Get username from ID or use directly
    local username=""
    local user_id=""
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        username=$(get_user_by_id "$input")
        if [[ $? -ne 0 ]]; then
            return 1
        fi
        user_id="$input"
        echo "💡 Removing user #$user_id: $username"
    else
        username="$input"
        # Find the user ID for display purposes
        if [[ -f "$GH_USERS_CONFIG" ]]; then
            user_id=$(grep -n "^$username$" "$GH_USERS_CONFIG" | cut -d: -f1)
        fi
    fi
    
    # Check if user exists in our list
    # LIBRARY NOTE: Would need to ensure config file exists and handle gracefully
    if [[ ! -f "$GH_USERS_CONFIG" ]] || ! grep -q "^$username$" "$GH_USERS_CONFIG" 2>/dev/null; then
        echo "❌ User $username not found in user list"
        echo "   Use 'ghs users' to see available users"
        return 1
    fi
    
    # Check if user is currently active (warn but don't block)
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        local current_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
        if [[ "$username" == "$current_user" ]]; then
            echo "⚠️  Warning: You're removing the currently active GitHub user"
        fi
    fi
    
    # Remove user from list
    # LIBRARY NOTE: Would need atomic write operation with proper error handling
    if [[ -f "$GH_USERS_CONFIG" ]]; then
        grep -v "^$username$" "$GH_USERS_CONFIG" > "${GH_USERS_CONFIG}.tmp" 2>/dev/null || true
        mv "${GH_USERS_CONFIG}.tmp" "$GH_USERS_CONFIG"
    fi
    
    # Clean up project configurations that reference this user
    local affected_projects=""
    if [[ -f "$GH_PROJECT_CONFIG" ]]; then
        affected_projects=$(grep "=$username$" "$GH_PROJECT_CONFIG" | cut -d'=' -f1 | tr '\n' ' ')
        grep -v "=$username$" "$GH_PROJECT_CONFIG" > "${GH_PROJECT_CONFIG}.tmp" 2>/dev/null || true
        mv "${GH_PROJECT_CONFIG}.tmp" "$GH_PROJECT_CONFIG"
    fi
    
    # Report results
    echo "✅ Removed $username from user list"
    if [[ -n "$affected_projects" ]]; then
        echo "🧹 Cleaned up project configurations: $affected_projects"
        echo "   These projects now have no default user configured"
    fi
    
    # Show updated list
    # LIBRARY NOTE: This UI coupling would be removed - caller decides what to show
    echo ""
    list_users
}

# Simple GitHub project switcher function
#
# LIBRARY TRANSFORMATION NOTES:
# This main function would be split into:
# 1. gh_switcher_main() - CLI interface (current behavior)
# 2. Core API functions - for programmatic use
# 3. UI functions - for customizable presentation
#
# Library structure would be:
# - gh_switcher_init(namespace, config_dir)
# - gh_switcher_add_user(username) -> return code
# - gh_switcher_get_users() -> structured data
# - gh_switcher_set_project(project, user) -> return code
# - gh_switcher_get_project_user(project) -> username
# - gh_switcher_switch_user(username) -> return code
# - gh_switcher_get_status() -> structured data
#
# Current project detection would be configurable:
# - Default: $(basename "$PWD") 
# - Override: GH_SWITCHER_PROJECT_NAME environment variable
# - API: gh_switcher_set_project_detector(function_name)
ghs() {
    local cmd="${1:-dashboard}"
    local project="$(basename "$PWD")"  # LIBRARY NOTE: Would be configurable
    
    case "$cmd" in
        "remove-user"|"rm-user")
            remove_user "$2"
            ;;
            
        "users"|"list-users")
            list_users
            ;;
            
        "profiles")
            if [[ ! -f "$GH_USER_PROFILES" || ! -s "$GH_USER_PROFILES" ]]; then
                echo "📋 No user profiles configured yet"
                echo "   Profiles are created automatically when you add/switch users"
                return 0
            fi
            
            echo "📋 GitHub Account Profiles:"
            echo ""
            
            # Get current user for highlighting
            local current_user=""
            if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                current_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
            fi
            
            # Try migration first
            migrate_old_profile_format
            
            # Display each user with rich profile information
            if [[ -f "$GH_USERS_CONFIG" ]]; then
                while IFS= read -r username; do
                    if [[ -n "$username" ]]; then
                        display_rich_profile "$username" "$current_user"
                        echo ""
                    fi
                done < "$GH_USERS_CONFIG"
            fi
            ;;
            
        "update-profile"|"edit")
            local input="$2"
            if [[ -z "$input" ]]; then
                echo "❌ Usage: ghs edit <username_or_number>"
                echo "   Use 'ghs profiles' to see available profiles"
                return 1
            fi
            
            local username=""
            if [[ "$input" =~ ^[0-9]+$ ]]; then
                username=$(get_user_by_id "$input")
                if [[ $? -ne 0 ]]; then
                    return 1
                fi
            else
                username="$input"
            fi
            
            # Get current profile data
            local profile=$(get_user_profile "$username")
            if [[ $? -ne 0 ]]; then
                echo "❌ No profile found for $username"
                return 1
            fi
            
            local current_name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
            local current_email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
            local current_gpg_key=$(echo "$profile" | grep "^gpg_key:" | cut -d':' -f2-)
            local current_ssh_key=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
            local current_auto_sign=$(echo "$profile" | grep "^auto_sign:" | cut -d':' -f2-)
            
            echo "📝 Editing profile: $username"
            echo ""
            echo "Current values:"
            echo "1. Name: $current_name"
            echo "2. Email: $current_email"
            echo "3. GPG Key: $current_gpg_key"
            echo "4. SSH Key: $current_ssh_key"
            echo "5. Auto-sign: $current_auto_sign"
            echo ""
            
            while true; do
                read -p "Select field to edit (1-5, s to save, c to cancel): " choice
                case "$choice" in
                    1)
                        read -p "Enter new name [$current_name]: " new_name
                        if [[ -n "$new_name" ]]; then
                            current_name="$new_name"
                            echo "✅ Name updated"
                        fi
                        ;;
                    2)
                        read -p "Enter new email [$current_email]: " new_email
                        if [[ -n "$new_email" ]]; then
                            current_email="$new_email"
                            echo "✅ Email updated"
                        fi
                        ;;
                    3)
                        read -p "Enter new GPG key [$current_gpg_key]: " new_gpg_key
                        if [[ -n "$new_gpg_key" ]]; then
                            if validate_gpg_key "$new_gpg_key"; then
                                current_gpg_key="$new_gpg_key"
                                echo "✅ GPG key updated and validated"
                            else
                                current_gpg_key="$new_gpg_key"
                                echo "⚠️  GPG key updated but not found in keyring"
                            fi
                        elif [[ "$new_gpg_key" == "" ]]; then
                            current_gpg_key=""
                            echo "✅ GPG key cleared"
                        fi
                        ;;
                    4)
                        read -p "Enter new SSH key path [$current_ssh_key]: " new_ssh_key
                        if [[ -n "$new_ssh_key" ]]; then
                            current_ssh_key="$new_ssh_key"
                            if [[ -f "$new_ssh_key" ]]; then
                                echo "✅ SSH key updated and verified"
                            else
                                echo "⚠️  SSH key updated but file not found"
                            fi
                        elif [[ "$new_ssh_key" == "" ]]; then
                            current_ssh_key=""
                            echo "✅ SSH key cleared"
                        fi
                        ;;
                    5)
                        read -p "Enable auto-sign commits? (y/n) [$current_auto_sign]: " auto_sign_choice
                        case "$auto_sign_choice" in
                            y|Y|yes|true)
                                current_auto_sign="true"
                                echo "✅ Auto-sign enabled"
                                ;;
                            n|N|no|false)
                                current_auto_sign="false"
                                echo "✅ Auto-sign disabled"
                                ;;
                            "")
                                # Keep current value
                                ;;
                            *)
                                echo "❌ Invalid choice. Use y/n"
                                ;;
                        esac
                        ;;
                    s|S|save)
                        # Save the profile
                        if write_profile_entry "$username" "$current_name" "$current_email" "$current_gpg_key" "$current_ssh_key" "$current_auto_sign"; then
                            echo "✅ Profile saved successfully"
                            return 0
                        else
                            echo "❌ Failed to save profile"
                            return 1
                        fi
                        ;;
                    c|C|cancel)
                        echo "❌ Cancelled without saving"
                        return 0
                        ;;
                    *)
                        echo "❌ Invalid choice. Use 1-5, s, or c"
                        ;;
                esac
                echo ""
            done
            ;;
            
        "validate")
            if [[ -n "$2" ]]; then
                # Validate specific user
                local input="$2"
                local username=""
                if [[ "$input" =~ ^[0-9]+$ ]]; then
                    username=$(get_user_by_id "$input")
                    if [[ $? -ne 0 ]]; then
                        return 1
                    fi
                else
                    username="$input"
                fi
                
                echo "🏥 Validating profile: $username"
                echo ""
                validate_profile_completeness "$username"
            else
                # Validate all users
                run_profile_health_check
            fi
            ;;
            
        "add-user")
            # Enhanced add-user with auto-detection
            local username="$2"
            if [[ -z "$username" ]]; then
                echo "❌ Usage: ghs add-user <username>"
                echo "   Use 'current' to add the currently authenticated GitHub user"
                return 1
            fi
            
            # Handle "current" special case
            if [[ "$username" == "current" ]]; then
                if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                    username=$(gh api user --jq '.login' 2>/dev/null || echo "")
                    if [[ -z "$username" ]]; then
                        echo "❌ Could not detect current GitHub user"
                        return 1
                    fi
                    echo "💡 Adding current GitHub user: $username"
                else
                    echo "❌ GitHub CLI not authenticated or not installed"
                    return 1
                fi
            fi
            
            # Check if user already exists
            if [[ -f "$GH_USERS_CONFIG" ]] && grep -q "^$username$" "$GH_USERS_CONFIG" 2>/dev/null; then
                echo "⚠️  User $username already exists"
                read -p "Do you want to recreate the profile with auto-detection? (y/n): " recreate
                if [[ "$recreate" != "y" && "$recreate" != "Y" ]]; then
                    return 0
                fi
            else
                # Add to user list
                echo "$username" >> "$GH_USERS_CONFIG"
                echo "✅ Added $username to user list"
            fi
            
            # Auto-detect configuration
            echo "🔍 Detecting current git configuration..."
            local current_config=$(detect_git_config "auto")
            if [[ $? -eq 0 ]]; then
                local detected_name=$(echo "$current_config" | grep "^name:" | cut -d':' -f2-)
                local detected_email=$(echo "$current_config" | grep "^email:" | cut -d':' -f2-)
                local detected_gpg_key=$(detect_gpg_key "auto")
                local detected_auto_sign=$(detect_auto_sign "auto")
                local detected_ssh_key=$(detect_ssh_key "$username")
                
                echo ""
                echo "📋 Found git config:"
                echo "   Name: $detected_name"
                echo "   Email: $detected_email"
                if [[ -n "$detected_gpg_key" ]]; then
                    echo "   GPG Key: $detected_gpg_key"
                    echo "   Auto-sign: $detected_auto_sign"
                fi
                if [[ -n "$detected_ssh_key" ]]; then
                    echo "   SSH Key: $detected_ssh_key"
                fi
                echo ""
                
                read -p "Use these values for $username profile? (y/n/edit): " choice
                case "$choice" in
                    y|Y|yes)
                        create_user_profile "$username" "$detected_name" "$detected_email" "false" "$detected_gpg_key" "$detected_ssh_key" "$detected_auto_sign"
                        ;;
                    e|E|edit)
                        # Create with detected values then open editor
                        create_user_profile "$username" "$detected_name" "$detected_email" "false" "$detected_gpg_key" "$detected_ssh_key" "$detected_auto_sign"
                        echo ""
                        echo "Opening profile editor..."
                        ghs edit "$username"
                        ;;
                    *)
                        # Manual entry
                        echo "📝 Manual profile creation:"
                        read -p "Enter name: " manual_name
                        read -p "Enter email: " manual_email
                        read -p "Enter GPG key (optional): " manual_gpg_key
                        read -p "Enter SSH key path (optional): " manual_ssh_key
                        read -p "Enable auto-sign commits? (y/n): " manual_auto_sign
                        
                        case "$manual_auto_sign" in
                            y|Y|yes)
                                manual_auto_sign="true"
                                ;;
                            *)
                                manual_auto_sign="false"
                                ;;
                        esac
                        
                        create_user_profile "$username" "$manual_name" "$manual_email" "false" "$manual_gpg_key" "$manual_ssh_key" "$manual_auto_sign"
                        ;;
                esac
            else
                echo "⚠️  Could not detect git configuration"
                echo "📝 Manual profile creation:"
                read -p "Enter name: " manual_name
                read -p "Enter email: " manual_email
                
                if [[ -z "$manual_name" || -z "$manual_email" ]]; then
                    echo "❌ Name and email are required"
                    return 1
                fi
                
                create_user_profile "$username" "$manual_name" "$manual_email" "false"
            fi
            
            echo ""
            list_users
            ;;
            
        "switch")
            local user_id="$2"
            if [[ -z "$user_id" ]]; then
                echo "❌ Usage: ghs switch <user_number>"
                echo "   Use 'ghs users' to see available users"
                return 1
            fi
            
            local username=$(get_user_by_id "$user_id")
            if [[ $? -eq 0 ]]; then
                # Switch to the user first
                if gh auth switch --user "$username" 2>/dev/null; then
                    echo "✅ Switched to $username (#$user_id)"
                    
                    # Check if user has a profile
                    local profile=$(get_user_profile "$username")
                    if [[ $? -eq 0 ]]; then
                        # Profile exists - apply it automatically
                        if apply_user_profile "$username" "local"; then
                            local name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
                            local email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
                            echo "🔧 Applied git config: $name <$email>"
                        else
                            echo "⚠️  Could not apply git config profile (continuing with GitHub switch)"
                        fi
                    else
                        # No profile exists - create one from current config
                        echo "💡 Creating profile for $username from current git config"
                        if create_user_profile "$username" "" "" "true"; then
                            # Now apply the newly created profile
                            if apply_user_profile "$username" "local"; then
                                echo "🔧 Applied newly created git config profile"
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
            ;;
            
        "assign")
            local input="$2"
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
            ;;
            
        "list")
            if [[ -f "$GH_PROJECT_CONFIG" && -s "$GH_PROJECT_CONFIG" ]]; then
                echo "📋 Configured project accounts:"
                while IFS='=' read -r proj user; do
                    if [[ -n "$proj" && -n "$user" ]]; then
                        # Try to find user ID if it exists in users list
                        local user_id=""
                        if [[ -f "$GH_USERS_CONFIG" ]]; then
                            user_id=$(grep -n "^$user$" "$GH_USERS_CONFIG" | cut -d: -f1)
                        fi
                        
                        local user_display="$user"
                        if [[ -n "$user_id" ]]; then
                            user_display="$user (#$user_id)"
                        fi
                        
                        if [[ "$proj" == "$project" ]]; then
                            echo "  🟢 $proj → $user_display (current project)"
                        else
                            echo "  ⚪ $proj → $user_display"
                        fi
                    fi
                done < "$GH_PROJECT_CONFIG"
            else
                echo "📋 No project accounts configured yet"
                echo "   Use 'ghs assign <username_or_number>' to configure current project"
            fi
            ;;
            
        "status")
            echo "📍 Current project: $project"
            if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                local current_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
                
                # Try to find current user ID
                local current_user_id=""
                if [[ -f "$GH_USERS_CONFIG" ]]; then
                    current_user_id=$(grep -n "^$current_user$" "$GH_USERS_CONFIG" | cut -d: -f1)
                fi
                
                if [[ -n "$current_user_id" ]]; then
                    echo "🔑 Current GitHub user: $current_user (#$current_user_id)"
                else
                    echo "🔑 Current GitHub user: $current_user"
                fi
                
                local project_user=""
                if [[ -f "$GH_PROJECT_CONFIG" ]]; then
                    project_user=$(grep "^$project=" "$GH_PROJECT_CONFIG" 2>/dev/null | cut -d'=' -f2)
                fi
                
                if [[ -n "$project_user" ]]; then
                    # Try to find project user ID
                    local project_user_id=""
                    if [[ -f "$GH_USERS_CONFIG" ]]; then
                        project_user_id=$(grep -n "^$project_user$" "$GH_USERS_CONFIG" | cut -d: -f1)
                    fi
                    
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
            ;;
            
        "install")
            # Install the switcher to shell profile
            local shell_profile=""
            # Detect shell more reliably
            if [[ "$SHELL" == *"zsh"* ]] || [[ -n "$ZSH_VERSION" ]]; then
                shell_profile="$HOME/.zshrc"
            elif [[ "$SHELL" == *"bash"* ]] || [[ -n "$BASH_VERSION" ]]; then
                shell_profile="$HOME/.bashrc"
            else
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
            local shell_profile=""
            # Detect shell more reliably
            if [[ "$SHELL" == *"zsh"* ]] || [[ -n "$ZSH_VERSION" ]]; then
                shell_profile="$HOME/.zshrc"
            elif [[ "$SHELL" == *"bash"* ]] || [[ -n "$BASH_VERSION" ]]; then
                shell_profile="$HOME/.bashrc"
            else
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
            
        "help"|"-h"|"--help")
            # Show help
            echo "🎯 GitHub Project Switcher (ghs)"
            echo ""
            echo "Global GitHub account switching with numbered users and project memory."
            echo ""
            echo "INSTALLATION:"
            echo "  ghs install                Install to shell profile (auto-detects zsh/bash)"
            echo "  ghs uninstall              Remove from shell profile"
            echo ""
            echo "SETUP:"
            echo "  ghs add-user <username>    Add user with auto-detection of git config"
            echo "  ghs add-user current       Add currently authenticated GitHub user"
            echo ""
            echo "DAILY WORKFLOW:"
            echo "  ghs                        Show smart dashboard"
            echo "  ghs switch <number>        Switch to user by number"
            echo "  ghs assign <number>        Assign user as project default"
            echo ""
            echo "USER MANAGEMENT:"
            echo "  ghs users                  Show numbered list of users"
            echo "  ghs remove-user <user>     Remove user by name or number"
            echo "  ghs profiles               Show rich user profiles with health status"
            echo "  ghs edit <user>            Interactive profile editing"
            echo "  ghs validate [user]        Run profile health check (all users or specific)"
            echo ""
            echo "PROJECT & STATUS:"
            echo "  ghs status                 Show detailed current status"
            echo "  ghs list                   List all configured projects"
            ;;
            
        *)
            # Default action: show smart dashboard
            # 
            # LIBRARY TRANSFORMATION NOTES:
            # This entire dashboard would become: gh_switcher_show_dashboard()
            # The data gathering would be separate from presentation:
            # 
            # Core data functions:
            # - gh_switcher_get_current_project() -> string
            # - gh_switcher_get_current_user() -> string  
            # - gh_switcher_get_project_preference(project) -> string
            # - gh_switcher_get_users() -> structured data
            # - gh_switcher_check_gh_status() -> boolean + details
            #
            # UI functions (customizable):
            # - gh_switcher_format_project_status()
            # - gh_switcher_format_user_list() 
            # - gh_switcher_format_quick_actions()
            # - gh_switcher_format_dashboard() (orchestrates all above)
            #
            # This allows:
            # - Custom branding/colors per tool
            # - Different output formats (JSON, plain text, etc.)
            # - Integration with other tools' UIs
            
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
            
            if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                local current_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
                
                # Try to find current user ID
                local current_user_id=""
                local user_in_list=false
                if [[ -f "$GH_USERS_CONFIG" ]]; then
                    current_user_id=$(grep -n "^$current_user$" "$GH_USERS_CONFIG" | cut -d: -f1)
                    if [[ -n "$current_user_id" ]]; then
                        user_in_list=true
                    fi
                fi
                
                if [[ "$user_in_list" == true ]]; then
                    echo "🔑 Current user: $current_user (#$current_user_id)"
                    
                    # Show git config status
                    local profile=$(get_user_profile "$current_user")
                    if [[ $? -eq 0 ]]; then
                        local current_git_config=$(detect_git_config "auto")
                        if [[ $? -eq 0 ]]; then
                            local current_git_name=$(echo "$current_git_config" | grep "^name:" | cut -d':' -f2-)
                            local current_git_email=$(echo "$current_git_config" | grep "^email:" | cut -d':' -f2-)
                            
                            local profile_name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
                            local profile_email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
                            
                            if [[ -n "$current_git_name" && -n "$current_git_email" ]]; then
                                if [[ "$current_git_name" == "$profile_name" && "$current_git_email" == "$profile_email" ]]; then
                                    echo "🔧 Git config: ✅ matches profile"
                                else
                                    echo "🔧 Git config: ⚠️  mismatch ($current_git_name <$current_git_email>)"
                                fi
                            else
                                echo "🔧 Git config: ❌ not configured"
                            fi
                        else
                            echo "🔧 Git config: ❌ git not available"
                        fi
                    else
                        echo "🔧 Git config: ❓ no profile"
                    fi
                else
                    echo "🔑 Current user: $current_user"
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
                    local project_user_id=""
                    if [[ -f "$GH_USERS_CONFIG" ]]; then
                        project_user_id=$(grep -n "^$project_user$" "$GH_USERS_CONFIG" | cut -d: -f1)
                    fi
                    
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
            if [[ -f "$GH_USERS_CONFIG" && -s "$GH_USERS_CONFIG" ]]; then
                echo "📋 Available users:"
                local i=1
                while IFS= read -r username; do
                    if [[ -n "$username" ]]; then
                        if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                            local current_user=$(gh api user --jq '.login' 2>/dev/null || echo "")
                            if [[ "$username" == "$current_user" ]]; then
                                echo "  🟢 $i. $username (current)"
                            else
                                echo "  ⚪ $i. $username"
                            fi
                        else
                            echo "  ⚪ $i. $username"
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
# LIBRARY TRANSFORMATION NOTES - PACKAGE DISTRIBUTION:
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
# - Detect existing ~/.gh-* files 
# - Offer to migrate to new structure
# - Provide uninstall script
# - Backward compatibility mode
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
        # Show help
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
        echo "Commands:"
        echo "  (no args)          Show smart dashboard with current status & quick actions"
        echo "  status             Show detailed current status"
        echo "  assign <user_or_id> Assign account as project default"
        echo "  list               List all configured projects"
        echo ""
        echo "Installation:"
        echo "  install            Install to shell profile (auto-detects zsh/bash)"
        echo "  uninstall          Remove from shell profile"
        echo ""
        echo "User Management:"
        echo "  add-user <user>    Add a user to the numbered list (use 'current' for active user)"
        echo "  remove-user <user> Remove a user from the list (by name or number)"
        echo "  users              Show numbered list of users"
        echo "  switch <number>    Switch to user by number"
        echo ""
        echo "  help               Show this help message"
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