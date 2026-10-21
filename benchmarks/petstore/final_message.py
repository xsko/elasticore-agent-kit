"""The result event of a Claude Code stream-json run: turns, time, cost, and the final message.

usage: python final_message.py EVENTS.jsonl [MAX_CHARS]
"""
import json
import sys

sys.stdout.reconfigure(encoding="utf-8")
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
events = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
results = [e for e in events if e.get("type") == "result"]
if not results:
    print("no result event")
    sys.exit(1)
r = results[-1]
print(json.dumps({k: r.get(k) for k in ("num_turns", "duration_ms", "total_cost_usd", "is_error", "subtype")}))
print(str(r.get("result", ""))[:limit])
