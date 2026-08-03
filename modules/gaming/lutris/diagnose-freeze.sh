#!/usr/bin/env bash
# Capture the state of a frozen Pinball Science, non-destructively.
# Run this the moment it wedges, BEFORE killing it.
#
#   ./diagnose-freeze.sh [output-dir]
#
# Do NOT attach winedbg — it kills the process. Everything here is read-only
# except the brief strace attach, which detaches cleanly.
set -uo pipefail
OUT="${1:-$HOME/pinball-freeze-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"

PID=$(pgrep -x 'mscience.exe' | head -1)
if [ -z "$PID" ]; then
	echo "no mscience.exe running" >&2
	exit 1
fi
echo "capturing pid $PID -> $OUT"

# 1. Spinning or blocked? R + high CPU = spin; all-S on futex = deadlock.
{
	echo "=== top ==="
	top -b -n 2 -d 1 -p "$PID" 2>/dev/null | tail -6
	echo "=== status ==="
	grep -E "^(State|Threads|VmRSS|voluntary|nonvoluntary)" "/proc/$PID/status"
	echo "=== per-thread name/state/wchan/cputime ==="
	# Parse AFTER the last ')': the comm field can contain spaces and parens
	# (e.g. "[vkcf] Analysis"), which shifts every positional field.
	for t in /proc/"$PID"/task/*; do
		tid=$(basename "$t")
		rest=$(sed 's/.*) //' "$t/stat" 2>/dev/null)
		printf "%-8s %-3s %-22s %-24s %s\n" "$tid" \
			"$(echo "$rest" | awk '{print $1}')" \
			"$(cat "$t/comm" 2>/dev/null)" \
			"$(cat "$t/wchan" 2>/dev/null)" \
			"$(echo "$rest" | awk '{print $12+$13}')"
	done
} >"$OUT/threads.txt" 2>&1

# 2. What is it looping on? A PeekMessage+clock() spin shows as
#    read/write (wineserver IPC) + getrusage (clock) + sched_yield.
#    Needs ptrace: yama ptrace_scope=1 only permits attaching to descendants,
#    so this works when the game was launched from this shell and otherwise
#    needs `sudo sysctl kernel.yama.ptrace_scope=0`. Fall back to sampling
#    /proc, which needs the same permission but is worth trying.
if timeout 6 strace -c -p "$PID" >"$OUT/syscalls.txt" 2>&1 &&
	! grep -q "Operation not permitted" "$OUT/syscalls.txt"; then
	:
else
	{
		echo "strace attach denied (yama ptrace_scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null))."
		echo "To profile the hot loop: sudo sysctl kernel.yama.ptrace_scope=0"
		echo "--- /proc syscall samples (empty also means permission denied) ---"
		for _ in $(seq 1 15); do
			awk '{print $1}' "/proc/$PID/task/$PID/syscall" 2>/dev/null
			python3 -c "import time;time.sleep(0.1)"
		done | sort | uniq -c | sort -rn
	} >>"$OUT/syscalls.txt" 2>&1
fi

# 3. Which assets are open — the .wav/.mov held at freeze time is the clue.
ls -l "/proc/$PID/fd" >"$OUT/fds.txt" 2>&1
grep -oE "$HOME/Games/pinball-science/[^ ]*" "$OUT/fds.txt" | sort -u >"$OUT/open-assets.txt"

# 4. Audio actually alive? (pactl is NOT installed here — use wpctl/pw-dump.)
{
	echo "=== wpctl ==="
	wpctl status 2>/dev/null | sed -n '/Audio/,/Video/p'
	echo "=== streams for this pid ==="
	pw-dump 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit()
for o in d:
    p=(o.get('info') or {}).get('props') or {}
    if p.get('media.class','').startswith('Stream'):
        print(p.get('application.process.id'), p.get('application.name'), (o.get('info') or {}).get('state'))
"
} >"$OUT/audio.txt" 2>&1

# 5. Where is the spinning thread, in code? This is the decisive artefact.
#    Use gdb, which attaches and DETACHES cleanly. Do NOT use winedbg: it
#    terminates the process on attach, destroying the very state you want.
#    Needs kernel.yama.ptrace_scope=0 (see note above).
if command -v gdb >/dev/null 2>&1; then
	GDB=(gdb)
else
	GDB=(nix run nixpkgs#gdb --)
fi
timeout 120 "${GDB[@]}" -p "$PID" -batch \
	-ex "set pagination off" \
	-ex "thread apply all bt 15" >"$OUT/backtrace.txt" 2>&1 ||
	echo "gdb backtrace failed (is kernel.yama.ptrace_scope 0?)" >>"$OUT/backtrace.txt"

echo
echo "captured:"
echo "  threads.txt      spinning vs blocked"
echo "  syscalls.txt     what the hot loop is doing"
echo "  backtrace.txt    WHERE it is spinning (most useful)"
echo "  open-assets.txt  which .wav/.mov was in flight"
echo "  audio.txt        whether the stream was alive"
grep -E "^(State|Threads|voluntary)" "$OUT/threads.txt" 2>/dev/null | sed 's/^/  /'
echo "assets held open:"
sed 's/^/  /' "$OUT/open-assets.txt" 2>/dev/null | head
