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
        "add-user")
            add_user "$2"
            ;;
            
        "remove-user"|"rm-user")
            remove_user "$2"
            ;;
            
        "users"|"list-users")
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
                # Switch to the user
                if gh auth switch --user "$username" 2>/dev/null; then
                    echo "✅ Switched to $username (#$user_id)"
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
            echo "  ghs add-user <username>    Add a user to the numbered list"
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