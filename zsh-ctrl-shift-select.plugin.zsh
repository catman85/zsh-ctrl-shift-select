# vim: set ts=4:
# Custom Zsh navigation with shift-select support
# Combines custom character jumping with selection capabilities

# Characters to jump to
BREAKPOINT_SYMBOLS="'\"<>[]./ )("

# Custom jump function that follows specific character rules
function jump-to-symbol() {
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
      if [[ $BREAKPOINT_SYMBOLS == *${BUFFER[$i]}* ]]; then
        CURSOR=$i
        found=1
        break
      fi
    done
    [[ $found -eq 0 ]] && CURSOR=${#BUFFER}
  else
    # Backward search
    for (( i = CURSOR - 1; i >= 0; i-- )); do
      if [[ $BREAKPOINT_SYMBOLS == *${BUFFER[$i]}* ]]; then
        CURSOR=$i
        found=1
        break
      fi
    done
    [[ $found -eq 0 ]] && CURSOR=0
  fi
  
  zle reset-prompt
}

# Register the custom jump widget
zle -N jump-to-symbol

# Move cursor to the end of the buffer
function end-of-buffer() {
  CURSOR=${#BUFFER}
  zle end-of-line -w
}
zle -N end-of-buffer

# Move cursor to the beginning of the buffer
function beginning-of-buffer() {
  CURSOR=0
  zle beginning-of-line -w
}
zle -N beginning-of-buffer

# Kill the selected region and switch back to the main keymap
function shift-select::kill-region() {
  zle kill-region -w
  zle -K main
}
zle -N shift-select::kill-region

# Handle self-insert while text is selected: delete selection and insert character
function shift-select::self-insert-and-replace() {
  zle kill-region -w
  zle -K main
  zle self-insert -w
}
zle -N shift-select::self-insert-and-replace

# Deactivate selection and process keys again in main keymap
function shift-select::deselect-and-input() {
  zle deactivate-region -w
  zle -K main
  zle -U "$KEYS"
}
zle -N shift-select::deselect-and-input

# Activate selection region if not active, then invoke the widget
function shift-select::select-and-invoke() {
  if (( !REGION_ACTIVE )); then
    zle set-mark-command -w
    zle -K shift-select
  fi
  zle ${WIDGET#shift-select::} -w
}

# Custom jump with shift-select support
function shift-select::jump-to-symbol() {
  if (( !REGION_ACTIVE )); then
    zle set-mark-command -w
    zle -K shift-select
  fi
  zle jump-to-symbol -w
}
zle -N shift-select::jump-to-symbol

# Setup function
function {
  emulate -L zsh
  
  # Create shift-select keymap
  bindkey -N shift-select
  
  # Bind all printable characters to self-insert-and-replace in shift-select mode
  # This makes typing replace selected text
  local char
  for char in {' '..'~'}; do
    bindkey -M shift-select "$char" shift-select::self-insert-and-replace
  done
  
  # Bind remaining keys to deselect-and-input as fallback
  bindkey -M shift-select -R '^@'-'^_' shift-select::deselect-and-input
  
  local kcap seq seq_mac widget
  
  # Bind standard Shift navigation keys
  for kcap   seq          seq_mac    widget (
    kLFT   '^[[1;2D'    x          backward-char        # Shift+Left
    kRIT   '^[[1;2C'    x          forward-char         # Shift+Right
    kri    '^[[1;2A'    x          up-line              # Shift+Up
    kind   '^[[1;2B'    x          down-line            # Shift+Down
    kHOM   '^[[1;2H'    x          beginning-of-line    # Shift+Home
    kEND   '^[[1;2F'    x          end-of-line          # Shift+End
    x      '^[[1;6D'    '^[[1;4D'  backward-word        # Shift+Ctrl+Left (Shift+Option+Left on macOS)
    x      '^[[1;6C'    '^[[1;4C'  forward-word         # Shift+Ctrl+Right (Shift+Option+Right on macOS)
    x      '^[[1;6H'    '^[[1;4H'  beginning-of-buffer  # Shift+Ctrl+Home (Shift+Option+Home on macOS)
    x      '^[[1;6F'    '^[[1;4F'  end-of-buffer        # Shift+Ctrl+End (Shift+Option+End on macOS)
  ); do
    [[ "$OSTYPE" = darwin* && "$seq_mac" != x ]] && seq=$seq_mac
    zle -N shift-select::$widget shift-select::select-and-invoke
    bindkey -M emacs ${terminfo[$kcap]:-$seq} shift-select::$widget
    bindkey -M shift-select ${terminfo[$kcap]:-$seq} shift-select::$widget
  done
  
  # Bind Delete and Backspace to kill selected region
  for kcap   seq        widget (
    kdch1  '^[[3~'    shift-select::kill-region         # Delete
    bs     '^?'       shift-select::kill-region         # Backspace
  ); do
    bindkey -M shift-select ${terminfo[$kcap]:-$seq} $widget
  done
  
  # Bind custom jump to Ctrl+Left/Right (without shift)
  bindkey -M emacs '^[[1;5C' jump-to-symbol  # Ctrl+Right
  bindkey -M emacs '^[[1;5D' jump-to-symbol  # Ctrl+Left
  
  # Bind custom jump with selection to Shift+Ctrl+Left/Right
  bindkey -M emacs '^[[1;6C' shift-select::jump-to-symbol  # Shift+Ctrl+Right
  bindkey -M emacs '^[[1;6D' shift-select::jump-to-symbol  # Shift+Ctrl+Left
  bindkey -M shift-select '^[[1;6C' shift-select::jump-to-symbol  # Shift+Ctrl+Right (in select mode)
  bindkey -M shift-select '^[[1;6D' shift-select::jump-to-symbol  # Shift+Ctrl+Left (in select mode)
  
  # For macOS (Option instead of Ctrl)
  if [[ "$OSTYPE" = darwin* ]]; then
    bindkey -M emacs '^[[1;3C' jump-to-symbol                      # Option+Right
    bindkey -M emacs '^[[1;3D' jump-to-symbol                      # Option+Left
    bindkey -M emacs '^[[1;4C' shift-select::jump-to-symbol        # Shift+Option+Right
    bindkey -M emacs '^[[1;4D' shift-select::jump-to-symbol        # Shift+Option+Left
    bindkey -M shift-select '^[[1;4C' shift-select::jump-to-symbol # Shift+Option+Right (in select mode)
    bindkey -M shift-select '^[[1;4D' shift-select::jump-to-symbol # Shift+Option+Left (in select mode)
  fi
  
  # Bind Home/End (without shift)
  bindkey -M emacs '^[[H' beginning-of-line   # Home
  bindkey -M emacs '^[[F' end-of-line         # End
  bindkey -M emacs '^[[1~' beginning-of-line  # Home (alternative sequence)
  bindkey -M emacs '^[[4~' end-of-line        # End (alternative sequence)
  
  # Bind Ctrl+Home/End to beginning/end of buffer
  bindkey -M emacs '^[[1;5H' beginning-of-buffer  # Ctrl+Home
  bindkey -M emacs '^[[1;5F' end-of-buffer        # Ctrl+End
}
