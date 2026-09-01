source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

oh-my-posh init fish --config ~/.config/oh-my-posh/current.omp.json | source
function fish_greeting; end

fish_add_path /home/holla/.spicetify
