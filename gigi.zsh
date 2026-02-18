gigi() {
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Not a git repository"; return 1; }
  local track_file="$git_root/.git/skip-worktree-files"

  _gigi_relpath() {
    local p="$1"
    if [[ "$p" = /* ]]; then
      p="${p#$git_root/}"
    fi
    echo "$p"
  }

  case "$1" in
    skip)
      local save=false
      shift
      while [ $# -gt 0 ]; do
        case "$1" in
          -s|--save) save=true; shift ;;
          *) break ;;
        esac
      done

      if [ -z "$1" ]; then
        if [ "$save" = true ]; then
          echo "Error: -s requires at least one file path"
          return 1
        fi
        if [ ! -f "$track_file" ] || [ ! -s "$track_file" ]; then
          echo "No saved files to skip."
          return 0
        fi
        while IFS= read -r file; do
          [ -z "$file" ] && continue
          git update-index --skip-worktree "$file" && echo "Skipped: $file"
        done < "$track_file"
      else
        for raw in "$@"; do
          local f=$(_gigi_relpath "$raw")
          git update-index --skip-worktree "$f" && {
            echo "Skipped: $f"
            if [ "$save" = true ]; then
              echo "$f" >> "$track_file"
              echo "Saved: $f"
            fi
          }
        done
        if [ "$save" = true ] && [ -f "$track_file" ]; then
          sort -u "$track_file" -o "$track_file"
        fi
      fi
      ;;
    unskip)
      local save=false
      local all=false
      shift
      while [ $# -gt 0 ]; do
        case "$1" in
          -a|--all) all=true; shift ;;
          -s|--save) save=true; shift ;;
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
        if [ "$save" = true ]; then
          rm "$track_file"
          echo "List cleared."
        fi
      else
        for raw in "$@"; do
          local f=$(_gigi_relpath "$raw")
          git update-index --no-skip-worktree "$f" && {
            echo "Unskipped: $f"
            if [ "$save" = true ] && [ -f "$track_file" ]; then
              grep -Fxv "$f" "$track_file" > "$track_file.tmp"
              mv "$track_file.tmp" "$track_file"
              [ ! -s "$track_file" ] && rm "$track_file"
              echo "Removed from list: $f"
            fi
          }
        done
      fi
      ;;
    ls)
      if [ "$2" = "-a" ] || [ "$2" = "--all" ]; then
        local all_files saved_files unsaved_files
        all_files=$(git ls-files -v | grep '^S' | cut -c3-)

        if [ -f "$track_file" ] && [ -s "$track_file" ]; then
          saved_files=$(cat "$track_file")
        fi

        if [ -z "$all_files" ]; then
          echo "No skip-worktree files."
          return 0
        fi

        if [ -n "$saved_files" ]; then
          unsaved_files=$(echo "$all_files" | grep -Fxv -f "$track_file")
        else
          unsaved_files="$all_files"
        fi

        if [ -n "$saved_files" ]; then
          echo "Saved:"
          echo "$saved_files" | while IFS= read -r file; do
            [ -n "$file" ] && echo "  $file"
          done
        fi

        if [ -n "$unsaved_files" ]; then
          if [ -n "$saved_files" ]; then echo ""; fi
          echo "Not saved:"
          echo "$unsaved_files" | while IFS= read -r file; do
            [ -n "$file" ] && echo "  $file"
          done
        fi
      else
        if [ ! -f "$track_file" ] || [ ! -s "$track_file" ]; then
          echo "No saved files."
          return 0
        fi
        echo "Saved:"
        while IFS= read -r file; do
          [ -n "$file" ] && echo "  $file"
        done < "$track_file"
      fi
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
        echo "No list file yet. Skip a file with -s first."
        return 1
      fi
      ${EDITOR:-cursor} "$track_file"
      ;;
    *)
      echo "Usage: gigi <command> [-s] [file_path...]"
      echo ""
      echo "Commands:"
      echo "  skip <files...>       Skip file(s)"
      echo "  skip -s <files...>    Skip file(s) and save to list"
      echo "  skip                  Skip all saved files (re-apply)"
      echo "  unskip <files...>     Unskip file(s)"
      echo "  unskip -s <files...>  Unskip file(s) and remove from list"
      echo "  unskip                Unskip all saved files"
      echo "  unskip -a             Unskip all skip-worktree files (from git)"
      echo "  unskip -s             Unskip all saved files and clear list"
      echo "  reset                 Unskip all skip-worktree files and clear list"
      echo "  ls                    List saved file paths"
      echo "  ls -a                 List all skip-worktree files (from git)"
      echo "  path                  Print the list file path"
      echo "  edit                  Open the list file in \$EDITOR"
      ;;
  esac
}
