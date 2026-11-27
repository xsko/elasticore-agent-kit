#!/usr/bin/env bash
# Installs the ElastiCORE agent kit for pi or oh-my-pi (omp).
#
#   bash pi/install.sh                  pi, for you: ~/.pi/agent/ ($PI_CODING_AGENT_DIR when set)
#   bash pi/install.sh --project        pi, for the project in the current directory: .pi/, .agents/skills/
#   bash pi/install.sh --omp            omp, for you: ~/.omp/agent/ ($PI_CODING_AGENT_DIR when set)
#   bash pi/install.sh --omp --project  omp, for the project in the current directory: .omp/
#
# Copies the extension and the hook script (extensions/elasticore/), the skills
# (elasticore, report-issue, contribute) and, for omp, the modeler and the reviewer
# as task agents (agents/elasticore-*.md). Run it again to update: it overwrites
# its own files and deletes nothing.

set -eu

usage() {
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

home="${HOME:-}"
# On Windows pi and omp read %USERPROFILE%\.pi and %USERPROFILE%\.omp; the HOME of
# an MSYS2 or Cygwin shell may be /home/<user> instead.
if [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
    home="$(cygpath -u "$USERPROFILE")"
fi

host=pi
scope=user
for arg in "$@"; do
    case "$arg" in
        --project) scope=project ;;
        --omp) host=omp ;;
        -h | --help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$arg" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "$scope" = project ]; then
    if [ "$host" = omp ]; then
        target="$(pwd)/.omp"
        skills="$target/skills"
    else
        target="$(pwd)/.pi"
        skills="$(pwd)/.agents/skills"
    fi
else
    if [ -n "${PI_CODING_AGENT_DIR:-}" ]; then
        target="$PI_CODING_AGENT_DIR"
        command -v cygpath >/dev/null 2>&1 && target="$(cygpath -u "$target")"
    else
        [ -n "$home" ] || { echo "HOME is not set: run with --project, or set PI_CODING_AGENT_DIR." >&2; exit 1; }
        target="$home/.$host/agent"
    fi
    skills="$target/skills"
fi

here="$(cd "$(dirname "$0")" && pwd)"
kit="$here/../plugins/elasticore"
if [ ! -f "$kit/hooks/elasticore-hook.sh" ] || [ ! -f "$kit/pi/elasticore.js" ]; then
    echo "Run this script from a checkout of the ElastiCORE agent kit: $kit is missing." >&2
    exit 1
fi

# copy <source file> <target file>
copy() {
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
    printf '  %s\n' "$2"
}

printf 'Installing the ElastiCORE agent kit for %s (%s)\n' "$host" "$scope"
extension="$target/extensions/elasticore"
copy "$kit/pi/elasticore.js" "$extension/index.js"
copy "$kit/hooks/elasticore-hook.sh" "$extension/elasticore-hook.sh"

# Git Bash on Windows, for the extension to run the hook script with: Git's launcher,
# bin/bash.exe (install.ps1 passes the one it found) - usr/bin/bash.exe, which
# `command -v bash` names inside Git Bash, does not put Git's tools on the PATH.
if command -v cygpath >/dev/null 2>&1; then
    bash_exe="${ELASTICORE_BASH:-}"
    [ -n "$bash_exe" ] && bash_exe="$(cygpath -m "$bash_exe")"
    if [ -z "$bash_exe" ] || [ ! -f "$bash_exe" ]; then
        # The Windows form: /bin is mounted on usr/bin inside Git Bash.
        bash_exe="$(cygpath -m /)"
        bash_exe="${bash_exe%/}/bin/bash.exe"
        [ -f "$bash_exe" ] || bash_exe="$(cygpath -m "$(command -v bash)")"
    fi
    printf '%s\n' "$(cygpath -w "$bash_exe")" > "$extension/bash-path"
    printf '  %s\n' "$extension/bash-path"
fi

for skill in elasticore report-issue contribute; do
    (cd "$kit/skills/$skill" && find . -type f | sed 's#^\./##' | LC_ALL=C sort) | while IFS= read -r file; do
        copy "$kit/skills/$skill/$file" "$skills/$skill/$file"
    done
done

# omp's task agents: the Claude Code agents under the names opencode and Codex give
# them - omp lets an agent of the same name replace its own, and it has a reviewer -
# with omp's tool names. pi has no subagents.
if [ "$host" = omp ]; then
    for name in modeler reviewer; do
        out="$target/agents/elasticore-$name.md"
        mkdir -p "$(dirname "$out")"
        awk -v name="elasticore-$name" '
            { sub(/\r$/, "") }
            NR > 1 && !done && /^---$/ { done = 1 }
            !done && /^name: / { print "name: " name; next }
            !done && /^tools: / {
                n = split(substr($0, 8), t, /, */); line = ""
                for (i = 1; i <= n; i++) {
                    x = tolower(t[i])
                    if (x == "powershell" || x == "skill") continue
                    line = line (line == "" ? "" : ", ") x
                }
                print "tools: " line; next
            }
            { print }' "$kit/agents/$name.md" > "$out"
        printf '  %s\n' "$out"
    done
fi

if [ "$host" = omp ]; then
    printf 'Done. Start a new omp session to load it (omp needs Bun 1.4.4 or later).\n'
elif [ "$scope" = project ]; then
    printf 'Done. pi loads a project'"'"'s .pi/ and .agents/ only once you trust the project: start pi in it and answer yes when it asks, or run /trust (pi -a trusts it for one run).\n'
else
    printf 'Done. Start a new pi session to load it.\n'
fi
