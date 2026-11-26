#!/usr/bin/env bash
# The ElastiCORE plugin's hooks. They keep an agent on the DSL side of an
# ElastiCORE project: a generated file is changed through the YAML under
# src/main/resources/blueprint/<domain>/, and a DSL change is generated and
# compiled before the agent says it is done.
#
#   pre-edit   PreToolUse          Edit|Write|MultiEdit  refuse an edit to a file the generator rewrites,
#                                                        and a Write over a merged generated file
#   pre-bash   PreToolUse          Bash|PowerShell       refuse a Gradle run that forces overwriting
#   post-edit  PostToolUse         Edit|Write|MultiEdit  after a DSL edit, say what to run before finishing
#   post-bash  PostToolUse(Failure) Bash|PowerShell      after a Gradle run, pass on what the generator said;
#                                                        note a type check of screens on the generated client
#   stop       Stop                                      do not finish while a DSL change has not been compiled
#                                                        (nor its TypeScript client regenerated and type-checked)
#
# The same events from Codex CLI (second argument "codex"): an edit is apply_patch,
# checked file by file; a Stop is answered with decision "block". In a checkout of
# ElastiCORE itself (contributor mode) the guards above stay off, and the rules of
# its CONTRIBUTING.md that a hook can see are checked instead. Signs that
# ElastiCORE itself fell short point to the report-issue skill, once a session.
#
# Bash and POSIX tools only: Claude Code runs hooks with sh on macOS and Linux
# and with Git Bash on Windows. Anything unexpected ends in exit 0 or 1, which
# lets the action go ahead - a broken hook never blocks the user's work.
#
# ELASTICORE_ALLOW_GENERATED_EDITS=1 lets edits to generated files through;
# ELASTICORE_ALLOW_FORCE=1 lets -Pforce through; ELASTICORE_ALLOW_HISTORY_EDITS=1
# lets an edit of a checkout's elasticore-history.md through.

set -u
# Bytes, not characters: in a UTF-8 locale the BSD tools on macOS refuse or
# miscount bytes that are not valid UTF-8 - a BOM taken apart, a file in
# another encoding, a multibyte character cut by head -c.
export LC_ALL=C

event="${1:-}"
# The agent: "codex" from the Codex hooks file; otherwise Claude Code's JSON, which
# the opencode plugin sends too. A payload with Codex's turn_id is Codex's as well.
agent="${2:-}"
input="$(cat)" || exit 0
case "$input" in *'"turn_id"'*) [ -n "$agent" ] || agent=codex ;; esac
tab="$(printf '\t')"

# The raw value of a JSON string field, still escaped. Claude Code sends one
# line of JSON; a key inside another string value is escaped (\"key\") and is
# not matched.
json_string() {
    printf '%s' "$input" | sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' | head -n 1
}

# Whether a JSON boolean field is true. An escaped key inside a string value
# does not match.
json_true() {
    case "$input" in
        *"\"$1\":true"* | *"\"$1\": true"*) return 0 ;;
    esac
    return 1
}

# A path from the JSON. Windows paths arrive as C:\\dir\\file; Git Bash reads
# them with forward slashes, and slashes keep them safe inside the JSON written below.
json_path() {
    json_string "$1" | sed 's#\\\\#/#g'
}

# The model: YAML in a domain folder under the blueprint. Files in the
# blueprint root (schema.yml, semantic_model.yml) are written by the generator.
is_dsl() {
    case "$1" in
        */src/main/resources/blueprint/*/*.yml | */src/main/resources/blueprint/*/*.yaml) return 0 ;;
    esac
    return 1
}

# The file of a project that holds what ElastiCORE last generated - the base of
# the merge: .elasticore/generated-base.zip, or .elasticore/cache in a project an
# ElastiCORE from before the rename generated (a newer one moves it on its next
# build). With both there, ElastiCORE reads the new one.
merge_base() {
    if [ -f "$1/.elasticore/generated-base.zip" ]; then
        printf '%s' "$1/.elasticore/generated-base.zip"
    elif [ -f "$1/.elasticore/cache" ]; then
        printf '%s' "$1/.elasticore/cache"
    else
        return 1
    fi
}

# The project that keeps a merge base: the nearest folder above the file that
# has one. The 3.0 code is written without //ecd: lines and merged against it.
merge_root() {
    dir="$(dirname -- "$1")"
    i=0
    while [ -n "$dir" ] && [ "$i" -lt 40 ]; do
        merge_base "$dir" > /dev/null && { printf '%s' "$dir"; return 0; }
        parent="$(dirname -- "$dir")"
        [ "$parent" = "$dir" ] && break
        dir="$parent"
        i=$((i + 1))
    done
    return 1
}

# Whether the generator wrote the file last time and merges it from now on: the
# base is a zip stored without compression, so its entry names - paths from the
# project folder, with / - can be read as they are.
merged() {
    root="$(merge_root "$1")" || return 1
    key="${1#"$root"/}"
    [ "$key" != "$1" ] || return 1
    base_file="$(merge_base "$root")" || return 1
    grep -a -q -F -e "$key" -- "$base_file" 2>/dev/null
}

# Who owns a file, by the rules the generator applies to it.
#   none         no such file yet
#   hand         not written by ElastiCORE, or handed over to the developer
#   owned        "// Initially generated by ElastiCORE;" near the top: the developer's
#   block        generated, with a preserved block that survives regeneration
#   managed      generated: rewritten from the DSL, skipped once edited by hand
#   merged       generated with no //ecd: line and kept in the merge base
#                (.elasticore/generated-base.zip, earlier .elasticore/cache): a
#                hand edit is kept, and the DSL's changes are merged into it
#   regenerated  written again on every generation and with no //ecd: line -
#                schema.yml, the copied guides, the default messages file
# The generator looks for the ownership line within 200 characters after line
# one; 600 bytes here only errs on the side of letting an edit through.
classify() {
    [ -f "$1" ] || { echo none; return; }
    first="$(head -n 1 -- "$1" 2>/dev/null | tr -d '\r\357\273\277')"
    case "$first" in
        //ecd:*) ;;
        *)
            if merged "$1"; then
                if head -c 600 -- "$1" 2>/dev/null | grep -q -F -e '// Initially generated by ElastiCORE;'; then
                    echo owned
                else
                    echo merged
                fi
                return
            fi
            ;;
    esac
    case "$first" in
        //ecd:*)
            if head -c 600 -- "$1" 2>/dev/null | grep -q -F -e '// Initially generated by ElastiCORE;'; then
                echo owned
            elif grep -q -F -e '// !----------' -- "$1" 2>/dev/null; then
                echo block
            else
                echo managed
            fi
            return
            ;;
    esac
    # The model is the developer's, even when the wizard that created it wrote
    # "Generated by ElastiCORE" at the top of env.yml and model.yml.
    is_dsl "$1" && { echo hand; return; }
    case "$1" in
        */src/main/resources/blueprint/schema.yml | */src/main/resources/blueprint/semantic_model.yml | \
        */src/main/resources/blueprint/context-map.md | */src/main/resources/blueprint/elasticore-*.md)
            echo regenerated
            return
            ;;
        # A translation starts as a copy of the default messages file, header
        # included, but it is the developer's.
        *-messages_*.properties)
            echo hand
            return
            ;;
        # The resources the generator writes with a header and no //ecd: line -
        # the default messages file, the HTTP port settings, orm.xml. A source
        # file without //ecd: is the developer's whatever its comments say.
        */src/main/resources/*.properties | */src/main/resources/*.xml | \
        */src/main/resources/*.yml | */src/main/resources/*.yaml | \
        */src/main/resources/graphql/*.graphqls) ;;
        *)
            echo hand
            return
            ;;
    esac
    if head -n 5 -- "$1" 2>/dev/null | grep -q -F -e 'Generated by ElastiCORE'; then
        echo regenerated
    else
        echo hand
    fi
}

# A build script without its comment lines.
code_of() {
    grep -v -E '^[[:space:]]*(//|/\*|\*)' -- "$1" 2>/dev/null
}

# Whether the build scripts, in the model's module or above it, run the 2.x
# generator:
#   - output = 'v2' / output.set("v2"), on any version;
#   - a build that never applies the io.elasticore plugin - the 2.2 line, a
#     hand-written task running ModelExtractor, elasticore-base 2.x - unless it
#     runs the rule engine itself (RulesGenRunner);
#   - on a 2.x version or an early 3.0 build older than 3.0.261028 (the plugin's
#     version, its classpath artifact's, the catalog's, or a gradle.properties
#     value the plugin line names), no elasticore { } block, nor
#     elasticore.<setting>, that sets architecture, language, rules or output -
#     the released 3.0 runs the rule engine without one.
# A plugin applied with no version the scripts show is taken as a current one.
runs_2x() {
    dir="$1"
    i=0
    declared=1
    old=1
    applied=1
    mentioned=1
    while [ -n "$dir" ] && [ "$i" -lt 8 ]; do
        for script in "$dir/build.gradle" "$dir/build.gradle.kts" "$dir/settings.gradle" "$dir/settings.gradle.kts" \
            "$dir/gradle/libs.versions.toml"; do
            [ -f "$script" ] || continue
            code="$(code_of "$script")"
            case "$code" in *elasticore*) mentioned=0 ;; *) continue ;; esac
            printf '%s\n' "$code" | grep -Eq '(^|[^A-Za-z0-9_])output[[:space:]]*(=|\(|\.set[[:space:]]*\()[[:space:]]*["'"'"']v2["'"'"']' && return 0
            printf '%s\n' "$code" | grep -Eq '(^|[^A-Za-z0-9_])(architecture|language|rules|output)[[:space:]]*(=|\(|\.)' && declared=0
            # id 'io.elasticore', id("io.elasticore"), apply plugin: 'io.elasticore', apply(plugin = "io.elasticore"),
            # pluginManager.apply("io.elasticore"), alias(libs.plugins.elasticore) - or the rule engine run by hand.
            printf '%s\n' "$code" | grep -Eq 'id[[:space:]]*\(?[[:space:]]*["'"'"']io\.elasticore["'"'"']|apply[[:space:]]*\(?[[:space:]]*plugin[[:space:]]*(:|=)[[:space:]]*["'"'"']io\.elasticore["'"'"']|pluginManager\.apply[[:space:]]*\([[:space:]]*["'"'"']io\.elasticore["'"'"']|plugins\.elasticore|RulesGenRunner' && applied=0
            # ElastiCORE's own version: the plugin's, its classpath artifact's, or the catalog's.
            for v in $(printf '%s\n' "$code" | sed -nE \
                    -e 's/.*io\.elasticore["'"'"')]*[[:space:]]+version[[:space:]]*\(?[[:space:]]*["'"'"']([0-9][^"'"'"']*).*/\1/p' \
                    -e 's/.*io\.elasticore["'"'"')]*[[:space:]]+version[[:space:]]*\(?[[:space:]]*([A-Za-z_][A-Za-z0-9_.]*).*/@\1/p' \
                    -e 's/.*elasticore-gradle-plugin:([0-9][^"'"'"')]*).*/\1/p' \
                    -e 's/.*id[[:space:]]*=[[:space:]]*"io\.elasticore".*version[[:space:]]*=[[:space:]]*"([0-9][^"]*)".*/\1/p' \
                    -e 's/^[[:space:]]*elasticore[[:space:]]*=[[:space:]]*"([0-9][^"]*)".*/\1/p'); do
                case "$v" in
                    @*) # a property: gradle.properties beside the script
                        v="$(sed -nE 's/^[[:space:]]*'"${v#@}"'[[:space:]]*=[[:space:]]*([0-9][^[:space:]]*).*/\1/p' \
                             "$dir/gradle.properties" 2>/dev/null | head -n 1)" ;;
                esac
                case "$v" in
                    3.0.*) day="${v#3.0.}"; day="${day%%[!0-9]*}"; [ -n "$day" ] && [ "$day" -lt 261028 ] 2>/dev/null && old=0 ;;
                    [0-2].*) old=0 ;;
                esac
            done
        done
        parent="$(dirname -- "$dir")"
        [ "$parent" = "$dir" ] && break
        dir="$parent"
        i=$((i + 1))
    done
    [ "$declared" = 0 ] && return 1
    [ "$old" = 0 ] && return 0
    # Elasticore in the build, but neither its plugin nor its rule engine: the 2.x generator.
    [ "$mentioned" = 0 ] && [ "$applied" = 1 ]
}

