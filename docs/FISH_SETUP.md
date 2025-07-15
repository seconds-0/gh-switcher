# Fish Shell Setup for gh-switcher

Since Fish shell has a different syntax than Bash/Zsh, gh-switcher requires a wrapper function to work in Fish.

## Quick Setup

### Option 1: Use the built-in setup command (Easiest)

If gh-switcher is already installed and available in your current shell:

```bash
ghs fish-setup
```

This will automatically:
- Find your gh-switcher installation
- Create the Fish wrapper function
- Show you the next steps

### Option 2: Manual Automatic Setup

Run this command to automatically detect gh-switcher and create the wrapper:

```fish
# This will auto-detect your gh-switcher installation and set it up
set -l GHS_PATH ""

# Check npm global install
if command -q npm
    set -l npm_path (npm root -g 2>/dev/null)/gh-switcher/gh-switcher.sh
    test -f "$npm_path" && set GHS_PATH "$npm_path"
end

# Check Homebrew install
if test -z "$GHS_PATH" && command -q brew
    set -l brew_path (brew --prefix 2>/dev/null)/bin/gh-switcher.sh
    test -f "$brew_path" && set GHS_PATH "$brew_path"
end

# Check common locations
if test -z "$GHS_PATH"
    for path in ~/gh-switcher/gh-switcher.sh ~/.gh-switcher/gh-switcher.sh /usr/local/bin/gh-switcher.sh
        if test -f "$path"
            set GHS_PATH "$path"
            break
        end
    end
end

# Create the wrapper function
if test -n "$GHS_PATH"
    mkdir -p ~/.config/fish/functions
    echo "function ghs
    set -l script_path '$GHS_PATH'
    if not test -f \"\$script_path\"
        echo \"Error: gh-switcher.sh not found at \$script_path\" >&2
        echo \"Please update ~/.config/fish/functions/ghs.fish with the correct path\" >&2
        return 1
    end
    bash -c \"source '\$script_path' && ghs \\\$argv\"
end" > ~/.config/fish/functions/ghs.fish
    echo "✅ Fish setup complete! gh-switcher found at: $GHS_PATH"
    echo "   You can now use 'ghs' commands in new Fish sessions."
else
    echo "❌ Could not find gh-switcher.sh automatically."
    echo "   Please use manual setup below."
end
```

### Manual Setup (if automatic fails)

If the automatic setup doesn't work, find your installation manually:

```fish
# Find gh-switcher.sh on your system
find ~ -name "gh-switcher.sh" 2>/dev/null | head -5

# Once you find it, set the path:
set GHS_PATH /path/to/gh-switcher.sh

# Create the wrapper function
mkdir -p ~/.config/fish/functions
echo "function ghs
    set -l script_path '$GHS_PATH'
    if not test -f \"\$script_path\"
        echo \"Error: gh-switcher.sh not found at \$script_path\" >&2
        echo \"Please update ~/.config/fish/functions/ghs.fish with the correct path\" >&2
        return 1
    end
    bash -c \"source '\$script_path' && ghs \\\$argv\"
end" > ~/.config/fish/functions/ghs.fish
```

### 3. Test it works

The function will be automatically available in all new Fish sessions. Test it:

```fish
ghs --help
```

## Optional: Tab Completions

For basic tab completion support:

```fish
mkdir -p ~/.config/fish/completions
cat > ~/.config/fish/completions/ghs.fish << 'EOF'
complete -c ghs -f
complete -c ghs -n "__fish_use_subcommand" -a "status" -d "Show current GitHub user"
complete -c ghs -n "__fish_use_subcommand" -a "switch" -d "Switch GitHub user"
complete -c ghs -n "__fish_use_subcommand" -a "add" -d "Add a new GitHub user"
complete -c ghs -n "__fish_use_subcommand" -a "remove" -d "Remove a GitHub user"
complete -c ghs -n "__fish_use_subcommand" -a "users" -d "List all users"
complete -c ghs -n "__fish_use_subcommand" -a "guard" -d "Manage guard hooks"
complete -c ghs -n "__fish_use_subcommand" -a "assign" -d "Assign user to directory"
complete -c ghs -n "__fish_use_subcommand" -a "edit" -d "Edit user profile"
complete -c ghs -n "__fish_use_subcommand" -a "show" -d "Show user details"
complete -c ghs -n "__fish_use_subcommand" -a "test-ssh" -d "Test SSH key"
EOF
```

## Usage

Once set up, use `ghs` commands as normal:

```fish
ghs status
ghs add myuser
ghs switch myuser
# etc.
```

## Limitations

- The wrapper executes in a Bash subshell, so Fish-specific features (like universal variables) won't affect gh-switcher
- Shell startup time is slightly increased due to the wrapper
- Some error messages may reference Bash syntax

## Updating gh-switcher

When you update gh-switcher (via npm, brew, or git pull), the wrapper function automatically uses the new version. No changes needed!

If you move gh-switcher to a different location:
1. Find the new path (see step 1 above)
2. Update the wrapper function by running the setup again
3. Or manually edit: `~/.config/fish/functions/ghs.fish`


## Troubleshooting

If `ghs` command is not found:
1. Check that the function file exists: `ls ~/.config/fish/functions/ghs.fish`
2. Verify the path in the function is correct
3. Start a new Fish session or run: `source ~/.config/fish/functions/ghs.fish`

If you get "gh-switcher.sh not found" errors:
1. Verify gh-switcher is installed: `find ~ -name "gh-switcher.sh" 2>/dev/null`
2. Update the path in `~/.config/fish/functions/ghs.fish`
3. Make sure the file is executable: `chmod +x /path/to/gh-switcher.sh`