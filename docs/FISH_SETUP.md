# Fish Shell Setup for gh-switcher

Since Fish shell has a different syntax than Bash/Zsh, gh-switcher requires a wrapper function to work in Fish.

## Quick Setup

1. Create the wrapper function:
```fish
mkdir -p ~/.config/fish/functions
echo 'function ghs
    bash -c "source /path/to/gh-switcher.sh && ghs $argv"
end' > ~/.config/fish/functions/ghs.fish
```

2. Replace `/path/to/gh-switcher.sh` with the actual path to your gh-switcher installation.

3. The function will be automatically available in all new Fish sessions.

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

## Troubleshooting

If `ghs` command is not found:
1. Check that the function file exists: `ls ~/.config/fish/functions/ghs.fish`
2. Verify the path in the function is correct
3. Start a new Fish session or run: `source ~/.config/fish/functions/ghs.fish`