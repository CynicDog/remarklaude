# remarklaude

Talk to [Claude Code](https://docs.claude.com/claude-code) from a **reMarkable 2**, by typing — not drawing.

There are already great projects that turn the reMarkable's e-ink canvas into a
handwriting/vision-LLM interface (see
[ghostwriter](https://github.com/awwaiid/ghostwriter)). This is the other kind:
you open a real terminal on the device and get a plain, scrolling, typed
conversation with Claude — the same experience as running `claude` in any
other terminal, just on an e-ink screen.

## How it works

You run a terminal app (fingerterm / ReTerm) on the reMarkable, which SSHes
into your host machine and launches `bin/remarklaude` — a small wrapper
around the `claude` CLI. Each message you type is sent over that SSH
connection, and the wrapper prints back a single block of plain text.

The Claude Code CLI's normal interactive mode is a live-redrawing TUI
(spinners, animated tool-call boxes) — great in a fast terminal, rough on
e-ink's slow refresh. So instead of running `claude` interactively over SSH,
this repo ships **`bin/remarklaude`**: a small wrapper that reads one line of
input at a time and makes exactly one `claude -p --ax-screen-reader` call per
message, printing a single clean block of plain text back. No mid-response
redraws, no ghosting. Line editing (backspace, etc.) happens locally in the
reMarkable's terminal app over the normal SSH pty, same as any other command
line.

Each launch of `remarklaude` keeps one continuous conversation (via
`--session-id` / `--resume`), so context carries across messages until you
run `/new`.

## Prerequisites

- A reMarkable 2 on the same Wi-Fi network as your host machine.
- SSH access to the reMarkable (enabled by default — find the root password
  under **Settings → About → Copyright and licenses → GPLv3 Compliance** on
  the device, or **Settings → Help → Copyrights and licenses** on newer
  firmware).
- [Vellum](https://github.com/vellum-dev/vellum-cli) installed on the
  reMarkable, for a terminal emulator. Vellum is the current
  package manager for the reMarkable — **not Toltec**: Toltec only supports
  OS builds up to `3.3.2.1666` and can soft-brick newer devices. Check
  `vellum-cli`'s README for the exact bootstrap command (it changes with
  releases, so it's not worth hard-coding here) — copy it from the source
  yourself rather than from a paraphrase, since it includes a checksum
  verification step that has to be exact.
- The host machine has the `claude` CLI installed and already authenticated
  (if you're reading this, yours already is).

## 1. Host setup (your Mac)

1. Enable SSH: **System Settings → General → Sharing → Remote Login** (on).
2. Note how the reMarkable will reach this Mac — either its `.local`
   hostname (**System Settings → General → Sharing**, shown at the top, e.g.
   `Marks-MacBook-Pro.local`) or its LAN IP (`ipconfig getifaddr en0`).
3. Put this repo's `bin/remarklaude` on your `PATH`, e.g.:
   ```sh
   ln -s "$(pwd)/bin/remarklaude" /usr/local/bin/remarklaude
   # or, if you use ~/bin and it's already on PATH:
   ln -s "$(pwd)/bin/remarklaude" ~/bin/remarklaude
   ```
   (It must be reachable by name over a non-interactive SSH session, so
   `~/bin` or `/usr/local/bin` — not a path that only exists in your
   interactive shell's `PATH`.)
4. Set up key-based SSH auth so connecting from the reMarkable doesn't
   require typing a password on its on-screen keyboard (see step 3 below —
   the key is generated **on the reMarkable** and copied **to** the Mac).

## 2. reMarkable setup

1. Check which firmware version you're on (**Settings → General → Software
   version**), then confirm Toltec vs. Vellum compatibility for that version
   before installing anything — Toltec caps out around `3.3.2.1666`; newer
   firmware needs Vellum. Bootstrap whichever applies (Vellum:
   [vellum-cli](https://github.com/vellum-dev/vellum-cli)).
2. Install a terminal emulator:
   - **No Type Folio (touch keyboard)** — recommended to start:
     ```sh
     vellum add fingerterm
     ```
   - **With a Type Folio** (landscape, physical keyboard):
     ```sh
     vellum add reterm
     ```
   Both are available as Vellum packages; you can install both and try each.
3. Open the terminal app on the device and generate an SSH key, then copy it
   to the Mac:
   ```sh
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   ssh-copy-id yourname@yourmac.local
   # if ssh-copy-id isn't available:
   cat ~/.ssh/id_ed25519.pub | ssh yourname@yourmac.local 'cat >> ~/.ssh/authorized_keys'
   ```
4. (Optional) Copy `remarkable/connect.sh` from this repo onto the device
   and edit `REMARKLAUDE_HOST` at the top, so connecting is one command:
   ```sh
   scp remarkable/connect.sh root@10.11.99.1:/home/root/connect-claude.sh
   # on the reMarkable:
   chmod +x connect-claude.sh
   ```

## 3. Connect & use

From the terminal app on the reMarkable:

```sh
ssh -t yourname@yourmac.local remarklaude
# or, if you copied it over:
./connect-claude.sh
```

You'll see:

```
remarklaude — Claude Code over e-ink
Type a message and press Enter. /help for commands.

you>
```

Type a message, press Enter, and wait — there's deliberately no spinner or
live progress (that's what causes e-ink flicker), so a short pause before
`claude>` prints its answer is expected, especially for anything that needs
tool use.

Commands:
- `/new` — start a fresh conversation (drops prior context)
- `/help` — show available commands
- `/exit` or `/quit` (or Ctrl-D) — end the session

Tips for a good e-ink experience:
- Keep prompts short and specific; long back-and-forth is more pleasant than
  one giant message.
- This wrapper is intentionally "one message in, one block of text out" —
  don't expect streaming.
- `REMARKLAUDE_MODEL=sonnet ssh -t yourmac.local remarklaude` (set the env
  var host-side, e.g. in `~/.ssh/environment` with `PermitUserEnvironment`,
  or just hardcode a default in the script) lets you pin a model.

## Troubleshooting

- **`ssh: Could not resolve hostname`** — `.local` mDNS resolution can be
  flaky; use the Mac's LAN IP instead (`ipconfig getifaddr en0`).
- **Prompted for a password every time** — the SSH key wasn't copied
  correctly, or the Mac's `authorized_keys` permissions are wrong (should be
  `600`, and `~/.ssh` should be `700`).
- **`remarklaude: command not found` over SSH** — non-interactive SSH
  sessions use a minimal `PATH`; make sure the symlink is in `/usr/local/bin`
  or `~/bin` with `~/.bashrc`/`~/.zprofile` exporting that PATH for
  non-interactive shells, or just reference the full path in `connect.sh`.
- **Nothing happens / long hang** — check Wi-Fi on both ends; the reMarkable
  drops Wi-Fi aggressively to save battery.

## Later ideas

- Switch to `reterm` + Type Folio once you have one, for a landscape
  physical-keyboard experience.
- A launcher entry (via Vellum, if/when one offers this) so opening a
  notebook-like icon on the reMarkable home screen launches the terminal
  straight into `remarklaude`, one tap instead of typing a command.
- `mosh` instead of plain `ssh` for a connection that survives Wi-Fi drops
  without hanging.
