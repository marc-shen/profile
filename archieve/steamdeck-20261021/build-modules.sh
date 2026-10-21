#!/usr/bin/env bash
set -euo pipefail
source "$HOME/Software/env.sh"
app="$HOME/Software/apps/modules/5.7.0"
if [[ ${CONDA_PREFIX:-} != "$app/.pixi/envs/default" ]]; then
 exec "$HOME/Software/bin/pixi" run --frozen --manifest-path "$app/pixi.toml" bash "$HOME/Software/scripts/modules/build.sh"
fi
mkdir -p "$HOME/Software/build/modules/5.7.0" "$HOME/Software/share/modulefiles" "$HOME/Software/config/modules"
cp -a "$HOME/Software/src/modules-5.7.0/." "$HOME/Software/build/modules/5.7.0/"
cd "$HOME/Software/build/modules/5.7.0"
export LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib"
./configure --prefix="$app" \
 --etcdir="$HOME/Software/config/modules" \
 --with-tcl="$CONDA_PREFIX/lib" --with-tclinclude="$CONDA_PREFIX/include" \
 --with-tclsh="$CONDA_PREFIX/bin/tclsh" \
 --with-modulepath="$HOME/Software/share/modulefiles" \
 --disable-set-binpath --disable-example-modulefiles
make -j4
make install
