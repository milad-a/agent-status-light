# Agent Status Light 🚦

A physical USB status light for **Cursor** and **Claude Code** on macOS — see what your AI agent is doing without alt-tabbing.

| Color | Meaning |
|---|---|
| 🟡 Yellow | Agent is thinking / turn in flight |
| 🔴 Red | Agent is running a tool (shell, MCP, edits) |
| 🟣 Magenta (solid) | Agent has probably asked you a question and is waiting (fires after 60s of mid-turn silence) |
| 🟢 Green | Turn finished |
| ⚫ Off | Idle (20s after green, or 180s after magenta, or laptop undocked) |

No Arduino, no soldering, no custom firmware. Off-the-shelf hardware + open-source CLI + editor hooks.

## Hardware

- **[Luxafor Flag 2](https://www.amazon.com/dp/B0DTJL1ZNY)** (~$50, USB-C). The original Luxafor Flag works identically — the Flag 2 reports the exact same USB identity (vendor `0x04d8`, product `0xf372`), so all software treats them as the same device.
- Any USB light supported by [busylight-for-humans](https://github.com/JnyJny/busylight) also works (blink(1), Blynclight, Kuando, BlinkStick...) — the HTTP layer is identical, you'd only re-test colors.
- Works plugged into the Mac directly **or** into a monitor's USB hub (see [Dock/undock survival](#dockundock-survival)).

## Architecture

```
Cursor / Claude Code
        │  lifecycle hooks (JSON on stdin)
        ▼
  light.sh  ──curl──►  busyserve (localhost:8631, launchd-managed)
        │                    │ USB HID
   watchdog timers           ▼
  (magenta / auto-off)   Luxafor Flag
                             ▲
  flag-watchdog.sh ──── kickstarts busyserve when the Flag
  (every 30s via launchd)    re-enumerates after a dock cycle
```

Key design decisions, learned the hard way:

- **A long-running server (`busyserve`), not per-event CLI calls.** The busylight CLI has ~0.5s Python startup; `PreToolUse`-style hooks block the agent. Fire-and-forget curls to a resident server are ~10ms. The server also maintains blink/effect loops so hooks can exit immediately.
- **CLI and server can't coexist.** Once busyserve acquires the HID device, `busylight on green` no longer works — use `curl` (or the aliases below). Same reason you must NOT run Luxafor's own desktop app.
- **Port 8631, not 8000.** 8000 collides with every uvicorn/FastAPI dev server you'll ever run. Bound to `127.0.0.1` so your light isn't a LAN-controllable API.
- **"Waiting for you" is inferred, not evented.** Cursor emits no hook when it asks a plan-mode question (verified by logging every event). We detect it by silence: any event resets a timer; 60s of quiet while yellow → solid magenta. False positives during long thinking stretches are the accepted trade — a wasted glance beats a timed-out question (Cursor's question timeout is undocumented and erratic; see [cursor forum](https://forum.cursor.com/t/increase-the-timeout-for-ask-questions/159806)).
- **Solid colors only, no blinking.** Office-safe. Your coworkers will thank you.

## Install

### 0. Prereqs

- macOS, `uv` (or pip), a Luxafor Flag/Flag 2 plugged in with a **data** cable (many USB-C cables are charge-only — this is the #1 "it doesn't work" cause).
- Do **not** install Luxafor's desktop app, or fully quit it if present.

Verify the Mac sees the device:

```bash
ioreg -p IOUSB -w0 | grep -i luxafor
```

Nothing? Swap cable, plug directly into the Mac, try the other port. Note: `system_profiler` can miss it right after plugging; `ioreg` is more reliable.

### 1. busylight + busyserve

```bash
uv tool install 'busylight-for-humans[webapi]'
busylight list          # expect: "0 Flag"
busylight on green      # sanity check the hardware
busylight off
```

### 2. Run the installer

```bash
git clone <this repo> && cd agent-status-light
./install.sh
```

The installer copies scripts to `~/.local/bin` and `~/.cursor/hooks`, generates the two LaunchAgents with your real paths, loads them, and verifies the server answers. Prefer doing it manually? Every step is in [`install.sh`](install.sh) — it's short and commented.

### 3. Editor hooks

**Cursor** — the installer places [`cursor/hooks.json`](cursor/hooks.json) at `~/.cursor/hooks.json` (it will NOT overwrite an existing one; merge manually in that case). Fully restart Cursor afterwards — hooks.json is read at startup. (`light.sh` itself is re-read on every event; editing it needs no restart.)

**Claude Code** — merge the `"hooks"` object from [`claude-code/settings-hooks.json`](claude-code/settings-hooks.json) into `~/.claude/settings.json`. Back it up first:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
```

### 4. Test

Ask your agent something that runs a shell command. Expected: yellow on submit → red during the tool → yellow → green → off after 20s.

Handy manual-control aliases for `~/.zshrc`:

```bash
alias light-off="curl -s 'http://localhost:8631/light/0/off' >/dev/null"
light() { curl -s "http://localhost:8631/light/0/on?color=$1" >/dev/null; }
```

Colors: any CSS3 name (`hotpink`, `teal`, ...) or hex (`0xff8800`, `%23ff8800` URL-encoded).

## Dock/undock survival

If the Flag hangs off a monitor's USB hub and you take the laptop to meetings:

- **Unplug** → most monitors cut hub power without an upstream host, so the light goes dark by itself. Test yours: set a color, unplug, look.
- **Replug** → the Flag re-enumerates as a *new* USB device; busyserve keeps writing into its stale handle — and its API still returns `"success": true` while the light does nothing. This is what `flag-watchdog.sh` fixes: every 30s it compares the Flag's IOKit registry ID against the last one seen and kickstarts busyserve when it changes.
- The watchdog deliberately tracks device **identity**, not presence. A presence-edge detector misses fast replugs and — the killer — sleeps through the entire absence when you close the lid (launchd `StartInterval` doesn't tick during sleep). Identity comparison catches re-enumeration no matter what the watchdog slept through.

Recovery is within ~30s of re-dock. Force it immediately: `launchctl kickstart -k gui/$(id -u)/com.milad.busyserve` (label per your plist).

## Quirks & troubleshooting

- **zsh eats your test curls**: `curl http://...?color=red` fails with `no matches found` — the `?` is a glob. Always quote URLs interactively. (The scripts already do.)
- **`/lights/off` and `/lights/status` return 422**: known route-ordering issue in busylight's API — `/lights/{light_id}` matches first and tries to parse `off` as an integer. Use `/light/0/off` and `/lights/0/status`.
- **Light stuck on a color**: it's dumb — it holds the last command. Check `tail /tmp/busyserve.log`, `launchctl list | grep busyserve`, and whether you're in the stale-handle state (`ioreg` shows the Flag but curls don't land → kickstart).
- **White flashes when the Flag gets power**: firmware boot behavior, happens before the host can talk to it, cannot be disabled. Live with the two-second flutter.
- **Cursor CLI (`cursor-agent`)**: only emits `beforeShellExecution`/`afterShellExecution` at time of writing — the light vocabulary shrinks accordingly. Full event set requires the IDE.
- **Cursor question timeout**: if magenta "fixes itself" back to red/yellow without you answering, the question timed out and the agent proceeded with a synthetic "user skipped" — scroll up and check what it decided without you.
- Claude Code's `Notification` hook has real payloads: `notification_type` is `permission_prompt` or `idle_prompt` — matchable, so Claude Code gets precise "needs approval" vs "idle" handling instead of silence-inference. See [`claude-code/settings-hooks.json`](claude-code/settings-hooks.json).

## Repo layout

```
install.sh                        one-shot setup (idempotent-ish, path-aware)
scripts/light.sh                  hook target: sets color + watchdog timers
scripts/flag-watchdog.sh          re-enumeration detector → busyserve kickstart
scripts/log-hook.sh               optional: log raw hook payloads for debugging
cursor/hooks.json                 Cursor hook config (template; installer fixes paths)
claude-code/settings-hooks.json   hooks object to merge into ~/.claude/settings.json
launchagents/*.plist.template     busyserve + watchdog LaunchAgents (installer fills paths)
```

## Tuning

All timers live in `scripts/light.sh` (Cursor path):

| Timer | Default | Meaning |
|---|---|---|
| `sleep 60` (magenta branch) | 60s | mid-turn silence before "probably waiting on you" |
| `sleep 180` (after magenta) | 180s | magenta lifetime before giving up → off |
| `sleep 20` (green branch) | 20s | idle-off after a finished turn |

## Credits

Inspired by [agent-light](https://github.com/eternityspring/agent-light) (the Arduino traffic-light version that started this) — this repo is the no-soldering remake with dock-cycle self-healing.
