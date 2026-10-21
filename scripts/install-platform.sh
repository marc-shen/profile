#!/usr/bin/env bash
set -euo pipefail
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
export SOFTWARE_HOME=${SOFTWARE_HOME:-$HOME/Software}
action=${1:-install}; shift || true
command -v git >/dev/null || { echo 'Install system Git first (macOS: Xcode Command Line Tools).' >&2; exit 1; }
command -v curl >/dev/null || { echo 'Install curl and system CA certificates first.' >&2; exit 1; }
python3 "$repo/scripts/software.py" managers
python3 "$repo/scripts/software.py" tools "$@"
case $(uname -s) in
 Darwin)
  for prefix in /opt/homebrew /usr/local; do
   [[ ! -x $prefix/bin/brew ]] || export PATH="$prefix/bin:$prefix/sbin:$PATH"
  done
  command -v brew >/dev/null || { echo 'Install Homebrew in its default prefix: https://brew.sh' >&2; exit 1; }
  if [[ $EUID == 0 ]]; then
   [[ -x /Applications/Emacs.app/Contents/MacOS/Emacs && -d $(brew --prefix)/opt/modules ]] || { echo 'First install manifests/Brewfile as the Homebrew owner, then provision shared tools.' >&2; exit 1; }
  else
   brew bundle install --file="$repo/manifests/Brewfile"
  fi
  ;;
 Linux)
  source /etc/os-release
  case $ID in
   fedora|ubuntu|debian)
    packages="$repo/manifests/$ID-packages.txt"
    if [[ $ID == fedora ]]; then
     mapfile -t deps < "$packages"
     sudo dnf install -y "${deps[@]}"
    else
     mapfile -t deps < "$packages"
     sudo apt-get update
     sudo apt-get install -y "${deps[@]}"
     gcc_major=$(/usr/bin/gcc -dumpversion | cut -d. -f1)
     sudo apt-get install -y "libgccjit-$gcc_major-dev"
    fi
    python3 "$repo/scripts/build-emacs.py" --deps system;;
   steamos) python3 "$repo/scripts/build-emacs.py" --deps pixi
    python3 "$repo/scripts/build-modules.py";;
   *) echo "Unsupported distribution: $ID" >&2; exit 2;;
  esac;;
esac
python3 "$repo/scripts/plugins.py"
