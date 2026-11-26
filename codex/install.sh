#!/usr/bin/env bash
# Installs the ElastiCORE agent kit for Codex CLI.
#
#   bash codex/install.sh              for the current user: ~/.agents/skills/, ~/.codex/ ($CODEX_HOME when set)
#   bash codex/install.sh --project    for the project in the current directory: .agents/skills/, .codex/
#   bash codex/install.sh --no-hooks   skills and agents only - when the hooks come from the plugin
#
# Copies the skills (elasticore, report-issue, contribute), the agents
# (agents/elasticore-*.toml) and the hook script (elasticore-kit/elasticore-hook.sh),
# and writes hooks.json beside them - unless there is one already, which it
# leaves as it is and prints the hooks to add. Run it again to update; it
# deletes nothing.

set -eu

usage() {
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

home="${HOME:-}"
# On Windows Codex reads %USERPROFILE%\.codex and %USERPROFILE%\.agents; the HOME
# of an MSYS2 or Cygwin shell may be /home/<user> instead.
if [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
    home="$(cygpath -u "$USERPROFILE")"
fi

scope=user
hooks=yes
for arg in "$@"; do
    case "$arg" in
        --project) scope=project ;;
        --no-hooks) hooks=no ;;
        -h | --help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$arg" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "$scope" = project ]; then
    skills="$(pwd)/.agents/skills"
    codex="$(pwd)/.codex"
else
    [ -n "$home" ] || { echo "HOME is not set: run with --project." >&2; exit 1; }
    skills="$home/.agents/skills"
    if [ -n "${CODEX_HOME:-}" ]; then
        codex="$CODEX_HOME"
        command -v cygpath >/dev/null 2>&1 && codex="$(cygpath -u "$codex")"
    else
        codex="$home/.codex"
    fi
fi

here="$(cd "$(dirname "$0")" && pwd)"
kit="$here/../plugins/elasticore"
if [ ! -f "$kit/hooks/elasticore-hook.sh" ] || [ ! -f "$here/agents/elasticore-modeler.toml" ]; then
    echo "Run this script from a checkout of the ElastiCORE agent kit: $kit is missing." >&2
    exit 1
fi

# copy <source file> <target file>
copy() {
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
    printf '  %s\n' "$2"
}

printf 'Installing the ElastiCORE agent kit for Codex CLI (%s)\n' "$scope"
for skill in elasticore report-issue contribute; do
    (cd "$kit/skills/$skill" && find . -type f | sed 's#^\./##' | LC_ALL=C sort) | while IFS= read -r file; do
        copy "$kit/skills/$skill/$file" "$skills/$skill/$file"
    done
done
for file in "$here"/agents/*.toml; do
    copy "$file" "$codex/agents/$(basename "$file")"
done
[ "$hooks" = yes ] || { printf 'Done, without hooks. Start a new Codex session to load it.\n'; exit 0; }

script="$codex/elasticore-kit/elasticore-hook.sh"
copy "$kit/hooks/elasticore-hook.sh" "$script"

# The command Codex runs for each hook. On Windows: Git Bash by its full path - the
# bash on the PATH there may be WSL's, which cannot read a Windows path.
if command -v cygpath >/dev/null 2>&1; then
    bash_exe="$(cygpath -m "$(command -v bash)")"
    target="$(cygpath -m "$script")"
    run="\\\"$bash_exe\\\" \\\"$target\\\""
else
    run="bash \\\"$script\\\""
fi
entry() {  # entry <matcher or empty> <event argument>
    if [ -n "$1" ]; then
        printf '      { "matcher": "%s", "hooks": [ { "type": "command", "command": "%s %s codex", "timeout": 30 } ] }' "$1" "$run" "$2"
    else
        printf '      { "hooks": [ { "type": "command", "command": "%s %s codex", "timeout": 30 } ] }' "$run" "$2"
    fi
}
json="$(cat <<EOF
{
  "hooks": {
    "PreToolUse": [
$(entry 'apply_patch|Edit|Write' pre-edit),
$(entry 'Bash' pre-bash)
    ],
    "PostToolUse": [
$(entry 'apply_patch|Edit|Write' post-edit),
$(entry 'Bash' post-bash)
    ],
    "Stop": [
$(entry '' stop)
    ]
  }
}
EOF
)"

if [ -f "$codex/hooks.json" ]; then
    if grep -q -F 'elasticore-hook.sh' "$codex/hooks.json" 2>/dev/null; then
        printf 'Left %s as it is: it runs the kit'"'"'s hook script already.\n' "$codex/hooks.json"
    else
        printf '\n%s is there already and was left as it is. Add these hooks to it:\n\n%s\n\n' "$codex/hooks.json" "$json"
    fi
else
    mkdir -p "$codex"
    printf '%s\n' "$json" > "$codex/hooks.json"
    printf '  %s\n' "$codex/hooks.json"
fi
printf 'Done. Start a new Codex session, open /hooks and trust the ElastiCORE hooks - Codex runs no hook it has not been told to trust.\n'
