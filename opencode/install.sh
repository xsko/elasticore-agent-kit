#!/usr/bin/env bash
# Installs the ElastiCORE agent kit for opencode, for the current user.
#
#   bash opencode/install.sh            into ~/.config/opencode/ ($XDG_CONFIG_HOME/opencode/ when set)
#   bash opencode/install.sh --project  into ./.opencode/ of the current directory
#
# Copies the plugin, the hook script, the elasticore skill, the agents and the
# commands, and overwrites those files when they are there already - run it
# again to update. It deletes nothing.

set -eu

usage() {
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
}

home="${HOME:-}"
# On Windows opencode reads %USERPROFILE%\.config\opencode; the HOME of an
# MSYS2 or Cygwin shell may be /home/<user> instead.
if [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
    home="$(cygpath -u "$USERPROFILE")"
fi

case "${1:-}" in
    "") target="${XDG_CONFIG_HOME:-$home/.config}/opencode" ;;
    --project) target="$(pwd)/.opencode" ;;
    -h | --help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
esac
case "$target" in
    /.config/*) echo "HOME is not set: run with --project, or set XDG_CONFIG_HOME." >&2; exit 1 ;;
esac

here="$(cd "$(dirname "$0")" && pwd)"
kit="$here/../plugins/elasticore"
if [ ! -f "$kit/hooks/elasticore-hook.sh" ] || [ ! -f "$here/plugins/elasticore.js" ]; then
    echo "Run this script from a checkout of the ElastiCORE agent kit: $kit is missing." >&2
    exit 1
fi

# copy <source file> <path under the target>
copy() {
    mkdir -p "$(dirname "$target/$2")"
    cp "$1" "$target/$2"
    printf '  %s\n' "$2"
}

printf 'Installing the ElastiCORE agent kit for opencode into %s\n' "$target"
copy "$here/plugins/elasticore.js" plugins/elasticore.js
copy "$kit/hooks/elasticore-hook.sh" elasticore-kit/elasticore-hook.sh
(cd "$kit/skills/elasticore" && find . -type f | sed 's#^\./##' | LC_ALL=C sort) | while IFS= read -r file; do
    copy "$kit/skills/elasticore/$file" "skills/elasticore/$file"
done
for file in "$here"/agents/*.md; do
    copy "$file" "agents/$(basename "$file")"
done
for file in "$here"/commands/*.md; do
    copy "$file" "commands/$(basename "$file")"
done
printf 'Done. Start a new opencode session to load it; opencode/README.md has the settings to add to opencode.json.\n'