# Trims spaces and escaped line breaks from both ends of a JSON string value.
trim_json() {
    printf '%s' "$1" | sed -E -e 's/^([[:space:]]|\\[nrt])+//' -e 's/([[:space:]]|\\[nrt])+$//'
}

# Trims spaces and escaped line breaks from the end of a JSON string value.
trim_json_end() {
    printf '%s' "$1" | sed -E 's/([[:space:]]|\\[nrt])+$//'
}

# An Edit that only inserts one whole preserved block right before the closing
# brace of the file's class - where the generator puts a block's code back on
# every regeneration, so a block anywhere else would move. The old text ends
# with that brace on a line of its own, the only line in the file that starts
# with "}"; the new text is the old text with one block before the brace:
# "// !----------" first, an end line holding "//" and "------------!" last, each
# on lines of their own, and no other end marker in between - the generator ends
# a block at the first one. Anything else - code outside the block, generated
# code moved into it, a block at every match, a MultiEdit - is not this edit.
adds_block() {
    [ "$tool" = Edit ] || return 1
    json_true replace_all && return 1
    old="$(trim_json_end "$(json_string old_string)")"
    new="$(trim_json_end "$(json_string new_string)")"
    case "$old" in
        '}' | *'\n}') prefix="${old%?}" ;;
        *) return 1 ;;
    esac
    [ "$(tr -d '\r' < "$path" 2>/dev/null | grep -c '^}')" = 1 ] || return 1
    case "$new" in
        "$prefix"*'\n}') rest="${new#"$prefix"}"; rest="${rest%???}" ;;
        *) return 1 ;;
    esac
    rest="$(trim_json "$rest")"
    case "$rest" in
        *'// !----------'*'// !----------'*) return 1 ;;
        '// !----------'*'\n'*) ;;
        *) return 1 ;;
    esac
    case "${rest##*\\n}" in
        *'//'*'------------!'*) ;;
        *) return 1 ;;
    esac
    case "${rest%\\n*}" in
        *'------------!'*) return 1 ;;
    esac
    return 0
}

# Text for a JSON string: one line, quotes and backslashes escaped.
json_text() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Context for Claude: after a tool ran, or as the reason to go on instead of
# stopping. Unlike exit 2, the transcript shows it as feedback, not an error.
context() {
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$(json_text "$2")"
}

# Refuse a tool call; Claude reads the reason.
deny() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$(json_text "$1")"
}

# The shell command as simple commands, one per line: the JSON escapes decoded,
# split at ; & | ( ) and line breaks outside quotes, the quotes dropped, and the
# body of a here-document left out - text in a commit message is not a command.
# A quoted command handed to sh -c or cmd /c stays on the line of its caller.
commands() {
    printf '%s\n' "$1" | awk '
    function decode(s,   t, i, n, c, d) {
        t = ""; n = length(s)
        for (i = 1; i <= n; i++) {
            c = substr(s, i, 1)
            if (c == "\\" && i < n) {
                i++; d = substr(s, i, 1)
                if (d == "n") t = t "\n"
                else if (d == "t") t = t "\t"
                else if (d == "u") { t = t "?"; i += 4 }
                else if (d != "r") t = t d
            } else t = t c
        }
        return t
    }
    function emit() { sub(/^[ \t]+/, "", seg); if (seg != "") print seg; seg = "" }
    {
        t = decode($0); n = length(t); q = ""; seg = ""; hd = ""; i = 1
        while (i <= n) {
            c = substr(t, i, 1)
            if (q != "") {
                if (c == q) q = ""
                else if (c == "\n") seg = seg " "
                else seg = seg c
                i++; continue
            }
            if (c == "\"" || c == "\047") { q = c; i++; continue }
            if (substr(t, i, 2) == "<<" && substr(t, i, 3) != "<<<") {
                j = i + 2; w = ""
                if (substr(t, j, 1) == "-") j++
                while (substr(t, j, 1) == " ") j++
                while (j <= n) {
                    d = substr(t, j, 1)
                    if (d ~ /[A-Za-z0-9_]/) w = w d
                    else if (d != "\"" && d != "\047") break
                    j++
                }
                if (w != "") { hd = w; i = j; continue }
            }
            if (c == "\n") {
                emit(); i++
                if (hd != "") {
                    while (i <= n) {
                        k = index(substr(t, i), "\n")
                        if (k == 0) { l = substr(t, i); i = n + 1 } else { l = substr(t, i, k - 1); i += k }
                        sub(/^\t+/, "", l)
                        if (l == hd) break
                    }
                    hd = ""
                }
                continue
            }
            if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")") { emit(); i++; continue }
            seg = seg c; i++
        }
        emit()
    }'
}

# A Gradle run - gradle, gradlew or gradlew.bat, with any path, after variable
# assignments, or started through env, time, nice, exec, call, sh -c, bash -c,
# cmd /c or powershell -Command - and, with a second argument, one whose own
# task list names one of those tasks; a task excluded with -x does not count.
GRADLE='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((env|time|nice|exec|command|call|(sh|bash)[[:space:]]+-c|cmd(\.exe)?[[:space:]]+/[cC]|powershell(\.exe)?[[:space:]]+-(Command|c))[[:space:]]+)*([^[:space:]]*[/\\])?gradlew?(\.bat)?'
gradle_commands() {
    commands "$1" | grep -E "$GRADLE"'([[:space:]]|$)' \
        | sed -E 's/(^|[[:space:]])(-x|--exclude-task)([[:space:]]+|=)[^[:space:]]+//g'
}
runs_gradle() {
    if [ -n "${2:-}" ]; then
        gradle_commands "$1" | grep -Eq "$GRADLE"'[[:space:]]([^[:space:]]+[[:space:]]+)*([^[:space:]]*:)?('"$2"')([[:space:]]|$)'
    else
        gradle_commands "$1" | grep -q .
    fi
}

# The files a command writes its output to, by statement - a pipeline between
# ; && || & ( ) and line breaks: per statement a line "S", then "C <command>"
# for each simple command of its pipeline (quotes dropped, redirections left
# out), and "F <w|a> <file>" for each file it writes to: > 1> 2> *> &> >| (w)
# and the same with >> (a, appended), and tee, Tee-Object, Out-File and
# Set-Content (w) and Add-Content (a) after a pipe, with -a, --append or
# -Append (a). A redirection to another stream (2>&1, *>&1) is no file.
redirects() {
    printf '%s\n' "$1" | awk '
    function decode(s,   t, i, n, c, d) {
        t = ""; n = length(s)
        for (i = 1; i <= n; i++) {
            c = substr(s, i, 1)
            if (c == "\\" && i < n) {
                i++; d = substr(s, i, 1)
                if (d == "n") t = t "\n"
                else if (d == "t") t = t "\t"
                else if (d == "u") { t = t "?"; i += 4 }
                else if (d != "r") t = t d
            } else t = t c
        }
        return t
    }
    function word_end() { if (inword) words[++nw] = w; w = ""; inword = 0 }
    function command_end(   k, line) {
        word_end()
        if (nw > 0) {
            line = words[1]
            for (k = 2; k <= nw; k++) line = line " " words[k]
            print "C\t" line
            writers()
        }
        nw = 0
    }
    # tee and the PowerShell cmdlets that write what comes down the pipe to a file.
    function writers(   name, k, lw, mode, file) {
        name = words[1]; sub(/^.*[\/\\]/, "", name); name = tolower(name); sub(/\.exe$/, "", name)
        if (name == "tee") {
            mode = "w"
            for (k = 2; k <= nw; k++) if (words[k] == "-a" || words[k] == "--append") mode = "a"
            for (k = 2; k <= nw; k++) if (substr(words[k], 1, 1) != "-") print "F\t" mode "\t" words[k]
            return
        }
        if (name != "tee-object" && name != "out-file" && name != "set-content" && name != "add-content") return
        mode = (name == "add-content") ? "a" : "w"; file = ""
        for (k = 2; k <= nw; k++) {
            lw = tolower(words[k])
            if (lw == "-append") { mode = "a"; continue }
            if (lw == "-filepath" || lw == "-path" || lw == "-literalpath") { if (k < nw) file = words[k + 1]; k++; continue }
            if (lw == "-variable") { file = "-"; k++; continue }
            if (substr(lw, 1, 1) == "-") { if (lw == "-encoding" || lw == "-width" || lw == "-value" || lw == "-inputobject") k++; continue }
            if (file == "") file = words[k]
        }
        if (file != "" && file != "-") print "F\t" mode "\t" file
    }
    {
        t = decode($0); n = length(t); q = ""; w = ""; inword = 0; nw = 0; i = 1
        print "S"
        while (i <= n) {
            c = substr(t, i, 1)
            if (q != "") { if (c == q) q = ""; else w = w c; i++; continue }
            if (c == "\"" || c == "\047") { q = c; inword = 1; i++; continue }
            if (c == ">" || (c == "&" && substr(t, i + 1, 1) == ">")) {
                if (c == "&") i++
                else if (inword && w ~ /^[0-9*]$/) { w = ""; inword = 0 }
                else word_end()
                i++; mode = "w"
                if (substr(t, i, 1) == ">") { mode = "a"; i++ }
                if (substr(t, i, 1) == "|") i++
                if (substr(t, i, 1) == "&") {
                    i++
                    while (i <= n && substr(t, i, 1) ~ /[0-9-]/) i++
                    continue
                }
                while (i <= n && (substr(t, i, 1) == " " || substr(t, i, 1) == "\t")) i++
                target = ""; tq = ""
                while (i <= n) {
                    d = substr(t, i, 1)
                    if (tq != "") { if (d == tq) tq = ""; else target = target d; i++; continue }
                    if (d == "\"" || d == "\047") { tq = d; i++; continue }
                    if (d == " " || d == "\t" || d == "\n" || d == ";" || d == "&" || d == "|" || d == "(" || d == ")" || d == "<" || d == ">") break
                    target = target d; i++
                }
                if (target != "") print "F\t" mode "\t" target
                continue
            }
            if (c == "\n" || c == ";" || c == "(" || c == ")") { command_end(); print "S"; i++; continue }
            if (c == "&") { command_end(); print "S"; i++; if (substr(t, i, 1) == "&") i++; continue }
            if (c == "|") {
                command_end()
                if (substr(t, i + 1, 1) == "|") { print "S"; i += 2 } else i++
                continue
            }
            if (c == " " || c == "\t") { word_end(); i++; continue }
            w = w c; inword = 1; i++
        }
        command_end()
    }'
}

