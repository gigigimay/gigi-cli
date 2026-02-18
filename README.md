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
gigi skip <files...>        # Skip file(s) and save to list
gigi skip -t <files...>     # Skip file(s) without saving (temporary)
gigi skip -d                # Skip all modified files and save to list
gigi skip -d -t             # Skip all modified files without saving
gigi skip                   # Re-apply skip to all saved files
```

### Unskip files

```bash
gigi unskip <files...>      # Unskip file(s) and remove from list
gigi unskip -t <files...>   # Unskip file(s) without removing from list
gigi unskip                 # Unskip all saved files and clear list
gigi unskip -t              # Unskip all saved files (list remains)
gigi unskip -a              # Unskip all skip-worktree files (from git)
```

### Shortcuts

```bash
gigi save                   # Save all unsaved skip-worktree files to list
gigi reset                  # Unskip all skip-worktree files and clear list
```

### Manage the list

```bash
gigi ls                     # List skip-worktree files (saved & not saved)
gigi path                   # Print the list file path
gigi edit                   # Open the list file in $EDITOR (defaults to cursor)
```

## How it works

- **Skip/unskip** runs `git update-index --skip-worktree` / `--no-skip-worktree`.
- By default, skip/unskip **saves to / removes from** the tracking file at `.git/skip-worktree-files`.
- **`-t` flag** makes the action temporary -- the list is not modified.
- **`-a` flag** operates on all files git has marked, not just the saved list.
- **`gigi skip`** (no args) re-applies all saved skips, handy after switching branches.
- **`gigi save`** retroactively saves any unsaved skip-worktree files to the list.
- **`gigi reset`** unskips everything and clears the list.
- File paths are always normalized to repo-relative paths.

The tracking file lives inside `.git/`, so it's per-repo and never committed.
