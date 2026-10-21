#!/usr/bin/env bash
# Run on Fedora after the Pixi replacements have passed validation.
set -euo pipefail
root=${SOFTWARE_HOME:-$HOME/Software}
source /etc/os-release
[[ $ID == fedora ]] || { echo 'This cleanup is for Fedora only.' >&2; exit 1; }
for command in fd rg fzf zoxide starship bat jq; do
 [[ -x $root/bin/$command ]] || { echo "Missing replacement: $command" >&2; exit 1; }
 "$root/bin/$command" --version >/dev/null
done
packages=()
for package in fd-find ripgrep fzf zoxide starship bat jq neovim; do
 rpm -q "$package" >/dev/null 2>&1 && packages+=("$package")
done
[[ ${#packages[@]} -gt 0 ]] || { echo 'No obsolete RPM tools remain.'; exit 0; }
echo 'Replacement commands verified. Review the DNF removal transaction below.'
# No -y: dependencies or third-party consumers must be reviewed in the real transaction.
# Keep system Git, Python, login Zsh, Modules, compilers and development libraries.
sudo dnf remove --setopt=clean_requirements_on_remove=False "${packages[@]}"
