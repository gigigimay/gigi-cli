# gigi-cli

A tiny shell utility for managing `git update-index --skip-worktree` files.

Useful when you have local modifications (mock data, debug configs, etc.) that you don't want showing up in `git status`.

## Setup

Add this to your `~/.zshrc` (or `~/.bashrc`):

```bash
[ -f "$HOME/Projects/gigi-cli/gigi.zsh" ] && source "$HOME/Projects/gigi-cli/gigi.zsh"
```

Then reload your shell:

```bash
source ~/.zshrc
```

## Usage

### Skip files

```bash
gigi skip <files...>        # Skip file(s) (temporary, not saved)
gigi skip -s <files...>     # Skip file(s) and save to list
gigi skip                   # Re-apply skip to all saved files
```

### Unskip files

```bash
gigi unskip <files...>      # Unskip file(s)
gigi unskip -s <files...>   # Unskip file(s) and remove from list
gigi unskip                 # Unskip all saved files (list remains)
gigi unskip -s              # Unskip all saved files and clear the list
gigi unskip -a              # Unskip all skip-worktree files (from git)
```

### Shortcuts

```bash
gigi reset                  # Unskip all skip-worktree files and clear list
```

### Manage the list

```bash
gigi ls                     # List saved file paths
gigi ls -a                  # List all skip-worktree files (saved & not saved)
gigi path                   # Print the list file path
gigi edit                   # Open the list file in $EDITOR (defaults to cursor)
```

## How it works

- **Skip/unskip** runs `git update-index --skip-worktree` / `--no-skip-worktree`.
- **`-s` flag** persists the action to a tracking file at `.git/skip-worktree-files`.
- Without `-s`, the skip/unskip is ephemeral -- the list is not modified.
- **`-a` flag** operates on all files git has marked, not just the saved list.
- **`gigi skip`** (no args) re-applies all saved skips, handy after switching branches.
- **`gigi reset`** is a shortcut for unskipping everything and clearing the list.
- File paths are always normalized to repo-relative paths.

The tracking file lives inside `.git/`, so it's per-repo and never committed.