# A file named in a command, as the shell reads it: ~, $HOME, ${NAME}, $env:NAME,
# ${env:NAME} and %NAME% from the environment (any case, as on Windows), $PWD as
# the folder the command ran in, \ as /, and a relative path from that folder.
# Fails on the null device and on a variable the environment does not have - a
# variable of the shell session itself.
target_path() {
    case "$1" in '' | /dev/null | '$null' | [Nn][Uu][Ll] | [Nn][Uu][Ll]:) return 1 ;; esac
    p="$(printf '%s\n' "$1" | HOOK_CWD="$2" awk '
        function value(name,   k) {
            if (toupper(name) == "PWD" && ENVIRON["HOOK_CWD"] != "") return ENVIRON["HOOK_CWD"]
            if (name in ENVIRON) return ENVIRON[name]
            for (k in ENVIRON) if (toupper(k) == toupper(name)) return ENVIRON[k]
            missing = 1
            return ""
        }
        {
            s = $0; out = ""
            if (s == "~" || substr(s, 1, 2) == "~/" || substr(s, 1, 2) == "~\\") { out = value("HOME"); s = substr(s, 2) }
            while (s != "") {
                if (match(s, /^\$\{env:[A-Za-z_][A-Za-z0-9_]*\}/)) { name = substr(s, 7, RLENGTH - 7) }
                else if (match(s, /^\$env:[A-Za-z_][A-Za-z0-9_]*/)) { name = substr(s, 6, RLENGTH - 5) }
                else if (match(s, /^\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) { name = substr(s, 3, RLENGTH - 3) }
                else if (match(s, /^\$[A-Za-z_][A-Za-z0-9_]*/)) { name = substr(s, 2, RLENGTH - 1) }
                else if (match(s, /^%[A-Za-z_][A-Za-z0-9_]*%/)) { name = substr(s, 2, RLENGTH - 2) }
                else { out = out substr(s, 1, 1); s = substr(s, 2); continue }
                len = RLENGTH
                out = out value(name)
                s = substr(s, len + 1)
            }
            if (missing) exit 1
            print out
        }' | tr '\\' '/')" || return 1
    [ -n "$p" ] || return 1
    case "$p" in
        /* | [A-Za-z]:/*) ;;
        *) [ -n "$2" ] || return 1; p="$2/$p" ;;
    esac
    printf '%s\n' "$p"
}

# What a Gradle run or a type check in the command writes its output to: "<w|a>
# TAB <file>" a line, for each statement that runs one.
output_files() {
    cwd="$(json_path cwd)"
    redirects "$1" | {
        cmds=""; files=""
        flush() {
            if [ -n "$files" ] && printf '%s' "$cmds" | grep -Eq "$GRADLE"'([[:space:]]|$)|'"$TSC|$CHECK"; then
                printf '%s' "$files" | while IFS="$tab" read -r mode f; do
                    f="$(target_path "$f" "$cwd")" && printf '%s\t%s\n' "$mode" "$f"
                done
            fi
            cmds=""; files=""
        }
        while IFS="$tab" read -r kind a b; do
            case "$kind" in
                S) flush ;;
                C) cmds="$cmds$a
" ;;
                F) files="$files$a$tab$b
" ;;
            esac
        done
        flush
    }
}

# Where pre-bash notes, for one tool call, when it started and how long each
# file it appends to was then: "<w|a> TAB <bytes> TAB <file>" a line.
started_note() {
    call="$(json_string tool_use_id | tr -cd 'A-Za-z0-9_-')"
    printf '%s' "$state_dir/started-${session:-default}-${call:-last}"
}

# The text a command wrote to the files it names, as far as it is new: for a file
# the command appended to, what came after the size it had when the command
# started; a file not written since then, or one appended to when the start was
# not noted, proves nothing. At most 4 MB a file.
redirected_output() {
    started="$(started_note)"
    output_files "$command" | while IFS="$tab" read -r mode f; do
        [ -f "$f" ] || continue
        skip=0
        if [ -f "$started" ]; then
            [ "$f" -nt "$started" ] || continue
            if [ "$mode" = a ]; then
                skip="$(F="$f" awk -F '\t' '$3 == ENVIRON["F"] { print $2; exit }' "$started")"
                # Not the file noted at the start (a cd in the command, say): what is
                # new in it cannot be told from what earlier runs left.
                [ -n "$skip" ] || continue
            fi
        elif [ "$mode" = a ]; then
            continue
        fi
        size="$(wc -c < "$f" | tr -d ' ')"
        [ "$size" -ge "$skip" ] 2>/dev/null || skip=0
        [ $((size - skip)) -le 4194304 ] || continue
        tail -c +"$((skip + 1))" -- "$f" 2>/dev/null | plain_text
    done
    rm -f -- "$started"
}

# Whether a Gradle run sets the property that makes the generator overwrite
# hand edits, in any form Gradle reads: -Pforce, -P force, --project-prop force,
# -Dorg.gradle.project.force, or ORG_GRADLE_PROJECT_force set in the same
# command. A gradle.properties that sets it cannot be seen from here.
forces() {
    runs_gradle "$1" || return 1
    commands "$1" | grep -Eq '(^|[[:space:]])(export[[:space:]]+)?ORG_GRADLE_PROJECT_force[[:space:]]*=|\$env:ORG_GRADLE_PROJECT_force[[:space:]]*=' && return 0
    gradle_commands "$1" \
        | grep -Eq '[[:space:]](-Pforce|-P[[:space:]]+force|--project-prop(=|[[:space:]]+)force|-Dorg\.gradle\.project\.force)([[:space:]=]|$)'
}

# What this session has done, one file per note in the plugin's data directory:
#   dsl-changed-<session>  the DSL changed and no successful compiling build followed;
#                          it lists the project folders the changes were made in
#   dsl-warned-<session>   the last build that compiled it left these DSL warnings, which
#                          no line of .elasticore/accepted-warnings.txt accepts
#   ts-client-<session>    the DSL changed in a project with a generated TypeScript
#                          client, and nothing has generated the client since; it lists
#                          those projects
#   ts-screens-<session>   ... and screens type-checked against it have not been
#                          checked since the client was; it lists their folders
#   legacy-noted-<session> the 2.x-generator warning was given
#   merged-noted-<session> what an edit of a merged generated file means was said
#   refused-<session>      the names of the files whose edit was refused
#   issue-noted-<session>  the report-issue skill was suggested
# and in an ElastiCORE checkout (contributor mode):
#   guides-<session>       the guides edited, "en <name>" or "ko <name>" a line
#   gates-<session>        formatCheck and diffErrorprone passed since the code last changed
#   push-noted-<session>   what a push still lacked, once said
state() {
    base="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/elasticore-agent-kit-$(id -u 2>/dev/null || echo user)}"
    state_dir="$(printf '%s' "$base" | tr '\\' '/')"
    session="$(json_string session_id | tr -cd 'A-Za-z0-9_-')"
    marker="$state_dir/dsl-changed-${session:-default}"
    warned="$state_dir/dsl-warned-${session:-default}"
    ts_client="$state_dir/ts-client-${session:-default}"
    ts_screens="$state_dir/ts-screens-${session:-default}"
    legacy="$state_dir/legacy-noted-${session:-default}"
    merged_noted="$state_dir/merged-noted-${session:-default}"
    refused="$state_dir/refused-${session:-default}"
    issue_noted="$state_dir/issue-noted-${session:-default}"
    guides="$state_dir/guides-${session:-default}"
    gates="$state_dir/gates-${session:-default}"
    pushed="$state_dir/push-noted-${session:-default}"
}

note() {
    mkdir -p -- "$state_dir" 2>/dev/null && : > "$1"
}

# Adds a line to a note, once.
note_line() {
    mkdir -p -- "$state_dir" 2>/dev/null || return 0
    [ -f "$1" ] && grep -q -x -F -e "$2" -- "$1" 2>/dev/null && return 0
    printf '%s\n' "$2" >> "$1"
}

# A JSON string value's text as it was printed: the escapes decoded, carriage
# returns dropped, a colour (\u001b[31m) left out; another \uXXXX becomes "?".
decoded() {
    printf '%s\n' "$1" | awk '{
        n = length($0); t = ""
        for (i = 1; i <= n; i++) {
            c = substr($0, i, 1)
            if (c != "\\" || i == n) { t = t c; continue }
            i++; d = substr($0, i, 1)
            if (d == "n") t = t "\n"
            else if (d == "t") t = t "\t"
            else if (d == "u") {
                u = tolower(substr($0, i + 1, 4)); i += 4
                if (u == "001b" && match(substr($0, i + 1), /^\[[0-9;]*m/)) i += RLENGTH
                else if (u != "001b") t = t "?"
            }
            else if (d != "r") t = t d
        }
        print t
    }'
}

# Text from a file: the NUL bytes of a UTF-16 file (what Windows PowerShell 5.1
# writes with > and Out-File) and its byte order mark, carriage returns and
# colours left out.
plain_text() {
    tr -d '\000\r\376\377' | awk '{ gsub(/\033\[[0-9;]*m/, ""); print }'
}

# The DSL validation warnings in a build's output, one a line, each once: the
# lines after "[elcore3] DSL validation warnings:" and its dashes, up to the
# blank line the rule engine ends the list with.
dsl_warnings() {
    printf '%s\n' "$1" | awk '
        index($0, "DSL validation warnings:") { on = 1; next }
        !on { next }
        { line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
        line ~ /^-+$/ { next }
        line == "" || line ~ /^(> Task |BUILD |=== |FAILURE: |\* What went wrong)/ { on = 0; next }
        !(line in seen) { seen[line] = 1; print line }'
}

# The DSL warnings a project has accepted - a generator defect the DSL cannot
# get round, say: the lines of .elasticore/accepted-warnings.txt, each a part
# of a warning's text. A line starting with # is a comment, and so is what
# follows a space and a # (the issue the warning waits for). Read from the
# project folders this session changed the model in, and from the folder the
# command ran in and those above it.
accepted_patterns() {
    {
        [ -f "$marker" ] && cat -- "$marker"
        dir="$(json_path cwd)"
        i=0
        while [ -n "$dir" ] && [ "$i" -lt 8 ]; do
            printf '%s\n' "$dir"
            parent="$(dirname -- "$dir")"
            [ "$parent" = "$dir" ] && break
            dir="$parent"
            i=$((i + 1))
        done
    } | while IFS= read -r d; do
        [ -n "$d" ] && [ -f "$d/.elasticore/accepted-warnings.txt" ] && printf '%s\n' "$d/.elasticore/accepted-warnings.txt"
    done | sort -u | while IFS= read -r f; do
        awk 'NR == 1 { sub(/^\357\273\277/, "") }
             { sub(/\r$/, ""); sub(/^[ \t]+/, "") }
             /^#/ { next }
             { sub(/[ \t]+#.*$/, ""); sub(/[ \t]+$/, "") }
             $0 != "" { print }' "$f"
    done
}

# The warnings (one a line) that no accepted line is a part of.
unaccepted() {
    [ -n "$1" ] || return 0
    patterns="$(accepted_patterns)"
    if [ -z "$patterns" ]; then
        printf '%s\n' "$1"
        return 0
    fi
    printf '%s\n' "$1" | PATTERNS="$patterns" awk '
        BEGIN { n = split(ENVIRON["PATTERNS"], p, "\n") }
        { for (i = 1; i <= n; i++) if (p[i] != "" && index($0, p[i]) > 0) next; print }'
}

# The first warnings of a list, for a message: at most five, each cut at 300 characters.
some_warnings() {
    printf '%s\n' "$1" | awk 'NR <= 5 { print (length($0) > 300 ? substr($0, 1, 300) "..." : $0) }' \
        | awk 'NR > 1 { printf " | " } { printf "%s", $0 }'
}

lines_in() {
    printf '%s\n' "$1" | grep -c .
}

# Whether the project holds a TypeScript client ElastiCORE generated, as
# ElastiCORE itself tells one: src/main/ts with a file the merge base names, or a
# .ts file there whose first line is //ecd: (before the merge).
has_client() {
    [ -d "$1/src/main/ts" ] || return 1
    base_file="$(merge_base "$1")" && grep -a -q -F -e 'src/main/ts/' -- "$base_file" 2>/dev/null && return 0
    for f in "$1"/src/main/ts/*.ts; do
        [ -f "$f" ] || continue
        case "$(head -n 1 -- "$f" 2>/dev/null)" in //ecd:*) return 0 ;; esac
    done
    return 1
}

# Whether a folder holds screens type-checked against the client: a tsconfig.json
# that includes src/main/ts, or a package.json with a check (typecheck,
# type-check) script.
screens_in() {
    { [ -f "$1/tsconfig.json" ] && grep -q -F -e 'src/main/ts' -- "$1/tsconfig.json" 2>/dev/null; } && return 0
    [ -f "$1/package.json" ] && grep -Eq '"(check|typecheck|type-check)"[[:space:]]*:' -- "$1/package.json" 2>/dev/null
}

# The folders of such screens in a project, relative to it: the project folder,
# src/main/ts (a client with a check of its own) and two levels of folders below
# the project, leaving out build output, node_modules and the like.
screen_dirs() {
    screens_in "$1" && printf '.\n'
    { [ -f "$1/src/main/ts/tsconfig.json" ] || screens_in "$1/src/main/ts"; } && printf 'src/main/ts\n'
    for d1 in "$1"/*/; do
        d1="${d1%/}"
        n1="${d1##*/}"
        case "$n1" in node_modules | build | out | bin | target | dist | gradle | src | .*) continue ;; esac
        [ -d "$d1" ] || continue
        screens_in "$d1" && printf '%s\n' "$n1"
        for d2 in "$d1"/*/; do
            d2="${d2%/}"
            n2="${d2##*/}"
            case "$n2" in node_modules | build | out | bin | target | dist | gradle | .*) continue ;; esac
            [ -d "$d2" ] && screens_in "$d2" && printf '%s\n' "$n1/$n2"
        done
    done
}

