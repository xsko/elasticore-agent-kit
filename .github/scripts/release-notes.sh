#!/usr/bin/env bash
# The notes of a GitHub release, from CHANGELOG.md.
#
#   release-notes.sh TAG       e.g. v1.3.0; prints the notes, or fails
#
# Fails when TAG is not "v" + the plugin's version in
# plugins/elasticore/.claude-plugin/plugin.json, or when CHANGELOG.md has no
# "## <version>" section. The notes are that section - its links made absolute,
# at the tag, so that they work on the release page - and a footer.
set -euo pipefail

tag="${1:?usage: release-notes.sh TAG}"
here="$(cd "$(dirname "$0")/../.." && pwd)"
version="$(sed -nE 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$here/plugins/elasticore/.claude-plugin/plugin.json" | head -n 1)"
if [ "$tag" != "v$version" ]; then
    echo "The tag $tag is not the plugin's version: plugins/elasticore/.claude-plugin/plugin.json says $version, so the tag must be v$version." >&2
    exit 1
fi

section="$(awk -v v="$version" '
    $0 == "## " v { on = 1; next }
    on && /^## / { exit }
    on { print }' "$here/CHANGELOG.md")"
if [ -z "$(printf '%s' "$section" | tr -d '[:space:]')" ]; then
    echo "CHANGELOG.md has no section \"## $version\": write what $version gives users there first." >&2
    exit 1
fi

repo="https://github.com/xsko/elasticore-agent-kit"
# Relative links ([text](codex/README.md)) point into the repository at the tag.
printf '%s\n' "$section" | awk -v base="$repo/blob/$tag/" '
    {
        out = ""; s = $0
        while (match(s, /\]\([^)]+\)/)) {
            target = substr(s, RSTART + 2, RLENGTH - 3)
            if (target !~ /^(https?:|mailto:|#)/) target = base target
            out = out substr(s, 1, RSTART - 1) "](" target ")"
            s = substr(s, RSTART + RLENGTH)
        }
        print out s
    }' | sed -e '1{/^$/d;}'
anchor="$(printf '%s' "$version" | tr -d '.')"
printf '\n---\n\nInstall or update: see the [README](%s#readme) (Claude Code: `claude plugin update elasticore@elasticore-agent-kit`). The same notes are in the [CHANGELOG](%s/blob/main/CHANGELOG.md#%s).\n' "$repo" "$repo" "$anchor"
