# CachyOS ships its own fish defaults (aliases, fastfetch greeting); other
# distros do not have the file, so only source it where it exists.
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

function fish_greeting; end

# Prompt: oh-my-posh with the matugen-recoloured theme that setwall writes
# (via ~/dotfiles/gen-ohmyposh-template). Skipped, and the plain fish prompt
# kept, when either is missing.
if type -q oh-my-posh; and test -f ~/.config/oh-my-posh/current.omp.json
    oh-my-posh init fish --config ~/.config/oh-my-posh/current.omp.json | source
end

# spicetify's installer puts its binary here rather than in a package
if test -d ~/.spicetify
    fish_add_path ~/.spicetify
end