# Whether the build scripts of a project, or of the folders above it, set
# typescriptClient = true - then every build runs elcore3ts after elcore3.
client_with_build() {
    dir="$1"
    i=0
    while [ -n "$dir" ] && [ "$i" -lt 4 ]; do
        for script in "$dir/build.gradle" "$dir/build.gradle.kts"; do
            [ -f "$script" ] || continue
            code_of "$script" | grep -Eq '(^|[^A-Za-z0-9_])typescriptClient[[:space:]]*(=|\.set[[:space:]]*\()[[:space:]]*true' && return 0
        done
        parent="$(dirname -- "$dir")"
        [ "$parent" = "$dir" ] && break
        dir="$parent"
        i=$((i + 1))
    done
    return 1
}

# A type check of TypeScript screens: tsc or vue-tsc (through npx, pnpm, yarn or
# bunx too), or the check, typecheck or type-check script run by npm, pnpm, yarn
# or bun - not tsc --help, --version, --init or --showConfig.
TSC='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((env|time|nice|exec|command|call)[[:space:]]+)*([^[:space:]]*[/\\])?(((npx|bunx)(\.cmd)?|(pnpm|yarn)(\.cmd)?([[:space:]]+(exec|dlx))?)[[:space:]]+(-[^[:space:]]+[[:space:]]+)*)?(tsc|vue-tsc)(\.cmd)?([[:space:]]|$)'
CHECK='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((env|time|nice|exec|command|call)[[:space:]]+)*([^[:space:]]*[/\\])?(npm|pnpm|yarn|bun)(\.cmd)?([[:space:]]+-[^[:space:]]*([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+(run|run-script)[[:space:]]+(check|typecheck|type-check)([[:space:]]|$)'
type_checks() {
    commands "$1" | grep -E "$TSC|$CHECK" | grep -Evq '(^|[[:space:]])(--help|-h|--version|-v|--init|--showConfig)([[:space:]]|$)'
}

# The folder a type check ran in: the folder the command ran in, then its last cd
# (pushd, Set-Location), then the folder the check names (npm --prefix, pnpm -C /
# --dir, yarn --cwd, tsc -p / --project, a tsconfig file standing for its folder).
# Fails when the command's folder is not known.
check_dir() {
    base="$(json_path cwd)"
    [ -n "$base" ] || return 1
    commands "$1" | P="$TSC|$CHECK" awk '
        tolower($1) ~ /^(cd|pushd|set-location|sl|chdir)$/ {
            x = ""
            for (k = 2; k <= NF; k++) {
                if (x == "" && tolower($k) ~ /^(-l|-p|\/d|--|-path|-literalpath)$/) continue
                x = (x == "" ? $k : x " " $k)
            }
            if (x != "") { print "D\t" x; named = "" }
            next
        }
        $0 ~ ENVIRON["P"] {
            for (k = 1; k < NF; k++)
                if ($k ~ /^(--prefix|-C|--dir|--cwd|-p|--project)$/) named = $(k + 1)
            for (k = 1; k <= NF; k++)
                if ($k ~ /^(--prefix|--dir|--cwd|--project)=/) { named = $k; sub(/^[^=]*=/, "", named) }
        }
        END { if (named != "") print "D\t" named }' | {
        dir="$base"
        while IFS="$tab" read -r kind d; do
            [ "$kind" = D ] || continue
            p="$(target_path "$d" "$dir")" || continue
            case "$p" in *.json) p="$(dirname -- "$p")" ;; esac
            dir="$p"
        done
        printf '%s\n' "$dir"
    }
}

