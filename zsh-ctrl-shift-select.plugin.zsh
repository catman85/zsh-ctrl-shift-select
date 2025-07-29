
custom-jump-symbol() {
  local chars="'\"<>[]./ )("
  local found=0
  local direction

  # Determine direction from key sequence
  case "$KEYS" in
    *C) direction="forward" ;;  # Ctrl+Right
    *D) direction="backward" ;; # Ctrl+Left
    *) return 1 ;;
  esac

  if [[ $direction == "forward" ]]; then
    # Forward search
    for (( i = CURSOR + 1; i <= ${#BUFFER}; i++ )); do
      if [[ $chars == *${BUFFER[$i]}* ]]; then
        CURSOR=$i
        found=1
        break
      fi
    done
    [[ $found -eq 0 ]] && CURSOR=${#BUFFER}
  else
    # Backward search
    for (( i = CURSOR - 1; i >= 0; i-- )); do
      if [[ $chars == *${BUFFER[$i]}* ]]; then
        CURSOR=$i
        found=1
        break
      fi
    done
    [[ $found -eq 0 ]] && CURSOR=0
  fi

  zle reset-prompt
}

# Register the widget
zle -N custom-jump-symbol
