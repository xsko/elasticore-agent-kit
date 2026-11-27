#!/usr/bin/env bash
# Checks the Codex CLI parts of the kit without Codex: the agents' TOML says what
# their Markdown says, the plugin manifest and its hooks file name the hook script
# with the codex argument, and codex/install.sh installs into a project and a home
# folder and leaves a hooks.json of the user's alone.
#
# usage: bash tests/codex/test-codex.sh
# The fixtures go to a fresh directory under $TMPDIR, left for inspection.

set -u
here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d "${TMPDIR:-/tmp}/elasticore-codex-test.XXXXXX")"
passed=0
failed=0

check() {  # check <name> <condition...>
    name="$1"; shift
    if "$@"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        printf 'FAIL %s\n' "$name"
        [ "${GITHUB_ACTIONS:-}" = true ] && printf '::error title=Codex test failed::%s\n' "$name"
    fi
}

# --- the agents: TOML from the Markdown ------------------------------------------
# The body of an agent's Markdown (after its front matter), and the developer
# instructions of its TOML (between the ''' lines).
md_body() { awk 'n >= 2 { print; next } /^---$/ { n++; if (n == 2) getline; next }' "$1" | tr -d '\r'; }
md_key() { awk -v k="$2" 'NR > 1 && /^---$/ { exit } index($0, k ": ") == 1 { print substr($0, length(k) + 3) }' "$1" | tr -d '\r'; }
toml_body() { awk "/^developer_instructions = '''\$/ { on = 1; next } on && /^'''\$/ { exit } on { print }" "$1" | tr -d '\r'; }
toml_key() { sed -nE 's/^'"$2"' = "(.*)"$/\1/p' "$1" | sed 's/\\"/"/g; s/\\\\/\\/g' | tr -d '\r'; }
for pair in modeler:elasticore-modeler reviewer:elasticore-reviewer; do
    md="$repo/plugins/elasticore/agents/${pair%%:*}.md"
    toml="$repo/codex/agents/${pair#*:}.toml"
    check "${pair#*:}.toml has the instructions of ${pair%%:*}.md" [ "$(md_body "$md")" = "$(toml_body "$toml")" ]
    check "${pair#*:}.toml has its description" [ "$(md_key "$md" description)" = "$(toml_key "$toml" description)" ]
    check "${pair#*:}.toml is named ${pair#*:}" [ "$(toml_key "$toml" name)" = "${pair#*:}" ]
done

# --- the plugin: its manifest and the Codex hooks file -----------------------------
plugin="$repo/plugins/elasticore"
check "the plugin has a portable plugin.json at its root" [ -f "$plugin/plugin.json" ]
# Codex CLI 0.172, seen live with probe plugins: it takes a plugin's hooks file from
# .codex-plugin/plugin.json when the root plugin.json is not a portable manifest. A root
# plugin.json with "$schema" (portable) runs no plugin hook at all, not even one named in
# extensions.com.openai.hooks; without .codex-plugin it runs hooks/hooks.json - Claude Code's,
# whose commands do not run in Codex's PowerShell on Windows.
check ".codex-plugin/plugin.json names the Codex hooks file" grep -q '"hooks": "./hooks/codex-hooks.json"' "$plugin/.codex-plugin/plugin.json"
check "the root plugin.json is not a portable manifest (\$schema), which runs no plugin hook" eval '! grep -q "\\\$schema" "$plugin/plugin.json"'
check "nor names extensions.com.openai" eval '! grep -q "com.openai" "$plugin/plugin.json"'
ver() { sed -nE 's/.*"version": "([^"]+)".*/\1/p' "$1"; }
check "plugin.json, .codex-plugin/plugin.json and .claude-plugin/plugin.json have the same version" \
    eval '[ "$(ver "$plugin/plugin.json")" = "$(ver "$plugin/.claude-plugin/plugin.json")" ] && [ "$(ver "$plugin/.codex-plugin/plugin.json")" = "$(ver "$plugin/.claude-plugin/plugin.json")" ]'
for event in pre-edit pre-bash post-edit post-bash stop; do
    check "codex-hooks.json has a PowerShell commandWindows for $event: Git Bash looked for, \$env:PLUGIN_ROOT, a word when none is found" \
        grep -q "\"commandWindows\": \".*LOCALAPPDATA.*scoop.*git.exe.*env:PLUGIN_ROOT/hooks/elasticore-hook.sh.* $event codex}else{.*no Git Bash found" "$plugin/hooks/codex-hooks.json"
done
for event in pre-edit pre-bash post-edit post-bash stop; do
    check "codex-hooks.json runs the hook script's $event with the codex argument" \
        grep -q "elasticore-hook.sh[^ ]* $event codex" "$plugin/hooks/codex-hooks.json"
done
check "codex-hooks.json has no event Codex does not send" eval '! grep -q PostToolUseFailure "$plugin/hooks/codex-hooks.json"'
check "the Codex marketplace lists the plugin" grep -q '"path": "./plugins/elasticore"' "$repo/.agents/plugins/marketplace.json"

# --- codex/install.sh ------------------------------------------------------------
proj="$work/project"
mkdir -p "$proj"
out="$(cd "$proj" && bash "$repo/codex/install.sh" --project 2>&1)"; rc=$?
check "install.sh --project succeeds" [ "$rc" -eq 0 ]
for f in .agents/skills/elasticore/SKILL.md .agents/skills/elasticore/references/quick-reference.md \
    .agents/skills/report-issue/SKILL.md .agents/skills/contribute/SKILL.md \
    .codex/agents/elasticore-modeler.toml .codex/agents/elasticore-reviewer.toml \
    .codex/elasticore-kit/elasticore-hook.sh .codex/hooks.json; do
    check "install.sh --project writes $f" [ -f "$proj/$f" ]
