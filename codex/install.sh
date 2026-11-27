#!/usr/bin/env bash
# Installs the ElastiCORE agent kit for Codex CLI.
#
#   bash codex/install.sh              for the current user: ~/.agents/skills/, ~/.codex/ ($CODEX_HOME when set)
#   bash codex/install.sh --project    for the project in the current directory: .agents/skills/, .codex/
#   bash codex/install.sh --no-hooks   the skills and the agents, no hooks
#   bash codex/install.sh --agents-only   the agents alone - beside the plugin, which brings the skills and hooks
#
# Copies the skills (elasticore, report-issue, contribute), the agents
# (agents/elasticore-*.toml) and the hook script (elasticore-kit/elasticore-hook.sh),
# and writes hooks.json beside them - unless there is one already, which it
# leaves as it is and prints the hooks to add. Run it again to update; it
# deletes nothing.

set -eu

usage() {
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
}

home="${HOME:-}"
# On Windows Codex reads %USERPROFILE%\.codex and %USERPROFILE%\.agents; the HOME
# of an MSYS2 or Cygwin shell may be /home/<user> instead.
if [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
    home="$(cygpath -u "$USERPROFILE")"
fi

scope=user
hooks=yes
skills_too=yes
for arg in "$@"; do
    case "$arg" in
        --project) scope=project ;;
        --no-hooks) hooks=no ;;
        --agents-only) hooks=no; skills_too=no ;;
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
if [ "$skills_too" = yes ]; then
    for skill in elasticore report-issue contribute; do
        (cd "$kit/skills/$skill" && find . -type f | sed 's#^\./##' | LC_ALL=C sort) | while IFS= read -r file; do
            copy "$kit/skills/$skill/$file" "$skills/$skill/$file"
        done
    done
fi
for file in "$here"/agents/*.toml; do
    copy "$file" "$codex/agents/$(basename "$file")"
done
if [ "$hooks" = no ]; then
    [ "$skills_too" = yes ] && printf 'Done: the skills and the agents, no hooks. Start a new Codex session to load them.\n' \
        || printf 'Done: the agents alone. Start a new Codex session to load them.\n'
    exit 0
fi

script="$codex/elasticore-kit/elasticore-hook.sh"
copy "$kit/hooks/elasticore-hook.sh" "$script"

# The command Codex runs for each hook. On Windows Codex runs it with PowerShell (seen
# with Codex 0.172), so commandWindows calls Git Bash by its full path with & - the bash
# on the PATH there may be WSL's, which cannot read a Windows path. It is Git's launcher,
# bin/bash.exe (install.ps1 passes the one it found): usr/bin/bash.exe, which `command -v
# bash` names inside Git Bash, does not put Git's tools on the PATH when Codex starts it.
# The paths go in single quotes, so that a $ or a backtick in them stays as it is.
ps_quote() {  # a PowerShell single-quoted string
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}
if command -v cygpath >/dev/null 2>&1; then
    bash_exe="${ELASTICORE_BASH:-}"
    [ -n "$bash_exe" ] && bash_exe="$(cygpath -m "$bash_exe")"
    if [ -z "$bash_exe" ] || [ ! -f "$bash_exe" ]; then
        bash_exe="$(cygpath -m /)"
        bash_exe="${bash_exe%/}/bin/bash.exe"
        [ -f "$bash_exe" ] || bash_exe="$(cygpath -m "$(command -v bash)")"
    fi
    target="$(cygpath -m "$script")"
    run="bash \\\"$target\\\""
    run_win="& $(ps_quote "$bash_exe") $(ps_quote "$target")"
    run_win="$(printf '%s' "$run_win" | sed 's/\\/\\\\/g; s/"/\\"/g')"
else
    run="bash \\\"$script\\\""
    run_win=""
fi
entry() {  # entry <matcher or empty> <event argument>
    windows=""
    [ -n "$run_win" ] && windows="$(printf ', "commandWindows": "%s %s codex"' "$run_win" "$2")"
    if [ -n "$1" ]; then
        printf '      { "matcher": "%s", "hooks": [ { "type": "command", "command": "%s %s codex"%s, "timeout": 30 } ] }' "$1" "$run" "$2" "$windows"
    else
        printf '      { "hooks": [ { "type": "command", "command": "%s %s codex"%s, "timeout": 30 } ] }' "$run" "$2" "$windows"
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