# The noted screen folders other than the one a passing type check ran in.
screens_left() {
    D="$1" awk '
        function norm(p) {
            gsub(/\\/, "/", p)
            while (sub(/\/\.\//, "/", p)) ;
            sub(/\/\.$/, "", p); sub(/\/+$/, "", p)
            return tolower(p)
        }
        norm($0) != norm(ENVIRON["D"])' "$ts_screens"
}

GENERATING='elcore[A-Za-z0-9]*|compileJava|compileKotlin|classes|processResources|build|assemble|bootRun|test|check|jar|bootJar|bootWar'
COMPILING='compileJava|compileKotlin|classes|build|assemble|bootRun|test|check|jar|bootJar|bootWar'

# --- Codex CLI ------------------------------------------------------------------
# Codex sends the same events in its own shapes: an edit is the apply_patch tool,
# its patch text in tool_input.command; a Stop is answered with decision "block"
# and a reason, which Codex takes as the next prompt. Its hooks file passes
# "codex" as the second argument.

# The files a patch adds, changes, deletes or moves to: "<tool> TAB <file>" a line.
# A file the patch adds, or moves another onto, gets all of its content from the
# patch - a Write; one it changes or deletes is a Patch, never the one-block Edit
# the guard lets through. A relative path is taken from the folder the call ran in.
patch_files() {
    cwd="$(json_path cwd)"
    decoded "$1" | awk '
        { sub(/\r$/, "") }
        match($0, /^\*\*\* (Add File|Update File|Delete File|Move to): /) {
            verb = substr($0, 5, RLENGTH - 6); f = substr($0, RLENGTH + 1); sub(/[ \t]+$/, "", f)
            if (f != "") print ((verb == "Add File" || verb == "Move to") ? "Write" : "Patch") "\t" f
        }' | while IFS="$tab" read -r t f; do
        f="$(printf '%s' "$f" | tr '\\' '/')"
        case "$f" in
            /* | [A-Za-z]:/*) ;;
            *) [ -n "$cwd" ] || continue; f="$cwd/$f" ;;
        esac
        printf '%s\t%s\n' "$t" "$f"
    done
}

# The files a tool call edits: "<tool> TAB <file>" a line - the file_path of an
# Edit, Write or MultiEdit, or each file of an apply_patch.
edited_files() {
    t="$(json_string tool_name)"
    if [ "$t" = apply_patch ]; then
        patch_files "$(json_string command)"
    else
        p="$(json_path file_path)"
        [ -n "$p" ] && printf '%s\t%s\n' "$t" "$p"
    fi
}

# The answer that sends the agent back instead of stopping.
stop_answer() {
    if [ "$agent" = codex ]; then
        printf '{"decision":"block","reason":"%s"}\n' "$(json_text "$1")"
    else
        context Stop "$1"
    fi
}

# --- contributor mode: a checkout of ElastiCORE itself ------------------------------
# There the samples and templates are generated and edited on purpose, so the
# guards of a user project stay off; the rules of the checkout's CONTRIBUTING.md
# that a hook can see are checked instead.

# The root of an ElastiCORE checkout at or above a folder: elasticore-project/
# elasticore-base, and a settings.gradle that includes it.
checkout_root() {
    dir="$1"
    i=0
    while [ -n "$dir" ] && [ "$i" -lt 40 ]; do
        if [ -d "$dir/elasticore-project/elasticore-base" ]; then
            for s in "$dir/settings.gradle" "$dir/settings.gradle.kts"; do
                [ -f "$s" ] && grep -q -F -e 'elasticore-project:elasticore-base' -- "$s" 2>/dev/null \
                    && { printf '%s' "$dir"; return 0; }
            done
        fi
        parent="$(dirname -- "$dir")"
        [ "$parent" = "$dir" ] && break
        dir="$parent"
        i=$((i + 1))
    done
    return 1
}

HISTORY='elasticore-project/elasticore-base/src/main/resources/elasticore-guide/elasticore-history.md'
GUIDES='elasticore-project/elasticore-base/src/main/resources/elasticore-guide'

# An edit in a checkout: the history is assembled from changes/ fragments at a
# release, so a feature branch never edits it - unless the checkout predates
# changes/, or the branch is a release's (version/*).
contributor_refusal() {
    [ "${ELASTICORE_ALLOW_HISTORY_EDITS:-}" = 1 ] && return 0
    case "$1" in "$2/$HISTORY") ;; *) return 0 ;; esac
    [ -d "$2/changes" ] || return 0
    case "$(git -C "$2" symbolic-ref --short HEAD 2>/dev/null)" in version/*) return 0 ;; esac
    deny "This ElastiCORE checkout records a change as a fragment of its own, changes/<topic>.md (changes/README.md has the form: one ### section with its #### entries - why, before and after, how it was checked, the files), not as an edit to elasticore-history.md: the release moves the fragments into the history (./gradlew assembleHistory), and the CI job Change record fails a pull request that edits it. Write the fragment instead. If this is a release branch's work, the user can set ELASTICORE_ALLOW_HISTORY_EDITS=1."
}

# What an edit in a checkout calls for, as text: non-ASCII in elasticore-base's main
# sources; a guide changed in one language (noted for the Stop); code changed since
# the format and Error Prone gates last passed.
contributor_note() {
    rel="${1#"$2"/}"
    case "$rel" in
        *.java | *.kt | *.kts | *.gradle) rm -f -- "$gates" ;;
    esac
    case "$rel" in
        elasticore-project/elasticore-base/src/main/java/*)
            lines="$(grep -n "$(printf '[\200-\377]')" -- "$1" 2>/dev/null | cut -d: -f1 | head -n 5 | awk 'NR > 1 { printf ", " } { printf "%s", $0 }')"
            [ -n "$lines" ] && printf '%s' "$1 now holds characters that are not ASCII (line $lines). elasticore-base's main sources are ASCII only - an IDE or a plain javac on Korean Windows reads them as MS949 and fails, and SourceAsciiTest fails the build: write -> for an arrow, plain quotes and hyphens, English comments; Korean text belongs in a test or a resource file. "
            ;;
        "$GUIDES"/ko/*.md) note_line "$guides" "ko ${rel#"$GUIDES"/ko/}" ;;
        "$GUIDES"/elasticore-history.md) ;;
        "$GUIDES"/*.md) note_line "$guides" "en ${rel#"$GUIDES"/}" ;;
    esac
}

# The guides changed in this session in one language only: "<changed path> TAB <twin path>" a line.
guides_alone() {
    [ -f "$guides" ] || return 0
    awk '{ seen[$0] = 1; k[NR] = $0 }
         END {
             for (i = 1; i <= NR; i++) {
                 lang = substr(k[i], 1, 2); name = substr(k[i], 4)
                 other = (lang == "en" ? "ko" : "en") " " name
                 if (!(other in seen) && !(k[i] in done)) {
                     done[k[i]] = 1
                     if (lang == "en") print name "\tko/" name; else print "ko/" name "\t" name
                 }
             }
         }' "$guides"
}

# A git push or a gh pr create among the commands.
PUSH='^([^[:space:]]*[/\\])?git(\.exe)?([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--[^[:space:]]+)*[[:space:]]+push([[:space:]]|$)|^([^[:space:]]*[/\\])?gh(\.exe)?[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'

# What a push from a checkout still lacks, by the rules of its CONTRIBUTING.md: a
# changes/ fragment when the branch changes what ElastiCORE ships, and the format
# and Error Prone gates on the changed lines since the code last changed in this session.
push_missing() {
    root="$1"
    git -C "$root" rev-parse --verify -q origin/main > /dev/null 2>&1 || return 0
    changed="$( { git -C "$root" diff --name-only origin/main...HEAD; git -C "$root" status --porcelain | cut -c4-; } 2>/dev/null | sort -u)"
    if printf '%s\n' "$changed" | grep -E '^elasticore-project/[^/]+/src/main/' | grep -qvxF "$HISTORY"; then
        fragments="$( { git -C "$root" diff --name-only --diff-filter=A origin/main...HEAD -- changes; \
            git -C "$root" status --porcelain -- changes | grep -E '^(\?\?|A)' | cut -c4-; } 2>/dev/null \
            | grep -E '^changes/[^/]+\.md$' | grep -vxF 'changes/README.md')"
        [ -n "$fragments" ] || printf '%s' "no new changes/<topic>.md on this branch, and it changes what ElastiCORE ships (src/main) - the CI job Change record fails it (changes/README.md has the form); "
    fi
    if printf '%s\n' "$changed" | grep -Eq '\.java$' && [ ! -f "$gates" ]; then
        printf '%s' "the gates on the changed lines have not passed since the code last changed in this session - run ./gradlew formatChanged (commit what it changes), then ./gradlew formatCheck diffErrorprone -PdiffBase=origin/main --no-daemon (or ./gradlew prCheck), which CI runs as Format and static analysis of the change; "
    fi
}

# --- ElastiCORE itself falling short -------------------------------------------------
# A sign that the defect may be ElastiCORE's, not the project's: a compile error in
# a file the generator wrote, a generator that failed with an exception, or a command
# that changes a generated file whose edit was refused. Suggested once a session.
ISSUE_HINT="If the DSL is right, this may be an ElastiCORE defect: the report-issue skill can reproduce it in a minimal project and draft an issue for the user to post - only with their yes."

# Generated files named by compile errors in the output (javac's path:line: error,
# kotlinc's e: [file:///]path:line:col).
generated_errors() {
    printf '%s\n' "$1" | sed -nE \
        -e 's#^(.*\.(java|kt)):[0-9]+: error:.*#\1#p' \
        -e 's#^e: (file://)?(.*\.kt):[0-9]+:[0-9]+.*#\2#p' \
        -e 's#^e: (file://)?(.*\.kt): \([0-9]+, [0-9]+\).*#\2#p' | tr '\\' '/' | sort -u | while IFS= read -r f; do
        case "$f" in /[A-Za-z]:/*) f="${f#/}" ;; esac
        [ -f "$f" ] || continue
        case "$(classify "$f")" in managed | merged | block | regenerated) printf '%s\n' "$f" ;; esac
    done | head -n 3
}

# A generation task that failed with an exception of the generator's own - not the
# model check, which names what to change in the DSL.
generator_failed() {
    printf '%s\n' "$1" | grep -Eq "Execution failed for task '[^']*elcore[A-Za-z0-9]*'" || return 1
    printf '%s\n' "$1" | grep -Eq 'the model check failed|This project holds the code 2.x generates|DSL Validation' && return 1
    printf '%s\n' "$1" | grep -Eq '[A-Za-z0-9_$.]+(Exception|Error)([:[:space:]]|$)'
}

# Whether a command failed that Codex reports as PostToolUse - it has no
# PostToolUseFailure: the exit code in its tool_response.
command_failed() {
    [ "$agent" = codex ] || return 1
    printf '%s' "$input" | grep -Eq '"exit_code"[[:space:]]*:[[:space:]]*-?[1-9]'
}

# A command that changes a file whose edit was refused in this session: the
# refusal worked around through the shell.
works_around() {
    [ -f "$refused" ] || return 1
    cmd="$(decoded "$1")"
    printf '%s\n' "$cmd" | grep -Eq 'sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|perl[[:space:]]+-[a-z]*i|>|Set-Content|Add-Content|Out-File|WriteAll|Copy-Item|Move-Item|(^|[[:space:];|&])(cp|mv|tee|python[0-9]*|node|ruby|patch|git[[:space:]]+(apply|checkout|restore))[[:space:]]' || return 1
    while IFS= read -r name; do
        [ -n "$name" ] && case "$cmd" in *"$name"*) return 0 ;; esac
    done < "$refused"
    return 1
}

# --- one edited file ---------------------------------------------------------------

# The refusal of an edit of one file, printed, or nothing. $tool: Edit, Write,
# MultiEdit, or Patch (a change or delete in a patch).
refusal_for() {
    path="$1"
    if root="$(checkout_root "$(dirname -- "$path")")"; then
        contributor_refusal "$path" "$root"
        return 0
    fi
    [ "${ELASTICORE_ALLOW_GENERATED_EDITS:-}" = 1 ] && return 0
    case "$path" in
        *.java | *.kt | *.ts | *.tsx | *.proto | *.xml | *.properties | *.yml | *.yaml | *.graphqls | */src/main/resources/blueprint/*) ;;
        *) return 0 ;;
    esac
    case "$(classify "$path")" in
    managed)
        adds_block && return 0
        deny "ElastiCORE generates $path from the DSL (its first line is //ecd:). A hand edit is not kept in step: from the next build on, the generator skips the file - SKIP(user-modified) - and it no longer follows the DSL. (The 3.0 code merges hand edits: if this project is on ElastiCORE 3.0 and its build sets neither output = 'v2' nor merge = false, build once first - the build takes a file nobody edited over without its //ecd: line, and an edit made after that is kept.) Make this change in the YAML under src/main/resources/blueprint/<domain>/, or in a file that carries the line '// Initially generated by ElastiCORE;' - the elasticore skill says which. Code that has to live in this very file, such as a custom query in a repository, goes in a preserved block right before the class's closing brace - the generator puts a block's code there on every regeneration: one Edit whose old text ends with that last '}' line and whose new text is the same with one whole block inserted before the '}' - '// !----------', the code with fully qualified type names, '// ------------!', each on lines of their own - and nothing else; only that edit goes through. Do not make the change another way, with a shell command or a script. If the user wants this file edited by hand anyway, they can set ELASTICORE_ALLOW_GENERATED_EDITS=1."
        ;;
    regenerated)
        case "$path" in
        *.graphqls)
            deny "ElastiCORE writes $path from the compiled classes on every build (elcoreGraphQl), so an edit to it is lost. An entity's GraphQL operations follow the YAML in src/main/resources/blueprint/<domain>/ and env.yml (graphql:); an operation of your own goes in a .graphqls file of your own under src/main/resources/graphql/, written as 'extend type Query' or 'extend type Mutation'. Do not make the change another way, with a shell command or a script. If the user wants this file edited anyway, they can set ELASTICORE_ALLOW_GENERATED_EDITS=1."
            return 0
            ;;
        esac
        deny "ElastiCORE writes $path again on every generation, so an edit to it is lost. The model is the YAML in src/main/resources/blueprint/<domain>/; a message is translated or reworded in a copy with a locale suffix next to the default file, such as <domain>-messages_ko.properties. Do not make the change another way, with a shell command or a script. If the user wants this file edited anyway, they can set ELASTICORE_ALLOW_GENERATED_EDITS=1."
        ;;
    merged)
        # An edit of a merged file is kept; a Write replaces all of it - usually a class
        # of the agent's own given the name of a generated one, whose code (an entity's
        # controller, say) is then gone, and into which the next build merges the DSL's
        # changes as if it were still that file. Edit and MultiEdit stay allowed.
        [ "$tool" = Write ] || return 0
        base_name=".elasticore/$(basename -- "$(merge_base "$(merge_root "$path")")")"
        deny "$path holds a file ElastiCORE generates from the DSL (it is in the merge base, $base_name), and Write replaces all of it: what the generator wrote there - an entity's API, its DTO, its mapper - would be gone, and the next build would merge the DSL's changes into a file that no longer has anything to do with them. To change this file, Edit it: the edit is kept and merged with the DSL's changes. To add a class of your own, choose another name, one the generator does not write. Do not replace it another way, with a shell command or a script. If the user wants the file replaced anyway, they can set ELASTICORE_ALLOW_GENERATED_EDITS=1."
        ;;
    esac
    return 0
}

# What an edit of one file calls for, as text, or nothing: after a DSL change, what
# to run; after an edit of a generated file, what is kept.
note_for() {
    path="$1"
    [ -n "$path" ] || return 0
    if root="$(checkout_root "$(dirname -- "$path")")"; then
        contributor_note "$path" "$root"
        return 0
    fi
    model=0
    if is_dsl "$path"; then
        model=1
        project="${path%%/src/main/resources/blueprint/*}"
    else
        case "$path" in
            */build.gradle | */build.gradle.kts) grep -q 'elasticore' "$path" 2>/dev/null && model=1 && project="$(dirname -- "$path")" ;;
        esac
    fi
    if [ "$model" = 1 ]; then
        text=""
        # What the last build left is about the model before this change.
        rm -f -- "$warned"
        if [ ! -f "$marker" ]; then
            text="You changed the ElastiCORE model. Before you finish, run ./gradlew compileJava - it generates first, unless the build sets generateBeforeCompile = false; then run elcore3 or elcore before it - and fix every DSL validation warning and compile error, in the DSL. Read the generator's SKIP(...) lines too. "
        fi
        note_line "$marker" "$project"
        # A project with a generated TypeScript client: the change also needs a run that
        # generates it, and the screens on it a type check after that.
        if has_client "$project"; then
            note_line "$ts_client" "$project"
            screens="$(screen_dirs "$project")"
            if [ -n "$screens" ]; then
                printf '%s\n' "$screens" | while IFS= read -r d; do note_line "$ts_screens" "$project/$d"; done
            fi
            if [ -n "$text" ]; then
                text="${text}This project has a TypeScript client generated into src/main/ts: regenerate it too - ./gradlew elcore3ts, or any build when the elasticore { } block sets typescriptClient = true - "
                if [ -n "$screens" ]; then
                    text="${text}and then type-check the screens that use it ($(printf '%s\n' "$screens" | awk 'NR > 1 { printf ", " } { printf "%s", $0 }')): npm run check there, or npx tsc --noEmit, and fix what the change broke. "
                else
                    text="${text}and check the screens that use it. "
                fi
            fi
        fi
        if is_dsl "$path" && [ ! -f "$legacy" ] \
            && grep -Eq '@(access|owner|password|login|compute|snapshot)([^A-Za-z]|$)|^[[:space:]]*states:|:[[:space:]]*(money|quantity)([^A-Za-z]|$)' "$path" 2>/dev/null \
            && runs_2x "${path%%/src/main/resources/blueprint/*}"; then
            note "$legacy"
            text="${text}This project's build runs the 2.x generator (elcore): it says output = 'v2', or its ElastiCORE is 2.x or an early 3.0 build older than 3.0.261028 and it has no elasticore { } block that sets architecture, language or rules. That generator ignores @access, @owner, @password, @login, states:, @compute and @snapshot without a warning, and writes money and quantity fields without the converters the rule engine adds: none of that will be checked, hashed or derived. Tell the user before relying on it; moving the project to the 3.0 rule engine is their decision."
        fi
        printf '%s' "$text"
        return 0
    fi
    case "$(classify "$path")" in
    block)
        printf '%s' "$path is generated by ElastiCORE. Only code between '// !----------' and '// ------------!' survives regeneration. A change outside the block is lost on the 2.x generator (elcore) and makes the 3.0 rule engine (elcore3) skip the whole file - put it in the DSL instead."
        ;;
    merged)
        [ -f "$merged_noted" ] && return 0
        note "$merged_noted"
        # The file classify() read: the base under the name this project has.
        base_name=".elasticore/$(basename -- "$(merge_base "$(merge_root "$path")")")"
        printf '%s' "$path is generated from the DSL and merged (it is in the merge base, $base_name): ElastiCORE keeps your edit and merges the DSL's later changes into it. Where the DSL changes the same lines, the next build writes <<<<<<< yours / >>>>>>> elasticore marks into the file and fails until they are resolved. Whatever the DSL can say - a field, a check, a search condition, access - belongs in the DSL; keep hand edits for what it cannot."
        ;;
    esac
    return 0
}

