# credentialsd (patched)

The AUR `credentialsd` PKGBUILD plus a local fix, as pkgrel 1.1. See the
header of `0002-ignore-unknown-credential-transports.patch` for why: 0.2.0
drops any allow-list credential whose transports include a value it does
not know, which is every phone passkey ("cable"), so hybrid sign-in to an
existing account never matched. Upstream fixed it after 0.2.0; drop the
patch and go back to the plain AUR package on the next release.

    cd ~/dotfiles/pkgbuilds/credentialsd
    makepkg -srCf
    sudo pacman -U credentialsd-*.pkg.tar.zst firefox-extension-credentialsd-*.pkg.tar.zst
    patch-credentialsd-xpi     # the add-on patch does not survive a reinstall
