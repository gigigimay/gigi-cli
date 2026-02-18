gigi() {
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Not a git repository"; return 1; }
  local track_file="$git_root/.git/skip-worktree-files"

  _gigi_relpath() {
    local p="$1"
    if [[ "$p" = /* ]]; then
      p="${p#$git_root/}"
    fi
    p="${p#./}"
    echo "$p"
  }

  case "$1" in
    skip)
      local temp=false
      local dirty=false
      shift
      while [ $# -gt 0 ]; do
        case "$1" in
          -t|--temp) temp=true; shift ;;
          -d|--dirty) dirty=true; shift ;;
          *) break ;;
        esac
      done

      if [ "$dirty" = true ]; then
        if [ -n "$1" ]; then
          echo "Error: -d cannot be used with file paths"
          return 1
        fi
        local changed
        changed=$(git diff --name-only; git diff --cached --name-only)
        changed=$(echo "$changed" | sort -u)
        if [ -z "$changed" ]; then
          echo "No modified files."
          return 0
        fi
        echo "$changed" | while IFS= read -r f; do
          [ -z "$f" ] && continue
          git update-index --skip-worktree "$f" && {
            if [ "$temp" = false ]; then
              echo "$f" >> "$track_file"
              echo "Skipped (saved): $f"
            else
              echo "Skipped: $f"
            fi
          }
        done
        if [ "$temp" = false ] && [ -f "$track_file" ]; then
          sort -u "$track_file" -o "$track_file"
        fi
      elif [ -z "$1" ]; then
        if [ "$temp" = true ]; then
          echo "Error: -t requires at least one file path"
          return 1
        fi
        if [ ! -f "$track_file" ] || [ ! -s "$track_file" ]; then
          echo "No saved files to skip."
          return 0
        fi
        local already_skipped
        already_skipped=$(git ls-files -v | grep '^S' | cut -c3-)
        while IFS= read -r file; do
          [ -z "$file" ] && continue
          if [ -n "$already_skipped" ] && echo "$already_skipped" | grep -Fxq "$file"; then
            echo "Already skipped: $file"
          else
            git update-index --skip-worktree "$file" && echo "Skipped: $file"
          fi
        done < "$track_file"
      else
        for raw in "$@"; do
          local f=$(_gigi_relpath "$raw")
          git update-index --skip-worktree "$f" && {
            if [ "$temp" = false ]; then
              echo "$f" >> "$track_file"
              echo "Skipped (saved): $f"
            else
              echo "Skipped: $f"
            fi
          }
        done
        if [ "$temp" = false ] && [ -f "$track_file" ]; then
          sort -u "$track_file" -o "$track_file"
        fi
      fi
      ;;
    unskip)
      local temp=false
      local all=false
      shift
      while [ $# -gt 0 ]; do
        case "$1" in
          -a|--all) all=true; shift ;;
          -t|--temp) temp=true; shift ;;
          *) break ;;
        esac
      done

      if [ "$all" = true ]; then
        if [ -n "$1" ]; then
          echo "Error: -a cannot be used with file paths"
          return 1
        fi
        local files
        files=$(git ls-files -v | grep '^S' | cut -c3-)
        if [ -z "$files" ]; then
          echo "No skip-worktree files."
          return 0
        fi
        echo "$files" | while IFS= read -r file; do
          git update-index --no-skip-worktree "$file" && echo "Unskipped: $file"
        done
      elif [ -z "$1" ]; then
        if [ ! -f "$track_file" ] || [ ! -s "$track_file" ]; then
          echo "No saved files to unskip."
          return 0
        fi
        while IFS= read -r file; do
          [ -z "$file" ] && continue
          git update-index --no-skip-worktree "$file" && echo "Unskipped: $file"
        done < "$track_file"
        if [ "$temp" = false ]; then
          rm "$track_file"
          echo "List cleared."
        fi
      else
        for raw in "$@"; do
          local f=$(_gigi_relpath "$raw")
          git update-index --no-skip-worktree "$f" && {
            if [ "$temp" = false ] && [ -f "$track_file" ]; then
              grep -Fxv "$f" "$track_file" > "$track_file.tmp"
              mv "$track_file.tmp" "$track_file"
              [ ! -s "$track_file" ] && rm "$track_file"
              echo "Unskipped (removed): $f"
            else
              echo "Unskipped: $f"
            fi
          }
        done
      fi
      ;;
    ls)
      local all_files saved_files unsaved_files
      all_files=$(git ls-files -v | grep '^S' | cut -c3-)

      if [ -f "$track_file" ] && [ -s "$track_file" ]; then
        saved_files=$(cat "$track_file")
      fi

      if [ -z "$all_files" ] && [ -z "$saved_files" ]; then
        echo "No skip-worktree files."
        return 0
      fi

      if [ -n "$saved_files" ]; then
        if [ -n "$all_files" ]; then
          unsaved_files=$(echo "$all_files" | grep -Fxv -f "$track_file")
        fi
      else
        unsaved_files="$all_files"
      fi

      if [ -n "$saved_files" ]; then
        echo "Saved:"
        echo "$saved_files" | while IFS= read -r file; do
          [ -z "$file" ] && continue
          if [ -n "$all_files" ] && echo "$all_files" | grep -Fxq "$file"; then
            echo "  $file"
          else
            echo "  $file (not active)"
          fi
        done
      fi

      if [ -n "$unsaved_files" ]; then
        if [ -n "$saved_files" ]; then echo ""; fi
        echo "Not saved:"
        echo "$unsaved_files" | while IFS= read -r file; do
          [ -n "$file" ] && echo "  $file"
        done
      fi
      ;;
    save)
      local all_files unsaved_files
      all_files=$(git ls-files -v | grep '^S' | cut -c3-)
      if [ -z "$all_files" ]; then
        echo "No skip-worktree files to save."
        return 0
      fi
      if [ -f "$track_file" ] && [ -s "$track_file" ]; then
        unsaved_files=$(echo "$all_files" | grep -Fxv -f "$track_file")
      else
        unsaved_files="$all_files"
      fi
      if [ -z "$unsaved_files" ]; then
        echo "All skip-worktree files are already saved."
        return 0
      fi
      echo "$unsaved_files" >> "$track_file"
      sort -u "$track_file" -o "$track_file"
      echo "$unsaved_files" | while IFS= read -r file; do
        [ -n "$file" ] && echo "Saved: $file"
      done
      ;;
    reset)
      local files
      files=$(git ls-files -v | grep '^S' | cut -c3-)
      if [ -z "$files" ]; then
        echo "No skip-worktree files."
        return 0
      fi
      echo "$files" | while IFS= read -r file; do
        git update-index --no-skip-worktree "$file" && echo "Unskipped: $file"
      done
      if [ -f "$track_file" ]; then
        rm "$track_file"
        echo "List cleared."
      fi
      ;;
    path)
      echo "$track_file"
      ;;
    edit)
      if [ ! -f "$track_file" ]; then
        echo "No list file yet. Skip a file first."
        return 1
      fi
      ${EDITOR:-cursor} "$track_file"
      ;;
    *)
      echo "Usage: gigi <command> [-t] [file_path...]"
      echo ""
      echo "Commands:"
      echo "  skip <files...>       Skip file(s) and save to list"
      echo "  skip -t <files...>    Skip file(s) without saving (temporary)"
      echo "  skip -d               Skip all modified files and save to list"
      echo "  skip -d -t            Skip all modified files without saving"
      echo "  skip                  Skip all saved files (re-apply)"
      echo "  unskip <files...>     Unskip file(s) and remove from list"
      echo "  unskip -t <files...>  Unskip file(s) without removing from list"
      echo "  unskip                Unskip all saved files and clear list"
      echo "  unskip -t             Unskip all saved files (list remains)"
      echo "  unskip -a             Unskip all skip-worktree files (from git)"
      echo "  save                  Save all unsaved skip-worktree files to list"
      echo "  reset                 Unskip all skip-worktree files and clear list"
      echo "  ls                    List skip-worktree files (saved & not saved)"
      echo "  path                  Print the list file path"
      echo "  edit                  Open the list file in \$EDITOR"
      ;;
  esac
}
