set -gx BAT_THEME Dracula
set -gx DOCKER_HIDE_LEGACY_COMMANDS 1
set -gx EDITOR nvim
set -gx LANG C.utf8
set -gx XDG_CONFIG_HOME "$HOME/.config"

command -q bat && alias cat bat
command -q docker && alias d docker
command -q git && alias g git
command -q less && alias less "less -i"
command -q nvim && alias vim nvim

fish_add_path -gpm "$HOME/.local/bin"
fish_add_path -gpm "$HOME/bin"

# mise (https://github.com/jdx/mise)
mise activate fish | source

# direnv (https://direnv.net)
direnv hook fish | source
