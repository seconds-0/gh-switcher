# Using gh-switcher with POSIX shells (dash, sh)

gh-switcher requires bash-specific features and cannot be directly sourced in POSIX shells like dash or `/bin/sh`.

## Why bash is required

gh-switcher uses several bash features that aren't available in POSIX sh:
- `[[` conditional expressions
- Regular expression matching with `=~`
- String length operations `${#var}`
- Arrays (in some functions)

## How to use gh-switcher from POSIX shells

If your default shell is dash or another POSIX shell, you can still use gh-switcher by invoking it through bash:

### Option 1: Create an alias

Add to your shell configuration:
```sh
alias ghs='bash -c "source /path/to/gh-switcher.sh && ghs \"\$@\"" --'
```

### Option 2: Create a wrapper script

Create a file called `ghs` in your PATH:
```sh
#!/bin/sh
exec bash -c "source /path/to/gh-switcher.sh && ghs \"\$@\"" -- "$@"
```

Make it executable:
```sh
chmod +x /path/to/ghs
```

### Option 3: Use bash directly

For one-off commands:
```sh
bash -c "source /path/to/gh-switcher.sh && ghs switch myuser"
```

## Docker and CI environments

Many Docker containers use `/bin/sh` linked to dash for performance. In these environments:

1. Ensure bash is installed:
   ```dockerfile
   RUN apt-get update && apt-get install -y bash
   ```

2. Use bash explicitly in scripts:
   ```sh
   #!/bin/bash
   source /path/to/gh-switcher.sh
   ghs switch myuser
   ```

## Common errors

If you see these errors, you're trying to run gh-switcher in a POSIX shell:
- `[[: not found`
- `Syntax error: "(" unexpected`
- `Bad substitution`

The solution is always to invoke gh-switcher through bash as shown above.