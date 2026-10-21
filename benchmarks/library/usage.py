"""Token and context use of an experiment arm, from its events.jsonl.

  python usage.py LABEL EVENTS.jsonl [LABEL EVENTS.jsonl ...]

Claude Code (stream-json): the totals come from the result events (one per session; a run whose
background command finished after the first session has two) - the assistant events never carry
the final output count. Calls and the peak prompt come from the assistant messages (one per id).
opencode: one API call per step_finish; tokens.input/output/reasoning/cache.read/cache.write.
Codex (codex exec --json): turn.completed usage - input_tokens (cached_input_tokens of them from
the cache, cache_write_input_tokens written), output_tokens (reasoning_output_tokens of them) - one
total for the whole turn. The per-call numbers come from the session rollout that Codex writes to
~/.codex/sessions/YYYY/MM/DD/rollout-*-<thread_id>.jsonl: every token_count event_msg carries
last_token_usage (that API call) and total_token_usage. Verified on Codex CLI 0.163.0, 2026-10-21.
"context processed" = every prompt token the model read over the run (fresh + cache read + cache
write); "peak context" = the largest single prompt, i.e. how full the window got.
"""
import json
import os
import sys


def load(path):
    out = []
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line:
            try:
                out.append(json.loads(line))
            except Exception:
                pass
    return out


def claude(ev):
    per_msg, order, cost, totals = {}, [], 0.0, [0, 0, 0, 0]
    for e in ev:
        if e.get("type") == "assistant":
            m = e.get("message", {})
            u = m.get("usage")
            if not u:
                continue
            if m.get("id") not in per_msg:
                order.append(m.get("id"))
            per_msg[m.get("id")] = (u.get("input_tokens", 0), u.get("cache_read_input_tokens", 0),
                                    u.get("cache_creation_input_tokens", 0))
        elif e.get("type") == "result":
            cost = e.get("total_cost_usd") or cost  # cumulative over the sessions of the run
            u = e.get("usage") or {}
            for i, k in enumerate(("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens", "output_tokens")):
                totals[i] += u.get(k, 0)
    peak = max((sum(per_msg[i]) for i in order), default=0)
    return totals, cost, len(order), peak


def opencode(ev):
    totals, cost, n, peak = [0, 0, 0, 0], 0.0, 0, 0
    for e in ev:
        if e.get("type") == "step_finish":
            t = (e.get("part") or {}).get("tokens") or {}
            c = t.get("cache") or {}
            row = (t.get("input", 0), c.get("read", 0), c.get("write", 0), t.get("output", 0) + t.get("reasoning", 0))
            totals = [a + b for a, b in zip(totals, row)]
            peak = max(peak, row[0] + row[1] + row[2])
            n += 1
            cost += (e.get("part") or {}).get("cost") or 0
    return totals, cost, n, peak


def codex_row(u):
    cached, written = u.get("cached_input_tokens", 0), u.get("cache_write_input_tokens", 0)
    return (u.get("input_tokens", 0) - cached - written, cached, written, u.get("output_tokens", 0))


def codex(ev):
    totals, n, peak = [0, 0, 0, 0], 0, 0
    thread = next((e.get("thread_id") for e in ev if e.get("type") == "thread.started"), None)
    rollout = None
    if thread:
        for d, _, files in os.walk(os.path.expanduser("~/.codex/sessions")):
            for f in files:
                if f.endswith(thread + ".jsonl"):
                    rollout = os.path.join(d, f)
    if rollout:
        for e in load(rollout):
            p = e.get("payload") or {}
            if e.get("type") == "event_msg" and p.get("type") == "token_count" and (p.get("info") or {}).get("last_token_usage"):
                row = codex_row(p["info"]["last_token_usage"])
                totals = [a + b for a, b in zip(totals, row)]
                peak = max(peak, row[0] + row[1] + row[2])
                n += 1
        return totals, None, n, peak
    for e in ev:  # no rollout found: the turn total only (one row, peak unknown)
        u = e.get("usage") if e.get("type") == "turn.completed" else None
        if u:
            row = codex_row(u)
            totals = [a + b for a, b in zip(totals, row)]
            n += 1
    return totals, None, n, 0


def main():
    args = sys.argv[1:]
    print("%-34s %6s %12s %12s %10s %10s %13s %10s" % ("arm", "calls", "fresh input", "cache read", "cache wr", "output", "ctx processed", "peak ctx"))
    for label, path in zip(args[::2], args[1::2]):
        ev = load(path)
        kinds = {e.get("type") for e in ev}
        if "assistant" in kinds and "result" in kinds:
            totals, cost, n, peak = claude(ev)
        elif "step_finish" in kinds:
            totals, cost, n, peak = opencode(ev)
        else:
            totals, cost, n, peak = codex(ev)
        fresh, read, write, out = totals
        print("%-34s %6d %12s %12s %10s %10s %13s %10s%s" % (
            label, n, f"{fresh:,}", f"{read:,}", f"{write:,}", f"{out:,}", f"{fresh + read + write:,}", f"{peak:,}",
            "  $%.2f" % cost if cost else ""))


main()
