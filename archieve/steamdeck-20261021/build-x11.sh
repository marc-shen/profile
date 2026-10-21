#!/usr/bin/env bash
set -euo pipefail
source "$HOME/Software/env.sh"
cd "$HOME/Software"
if [[ ${CONDA_PREFIX:-} != "$HOME/Software/apps/emacs/31.1/.pixi/envs/default" ]]; then
    exec "$HOME/Software/bin/pixi" run --manifest-path "$HOME/Software/apps/emacs/31.1/pixi.toml" --frozen bash "$HOME/Software/scripts/emacs/build-x11.sh"
fi
export CFLAGS="-O2 -pipe"
export CXXFLAGS="-O2 -pipe"
export CPPFLAGS="-I$CONDA_PREFIX/include"
export LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib -Wl,-rpath-link,$CONDA_PREFIX/lib"
export PKG_CONFIG_PATH="$CONDA_PREFIX/lib/pkgconfig:$CONDA_PREFIX/share/pkgconfig"
cd "$HOME/Software/src/emacs"
git rev-parse HEAD > "$HOME/Software/logs/emacs/source-commit.txt"
[[ -f configure ]] || ./autogen.sh
mkdir -p "$HOME/Software/build/emacs-x11"
cd "$HOME/Software/build/emacs-x11"
"$HOME/Software/src/emacs/configure" \
    --prefix="$HOME/Software/apps/emacs/31.1/x11" \
    --without-pgtk --with-x-toolkit=gtk3 --without-xpm --with-modules --with-tree-sitter \
    --without-native-compilation --with-gnutls \
    --without-compress-install --without-selinux --without-libsystemd \
    --without-gpm --without-mailutils
make -j4
make install
"$HOME/Software/apps/emacs/31.1/x11/bin/emacs" --batch -Q \
    --eval '(princ (format "Emacs %s\n%s\n" emacs-version system-configuration-features))'
touch "$HOME/Software/logs/emacs/build-x11.success"