case "$event" in

pre-edit)
    state
    # One file at a time - an apply_patch names several; the first refusal is the answer.
    while IFS="$tab" read -r tool path; do
        [ -n "$path" ] || continue
        answer="$(refusal_for "$path")"
        if [ -n "$answer" ]; then
            printf '%s\n' "$answer"
            note_line "$refused" "$(basename -- "$path")"
            break
        fi
    done <<EOF
$(edited_files)
EOF
    exit 0
    ;;

pre-bash)
    # A build whose output goes to a file: note when it starts, and how long a file it
    # appends to is, so that post-bash reads only what this run wrote.
    case "$input" in
        *gradle* | *tsc* | *check*)
            state
            started="$(started_note)"
            rm -f -- "$started"
            files="$(output_files "$(json_string command)")"
            if [ -n "$files" ] && mkdir -p -- "$state_dir" 2>/dev/null; then
                printf '%s\n' "$files" | while IFS="$tab" read -r mode f; do
                    size=0
                    [ "$mode" = a ] && [ -f "$f" ] && size="$(wc -c < "$f" | tr -d ' ')"
                    printf '%s\t%s\t%s\n' "$mode" "$size" "$f"
                done > "$started"
            fi
            ;;
    esac
    # An ElastiCORE checkout: no -Pforce guard; before a push, what CONTRIBUTING.md asks
    # for and the branch lacks - said once, by refusing that one push.
    if root="$(checkout_root "$(json_path cwd)")"; then
        case "$input" in *push* | *pr*create*) ;; *) exit 0 ;; esac
        commands "$(json_string command)" | grep -Eq "$PUSH" || exit 0
        state
        missing="$(push_missing "$root")"
        [ -n "$missing" ] || exit 0
        [ -f "$pushed" ] && [ "$(cat -- "$pushed" 2>/dev/null)" = "$missing" ] && exit 0
        mkdir -p -- "$state_dir" 2>/dev/null && printf '%s' "$missing" > "$pushed"
        deny "Before this push, by the checkout's CONTRIBUTING.md: ${missing}and rebase on the latest origin/main if the branch is behind it. Do what is missing, then push again; if it is done already (outside this session), push again - this is said once."
        exit 0
    fi
    [ "${ELASTICORE_ALLOW_FORCE:-}" = 1 ] && exit 0
    case "$input" in *force*) ;; *) exit 0 ;; esac
    command="$(json_string command)"
    forces "$command" || exit 0
    deny "-Pforce makes the ElastiCORE generator overwrite hand edits in generated files, and those edits are lost. Ask the user first. If they agree, they can run the command themselves, or set ELASTICORE_ALLOW_FORCE=1."
    exit 0
    ;;

