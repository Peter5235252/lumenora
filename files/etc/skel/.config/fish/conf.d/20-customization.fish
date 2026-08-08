# -----------------------------------------------------
# CUSTOMIZATION
# -----------------------------------------------------

# -----------------------------------------------------
# Prompt (oh-my-posh from PATH — COPR ships /usr/bin/oh-my-posh)
# -----------------------------------------------------
set -l omp (command -v oh-my-posh 2>/dev/null)
if test -n "$omp" && test -f "$HOME/.config/ohmyposh/zen.toml"
    eval "$($omp init fish --config "$HOME/.config/ohmyposh/zen.toml")"
end
# eval "$($HOME/.local/bin/oh-my-posh init fish --config $HOME/.config/ohmyposh/EDM115-newline.omp.json)"