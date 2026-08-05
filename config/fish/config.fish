set -gx DOCKER_HIDE_LEGACY_COMMANDS 1
set -gx EDITOR nvim
set -gx LANG C.utf8
set -gx XDG_CONFIG_HOME "$HOME/.config"

command -q git && alias g git
command -q nvim && alias vim nvim
command -q docker && alias d docker
command -q bat && alias cat bat
command -q less && alias less "less -i"

fish_add_path -gpm "$HOME/.local/bin"
fish_add_path -gpm "$HOME/bin"

# mise (https://github.com/jdx/mise)
mise activate fish | source