post-edit)
    state
    texts=""
    while IFS="$tab" read -r tool path; do
        [ -n "$path" ] || continue
        t="$(note_for "$path")"
        [ -n "$t" ] || continue
        case "$texts" in *"$t"*) ;; *) texts="$texts$t " ;; esac
    done <<EOF
$(edited_files)
EOF
    texts="$(printf '%s' "$texts" | sed 's/[[:space:]]*$//')"
    [ -n "$texts" ] && context PostToolUse "$texts"
    exit 0
    ;;

post-bash)
    # An ElastiCORE checkout: only whether the gates on the changed lines passed.
    if root="$(checkout_root "$(json_path cwd)")"; then
        case "$input" in *gradle*) ;; *) exit 0 ;; esac
        command="$(json_string command)"
        state
        if { runs_gradle "$command" 'prCheck' || { runs_gradle "$command" 'formatCheck' && runs_gradle "$command" 'diffErrorprone'; }; } \
            && [ "$(json_string hook_event_name)" != PostToolUseFailure ] && ! command_failed \
            && printf '%s' "$input" | grep -q -F -e 'BUILD SUCCESSFUL' && ! printf '%s' "$input" | grep -q -F -e 'BUILD FAILED'; then
            note "$gates"
        fi
        exit 0
    fi
    # A generated file whose edit was refused, changed through the shell instead.
    state
    around=""
    if [ ! -f "$issue_noted" ] && works_around "$(json_string command)"; then
        note "$issue_noted"
        around="This command changes a generated file whose edit was refused in this session. Do not work around the refusal: undo it, and make the change in the DSL or in a file you own. If the DSL cannot say what the requirement needs, tell the user - this may be a gap in ElastiCORE: the report-issue skill can draft a reproducible issue for them to post, only with their yes. "
    fi
    case "$input" in
        *gradle* | *tsc* | *check*) ;;
        *) [ -n "$around" ] && context PostToolUse "$around"; exit 0 ;;
    esac
    # Returned before the build ran, or stopped partway: proves nothing.
    json_true run_in_background && exit 0
    json_true interrupted && exit 0
    json_true is_interrupt && exit 0
    command="$(json_string command)"
    # A Gradle command whose own task list generates, and that is not a dry run - or a
    # type check of screens on a generated client that the session's change waits for.
    gradle=0
    if runs_gradle "$command" "$GENERATING" \
        && ! gradle_commands "$command" | grep -Eq '(^|[[:space:]])(--dry-run|-m|help|tasks|--task)([[:space:]]|$)'; then
        gradle=1
    fi
    state
    checked=0
    [ -f "$ts_screens" ] && type_checks "$command" && checked=1
    [ "$gradle" = 1 ] || [ "$checked" = 1 ] || { rm -f -- "$(started_note)"; exit 0; }

    # What Gradle printed. The command itself may name the same words (a grep),
    # so only what came back counts: the tool's response - or the whole output,
    # which Claude Code saves to a file when it is too long to pass on - or, for
    # a command that failed, its error.
    # In two parts: what came in the JSON, still escaped, and what was read from a file.
    hook_event="$(json_string hook_event_name)"
    from_file=""
    if [ "$hook_event" = PostToolUseFailure ]; then
        failed=1
        from_json="$(printf '%s' "$input" | sed -n 's/.*"error"//p')"
    elif command_failed; then
        # Codex has no PostToolUseFailure: a command that failed comes as PostToolUse.
        hook_event=PostToolUse
        failed=1
        from_json="$(printf '%s' "$input" | sed -n 's/.*"tool_response"//p')"
    else
        hook_event=PostToolUse
        failed=0
        from_json="$(printf '%s' "$input" | sed -n 's/.*"tool_response"//p')"
        saved="$(printf '%s' "$from_json" | sed -nE 's/.*"persistedOutputPath"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' | sed 's#\\\\#/#g')"
        if [ -n "$saved" ] && [ -f "$saved" ]; then
            from_json=""
            from_file="$(plain_text < "$saved" 2>/dev/null)"
        fi
    fi
    state
    # A build whose output went to a file (> build.log, *> build.log, | tee build.log):
    # what it wrote there, as new as this run.
    redirected="$(redirected_output)"
    [ -n "$redirected" ] && from_file="$from_file
$redirected"
    output="$from_json
