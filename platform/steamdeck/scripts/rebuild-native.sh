#!/usr/bin/env bash
set -euo pipefail
root=${SOFTWARE_HOME:-$HOME/Software}
source "$root/env.sh"
app=$(cd "$root/apps/emacs/current" && pwd -P)
source "$app/activate.sh"
export CPPFLAGS="-D_GNU_SOURCE -I$CONDA_PREFIX/include"
export LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib"
export PKG_CONFIG_PATH="$CONDA_PREFIX/lib/pkgconfig:$CONDA_PREFIX/share/pkgconfig"
vterm=("$HOME"/.emacs.d/elpa/vterm-*)
pdf=("$HOME"/.emacs.d/elpa/pdf-tools-*)
[[ ${#vterm[@]} == 1 && ${#pdf[@]} == 1 ]] || { echo 'Expected one installed version of vterm and pdf-tools'; exit 1; }
# CMake caches encode absolute source/compiler locations; use a clean build directory.
cmake -S "${vterm[0]}" -B "$root/build/vterm-${app##*/}" \
 -DLIBVTERM_INCLUDE_DIR="$CONDA_PREFIX/include" -DLIBVTERM_LIBRARY="$CONDA_PREFIX/lib/libvterm.so"
cmake --build "$root/build/vterm-${app##*/}" -j2
(cd "${pdf[0]}/build/server" && make clean) || true
bash "${pdf[0]}/build/server/autobuild" -D -i "${pdf[0]}"
ldd "${vterm[0]}/vterm-module.so"
ldd "${pdf[0]}/epdfinfo"