done
valid_json_file() {
    for py in python3 python; do
        if command -v "$py" >/dev/null 2>&1 && "$py" -c 'print(1)' >/dev/null 2>&1; then
            "$py" -c 'import json,sys; json.load(open(sys.argv[1]))' "$1"
            return
        fi
    done
    return 0
}
check "the hooks.json it writes is valid JSON" valid_json_file "$proj/.codex/hooks.json"
check "and runs the installed hook script with the codex argument" grep -q 'elasticore-kit/elasticore-hook.sh[^ ]* stop codex' "$proj/.codex/hooks.json"
check "the hook script it installs is the kit's" cmp -s "$repo/plugins/elasticore/hooks/elasticore-hook.sh" "$proj/.codex/elasticore-kit/elasticore-hook.sh"
printf '{ "hooks": { "Stop": [] } }\n' > "$proj/.codex/hooks.json"
out="$(cd "$proj" && bash "$repo/codex/install.sh" --project 2>&1)"; rc=$?
check "a hooks.json of the user's is left as it is" eval '[ "$rc" -eq 0 ] && [ "$(cat "$proj/.codex/hooks.json")" = "{ \"hooks\": { \"Stop\": [] } }" ]'
check "and the hooks to add are printed" eval 'case "$out" in *"Add these hooks"*pre-edit\ codex*) true ;; *) false ;; esac'
home="$work/home"
mkdir -p "$home"
out="$(HOME="$home" USERPROFILE="$home" CODEX_HOME= bash "$repo/codex/install.sh" --no-hooks 2>&1)"; rc=$?
check "install.sh --no-hooks installs skills and agents for the user" \
    eval '[ "$rc" -eq 0 ] && [ -f "$home/.agents/skills/elasticore/SKILL.md" ] && [ -f "$home/.codex/agents/elasticore-reviewer.toml" ] && [ ! -f "$home/.codex/hooks.json" ]'
home2="$work/home2"
mkdir -p "$home2"
out="$(HOME="$home2" USERPROFILE="$home2" CODEX_HOME= bash "$repo/codex/install.sh" --agents-only 2>&1)"; rc=$?
check "install.sh --agents-only installs the agents alone" \
    eval '[ "$rc" -eq 0 ] && [ -f "$home2/.codex/agents/elasticore-modeler.toml" ] && [ ! -d "$home2/.agents/skills" ] && [ ! -f "$home2/.codex/hooks.json" ]'
out="$(bash "$repo/codex/install.sh" --unknown 2>&1)"; rc=$?
check "install.sh refuses an unknown option" [ "$rc" -eq 2 ]

# --- Windows: the bash the hooks run with ------------------------------------------
if command -v cygpath >/dev/null 2>&1; then
    # The hooks.json above is the user's now; write a fresh one.
    proj2="$work/project-win"
    mkdir -p "$proj2"
    (cd "$proj2" && bash "$repo/codex/install.sh" --project >/dev/null 2>&1)
    line="$(grep -o '"commandWindows": "[^,]*' "$proj2/.codex/hooks.json" | head -n 1)"
    check "the installer's commandWindows calls Git's launcher bin/bash.exe, not usr/bin/bash.exe" \
        eval 'case "$line" in *"/usr/bin/bash.exe"* | *//bin/*) false ;; *"/bin/bash.exe"*) true ;; *) false ;; esac'
    check "with the paths in single quotes" eval 'case "$line" in *"& '"'"'"*) true ;; *) false ;; esac'
    # A folder whose name holds a $ and a backtick: kept as it is, in single quotes.
    odd="$work/pro\$j\`x"
    mkdir -p "$odd"
    (cd "$odd" && bash "$repo/codex/install.sh" --project >/dev/null 2>&1)
    oddline="$(grep -o '"commandWindows": "[^,]*' "$odd/.codex/hooks.json" | head -n 1)"
    check "a \$ or a backtick in the path stays as it is, in single quotes" \
        eval 'case "$oddline" in *"pro\$j\`x/.codex/elasticore-kit/elasticore-hook.sh'"'"'"*) true ;; *) false ;; esac'
    # Git's usr/bin/bash.exe started with only Git\cmd on the Windows PATH, as PowerShell may:
    # the hook script puts its tools on the PATH itself.
    usr_bash="$(cygpath -m /)"
    usr_bash="${usr_bash%/}/usr/bin/bash.exe"
    if [ -f "$usr_bash" ]; then
        printf '//ecd:-1H20261127080000_V3.0\npackage a;\n\npublic class A {}\n' > "$proj2/A.java"
        payload='{"session_id":"w","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"'"$(cygpath -m "$proj2/A.java")"'","old_string":"a","new_string":"b"}}'
        out="$(printf '%s' "$payload" | PATH="/c/Windows/System32:/c/Windows:$(cygpath -u "$(cygpath -m /)")/cmd" "$usr_bash" "$repo/plugins/elasticore/hooks/elasticore-hook.sh" pre-edit 2>&1)"
        check "the hook works under usr/bin/bash.exe with only System32, Windows and Git\\cmd on the PATH" \
            eval 'case "$out" in *"\"permissionDecision\":\"deny\""*) true ;; *) false ;; esac'
    fi
fi

printf '%d passed, %d failed (fixtures in %s)\n' "$passed" "$failed" "$work"
[ "$failed" -eq 0 ]