$from_file"
    has() { printf '%s' "$output" | grep -q -F -e "$1"; }
    # The output as it was printed, line by line.
    printed() { decoded "$from_json"; printf '%s\n' "$from_file"; }

    state
    text="$around"
    unreadable=0
    # The model loader prints " * LOAD ERROR: <file>" and the parse error, skips
    # the file and goes on: the build can pass without that part of the model.
    if has '* LOAD ERROR: '; then
        unreadable=1
        text="A blueprint YAML file could not be read: the generator printed its path and the parse error, left the file out of the model and went on - the build can pass without what that file declares. Fix the YAML at the line the error names (indentation, a missing ':' or quote) and build again. "
    fi
    # The warnings no line of .elasticore/accepted-warnings.txt accepts. A list the
    # hook cannot read counts as one that is not accepted.
    left=""
    if has 'DSL validation warnings:'; then
        warnings="$(dsl_warnings "$(printed)")"
        if [ -z "$warnings" ]; then
            left="(the list of warnings could not be read)"
        else
            left="$(unaccepted "$warnings")"
        fi
        if [ -n "$left" ]; then
            text="${text}The 3.0 rule engine (elcore3) listed DSL validation warnings. The model is wrong until they are gone, even when the build passes: fix each line under that header in the DSL and build again. "
            if [ -n "$warnings" ]; then
                accepted=$(( $(lines_in "$warnings") - $(lines_in "$left") ))
                [ "$accepted" -gt 0 ] && text="${text}(${accepted} of the $(lines_in "$warnings") are accepted in .elasticore/accepted-warnings.txt; the others are not.) "
            fi
            text="${text}Only a warning the DSL cannot fix - an ElastiCORE defect, with an issue - is accepted instead, by a line of .elasticore/accepted-warnings.txt, with the user's agreement (the elasticore skill's references/run-and-check.md). "
        fi
    fi
    # The rule engine stops before writing when the model cannot be generated as written
    # (a relation in an exposed composite key, a @deleted a delete would bypass, ...):
    # "[elcore3] the model check failed (N) - fix these and build again:" and one line each.
    # A project 2.x generated that chose no output: the build stops before writing anything.
    if has 'This project holds the code 2.x generates'; then
        text="${text}The build stopped: this project holds the code 2.x generated and its build chose no output. Do not pick one for the user. output = 'v2' keeps the 2.x code; moving to the 3.0 code (output = 'v3') is the user's decision - the migrate skill (/elasticore:migrate) checks first what that move would do, writing nothing. "
    fi
    if has 'the model check failed'; then
        text="${text}The 3.0 rule engine stopped before writing code: the model check failed. Each line after that header names the entity and field and says what to write instead - change the DSL as it says and build again; do not work around it in Java. "
    fi
    # elcoreValidate writes nothing but build/elasticore/validate.md:
    # "[elcore3] validate (nothing was written): FAILED", a line per reason, then "  stale: <file>",
    # "  no longer produced: <file>" and "  conflict or error: <file>".
    if has 'validate (nothing was written): FAILED'; then
        text="${text}elcoreValidate failed and wrote nothing; build/elasticore/validate.md has the whole report. A file listed 'stale:' or 'no longer produced:', or a migration not written yet, means the generated files in the project are not what the DSL generates now: run ./gradlew compileJava (it generates) and keep what it writes, the merge base .elasticore/generated-base.zip (.elasticore/cache before ElastiCORE renamed it) included - never edit a generated file by hand to make the check pass. A model check failure or a DSL warning (-Pstrict) is fixed in the DSL; a conflict is resolved as the generator's <<<<<<< yours marks say. Then run elcoreValidate again. "
    fi
    if has '[WARN] DSL Validation Warnings'; then
        text="${text}The 2.x generator (elcore) listed DSL validation warnings and stopped the build: fix each line under that header in the DSL and build again. "
    fi
    if has 'SKIP(user-modified' || has 'Externally Modified Files'; then
        text="${text}The generator found generated files edited by hand. It skips such a file, which then no longer follows the DSL - except that the 2.x generator rewrites one with a preserved block (listed with [INGORE]), and a hand edit outside the block is gone. If you made those edits in this session, move them into the DSL or into a file you own, then restore each file by deleting it and generating again. If you did not, they are someone's deliberate edits: list them for the user and ask before restoring anything. Never use -Pforce without asking. "
    fi
    if has 'does not hold were left as they are - the cache is missing'; then
        # Merged sources the lost base does not know: they also print SKIP(no ElastiCORE header - yours).
        # ElastiCORE kept the words "the cache is missing" when it renamed the file.
        text="${text}The generator left sources alone because the merge base is missing - .elasticore/generated-base.zip, named .elasticore/cache before ElastiCORE renamed it: those are generated files whose hand edits it can no longer merge. Take the base from git (it is committed with the generated files, under either name) and build again - do not delete those files, which would lose the edits in them. "
    elif has 'SKIP(no ElastiCORE header'; then
        text="${text}The generator left a file alone because it has no ElastiCORE header, and did not write its own there. If that file was meant to be generated, it has to be deleted and generated again - ask the user if you did not create it. "
    fi
    # The merge of the 3.0 code: "  CONFLICT" and "  CONFLICT(unresolved)" after the path.
    if has '  CONFLICT'; then
        text="${text}The generator merged hand edits with the DSL's changes, and in the files listed CONFLICT both change the same lines: those files now hold <<<<<<< yours / ======= / >>>>>>> elasticore marks, and every build fails until they are gone. Resolve each place as a git conflict - usually the DSL's new code together with what the edit was for - remove the marks and build again. If you did not make those edits, show the user the places and ask. Do not delete the file or the merge base (.elasticore/generated-base.zip, or .elasticore/cache) to get past it. "
    fi
    if has 'KEPT(yours'; then
        text="${text}A file of the developer's (written once by ElastiCORE, then edited) is listed KEPT: the DSL changes it where it was edited too, so the generator left it as it is and says so on every build until the file has the DSL's change. The [elcore3] lines after the list say how many places, and name what to carry over by hand when they can - an endpoint, a constructor argument, an annotation. Make those changes in the file, keeping what was written in it, and build again. "
    fi
    # The merge base renamed by its first build that writes, a newer ElastiCORE:
    # "[elcore3] .elasticore/cache was renamed to .elasticore/generated-base.zip - commit both changes ...",
    # "... .elasticore/generated-base.zip was written, but .elasticore/cache could not be removed (...) ..." and,
    # with both files there, "[elcore3] .elasticore/cache is no longer read - ...".
    if has '.elasticore/cache was renamed to .elasticore/generated-base.zip'; then
        text="${text}ElastiCORE renamed the merge base: .elasticore/cache is deleted and .elasticore/generated-base.zip written, with .elasticore/.gitattributes and .elasticore/.gitignore beside it. Commit the delete and the new files together, in one commit; do not restore .elasticore/cache, and do not ignore or delete the new file. "
    elif has '.elasticore/cache could not be removed'; then
        text="${text}ElastiCORE wrote the merge base under its new name, .elasticore/generated-base.zip, but could not delete the old .elasticore/cache (the build line says why); the old file is no longer read. Delete .elasticore/cache, then commit that delete and the new files in .elasticore/ together; do not delete or ignore .elasticore/generated-base.zip. "
    elif has '.elasticore/cache is no longer read'; then
        text="${text}This project has both merge bases: ElastiCORE reads .elasticore/generated-base.zip and no longer reads the old .elasticore/cache, which a branch from before the rename brought back. Delete .elasticore/cache and commit the delete; keep .elasticore/generated-base.zip. If that branch is being merged right now, the env guide (9-2, git merge conflicts) says which side's base to keep. "
    fi
    if has 'SKIP(not in the cache)'; then
        text="${text}The generator left files alone that the merge base (.elasticore/generated-base.zip, or .elasticore/cache before ElastiCORE renamed it) has no record of - edited before merging was turned on, or not written by ElastiCORE - so they no longer follow the DSL. If such a file should be generated, it has to be deleted and generated again: ask the user unless you created it. If the base itself is missing, it belongs in git with the generated files - take it from there. "
    fi
    # Cleared only by a build that shows the generator ran, compiled what it
    # generated and passed, with no DSL warning but accepted ones - and no other
    # build in the same command failed. A cut or filtered output that lost a line
    # proves nothing. A build that compiled it with warnings left keeps them for
    # the reminder; a failed one makes them out of date.
    if [ "$gradle" = 0 ]; then
        :
    elif [ "$failed" = 0 ] && [ "$unreadable" = 0 ] \
        && { has '=== elcore3: ' || has 'ModelExtractor execution mode'; } \
        && has 'BUILD SUCCESSFUL' && ! has 'BUILD FAILED' \
        && { runs_gradle "$command" "$COMPILING" || printf '%s' "$output" | grep -Eq '> Task [A-Za-z0-9_:-]*:compile(Java|Kotlin)'; }; then
        if [ -z "$left" ]; then
            rm -f -- "$marker" "$warned"
        elif mkdir -p -- "$state_dir" 2>/dev/null; then
            printf '%s\n' "$left" > "$warned"
        fi
    elif [ "$failed" = 1 ] || has 'BUILD FAILED'; then
        rm -f -- "$warned"
    fi

    # The TypeScript client. The rule engine says when a build left it older than
    # the model: "... holds a generated TypeScript client made from an older model".
    if [ "$gradle" = 1 ] && has 'holds a generated TypeScript client made from an older model'; then
        text="${text}The build says the TypeScript client in src/main/ts was made from an older model: run ./gradlew elcore3ts, or set typescriptClient = true in the elasticore { } block so that every build runs it, then type-check the screens that use it. "
    fi
    # Generated again by a run that passed and read the whole model: elcore3ts in its
    # output or its task list, or a build of a project that sets typescriptClient = true.
    if [ "$gradle" = 1 ] && [ -f "$ts_client" ] && [ "$failed" = 0 ] && [ "$unreadable" = 0 ] \
        && has '=== elcore3: ' && has 'BUILD SUCCESSFUL' && ! has 'BUILD FAILED'; then
        refreshed=0
        if printf '%s' "$output" | grep -Eq '> Task [A-Za-z0-9_:-]*:elcore3ts([[:space:]]|\\|$)' || runs_gradle "$command" 'elcore3ts'; then
            refreshed=1
        else
            while IFS= read -r root; do
                [ -n "$root" ] && client_with_build "$root" && refreshed=1 && break
            done < "$ts_client"
        fi
        [ "$refreshed" = 1 ] && rm -f -- "$ts_client"
    fi
    # The screens type-checked: a check that passed, after the client was generated again.
    if [ "$checked" = 1 ]; then
        if [ -f "$ts_client" ]; then
            text="${text}This type check ran against the TypeScript client as it was before the model change - it has not been generated again since. Run ./gradlew elcore3ts (or a build, when typescriptClient = true) first, then check the screens again. "
        elif [ "$failed" = 0 ] && ! printf '%s' "$output" | grep -Eq 'error TS[0-9]|Found [0-9]+ errors?|npm ERR!|npm error|ELIFECYCLE|Command failed'; then
            # Only the screens in the folder it ran in: another screen folder may
            # still be broken by the change.
            # Where it ran cannot be told without the command's folder: all of them, as before.
            left_screens=""
            dir="$(check_dir "$command")" && left_screens="$(screens_left "$dir")"
            if [ -n "$left_screens" ]; then
                printf '%s\n' "$left_screens" > "$ts_screens"
            else
                rm -f -- "$ts_screens"
            fi
        fi
    fi
    # ElastiCORE itself may have fallen short: a compile error in a generated file, or
    # the generator failed with an exception. Suggested once a session.
    if [ "$gradle" = 1 ] && [ ! -f "$issue_noted" ]; then
        if [ "$failed" = 1 ] || has 'BUILD FAILED'; then
            out_text="$(printed)"
            broken="$(generated_errors "$out_text")"
            if [ -n "$broken" ]; then
                note "$issue_noted"
                text="${text}The compile errors are in files ElastiCORE generated ($(printf '%s\n' "$broken" | awk 'NR > 1 { printf ", " } { printf "%s", $0 }')). Check the DSL first - a type named but not declared, a DTO no dto: section defines - and fix it there, never in the generated file. $ISSUE_HINT "
            elif generator_failed "$out_text"; then
                note "$issue_noted"
                text="${text}The ElastiCORE generator itself failed with an exception, not with a model check that names what to change. Read the exception; if the YAML at fault is not obvious, make the model smaller until it passes. $ISSUE_HINT "
            fi
        fi
    fi
    [ -n "$text" ] && context "$hook_event" "$text"
    exit 0
    ;;

stop)
    json_true stop_hook_active && exit 0
    state
    # An ElastiCORE checkout: a guide changed in one language only. Said once.
    alone="$(guides_alone)"
    if [ -n "$alone" ]; then
        rm -f -- "$guides"
        list="$(printf '%s\n' "$alone" | awk -F '\t' 'NR > 1 { printf "; " } { printf "%s without %s", $1, $2 }')"
        stop_answer "In this session a guide under elasticore-guide/ changed in one language only: $list. Each guide is written twice, in English and in Korean under ko/ - change both, at the same lines (GuideTranslationTest fails when their line counts, headings or code blocks differ, and cannot see a value changed in one language only). If the user asked for one language only, say so in your answer instead."
        exit 0
    fi
    [ -f "$marker" ] || [ -f "$ts_client" ] || [ -f "$ts_screens" ] || exit 0
    text=""
    if [ ! -f "$marker" ]; then
        :
    elif [ -f "$warned" ]; then
        # Built, with warnings left - unless they have been accepted since.
        left="$(unaccepted "$(cat -- "$warned" 2>/dev/null)")"
        if [ -n "$left" ]; then
            n="$(lines_in "$left")"
            text="The ElastiCORE model changed in this session and the last Gradle build generated and compiled it: built; $n DSL warning(s) left: $(some_warnings "$left"). Building again changes nothing - fix each warning in the DSL, then build. A warning the DSL cannot fix - an ElastiCORE defect, with an issue - can be accepted instead, with the user's agreement: add its text, or a part of it, as a line of .elasticore/accepted-warnings.txt in the project, with a # comment naming the issue it waits for (the elasticore skill's references/run-and-check.md). Otherwise tell the user in your answer which warnings are left and why."
        fi
    else
        text="The ElastiCORE model changed in this session and no successful Gradle build has generated and compiled it since - a build that failed, ran in the background, only generated, or whose output was cut short or filtered does not count. Run ./gradlew compileJava - it generates first - and fix every DSL validation warning and compile error before you finish. If the user asked you not to build, say so in your answer instead."
    fi
    # A project with a TypeScript client: each step the change still needs, by name.
    screens=""
    [ -f "$ts_screens" ] && screens="$(awk 'NR > 1 { printf ", " } { printf "%s", $0 }' "$ts_screens")"
    if [ -f "$ts_client" ]; then
        [ -n "$text" ] && text="$text "
        text="${text}The TypeScript client was not regenerated since the ElastiCORE model changed: src/main/ts still has the client of the model before. Run ./gradlew elcore3ts - or a build, when the elasticore { } block sets typescriptClient = true."
        [ -n "$screens" ] && text="$text Then the screens were not type-checked against it either: run npm run check (or npx tsc --noEmit) in $screens and fix what the change broke."
    elif [ -n "$screens" ]; then
        [ -n "$text" ] && text="$text "
        text="${text}The screens were not type-checked since the TypeScript client was regenerated from the changed model: run npm run check (or npx tsc --noEmit) in $screens and fix what the change broke before you finish."
    fi
    # Remind once per DSL change; the next DSL edit sets the notes again.
    rm -f -- "$marker" "$warned" "$ts_client" "$ts_screens"
    [ -n "$text" ] && stop_answer "$text"
    exit 0
    ;;

esac
exit 0
