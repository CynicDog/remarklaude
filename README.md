# remarklaude

Talk to [Claude Code](https://docs.claude.com/claude-code) from a **reMarkable 2**, by typing — not drawing.

There are already great projects that turn the reMarkable's e-ink canvas into
a handwriting/vision-LLM interface (see
[ghostwriter](https://github.com/awwaiid/ghostwriter)). This is the other
kind: you open a real terminal on the device and get a plain, typed
conversation with Claude — the same experience as running `claude` in any
other terminal, just on an e-ink screen.

This README is split in two:

- **Part 1** is the minimum path that actually gets you from a stock
  reMarkable 2 to a live `claude` session on its screen. Every step here was
  run and confirmed working on a reMarkable 2, firmware `3.24.0.149`.
- **Part 2** is optional polish — mainly killing the password prompt.

An earlier version of this README recommended Toltec, `fingerterm`/`reterm`,
and `opkg`. That was wrong for current firmware and is why this got rewritten
— see the note in Part 1, step 3.

## Part 1 — Minimum connection

### 1. Find your Mac's SSH address

**System Settings → General → Sharing → Remote Login** (turn it on if it
isn't). It shows you a line like:

```
To log in to this computer remotely, type "ssh eunsang@192.168.0.85"
```

That username and IP are your host machine's address — you'll use it below.
(The IP is DHCP-assigned and can change later; if `ssh` stops connecting
after a while, re-check this screen.)

### 2. SSH into the reMarkable

First connect over USB (WiFi SSH is off by default):

```sh
ssh root@10.11.99.1
```

The password is on-device: **Settings → Help → Copyright and licenses →
GPLv3 Compliance** (on some older firmware it's under **Settings → About**
instead — check whichever menu exists on your device).

Once connected, enable SSH over WiFi so the USB cable isn't needed going
forward:

```sh
rm-ssh-over-wlan on
```

After that, reconnect over WiFi: `ssh root@remarkable.local` (or its LAN IP
from your router's client list).

### 3. Install Vellum — not Toltec

Toltec, the older reMarkable package manager, only supports OS builds up to
`3.3.2.1666` and can **soft-brick devices on newer firmware**. If your
firmware is newer than that (check **Settings → General → Software
version**), use **Vellum** instead — that's what the rest of this guide
uses.

Copy the install command straight from
[vellum-dev/vellum-cli](https://github.com/vellum-dev/vellum-cli)'s
Installation section and run it on the reMarkable. It looks like this (copy
the real one from the repo — it includes a checksum check, and hardcoding it
here would just go stale on the next release):

```sh
wget --no-check-certificate -O bootstrap.sh <url-from-the-repo>
sha256sum -c <checksum-line-from-the-repo> && bash bootstrap.sh
exec bash --login
```

### 4. Install a terminal (literm) and a way to open it (tripletap)

On current firmware, this combination is the one that actually works:

```sh
vellum add literm
vellum add tripletap
```

- `literm` is a Qt-based terminal that loads itself into `xochitl` (the
  reMarkable's own UI process) via a framework called **xovi**. A simpler,
  standalone framebuffer terminal (`yaft`) also exists, but it needs a
  compatibility shim (`rm2fb`) that Vellum doesn't currently package — dead
  end for now, hence `literm`.
- `tripletap` binds a triple-press of the power button to opening
  **AppLoad**, the on-device launcher that surfaces `literm` as an app named
  "Terminal." Without `tripletap` (or some other AppLoad trigger), `literm`
  installs fine but you have no way to actually open it.

If `vellum add literm` complains about an `appload` version conflict, it's
because the compatible `appload` version is gated by your OS version —
don't fight it by deleting/reinstalling packages; it should just resolve
cleanly on a fresh install.

Now activate xovi:

```sh
xovi/rebuild_hashtable
xovi/start
```

The device will show an **"Update installed, Restart"** dialog — this is
expected (`xovi/start` reuses the OS's own update/restart mechanism to load
the mods). Tap **Restart**.

### 5. Open the terminal and connect

On the physical device, **triple-press the power button**. AppLoad's menu
appears — tap **Terminal**.

Inside that terminal, SSH into your Mac and run `claude` directly:

```sh
ssh -t eunsang@192.168.0.85 claude --ax-screen-reader
```

`--ax-screen-reader` gives flat text with no decorative borders or
animations — much better suited to e-ink's slow refresh than the default
interactive UI, which redraws constantly.

You'll be asked for your Mac account password every time (Part 2 fixes
that). If `claude` reports it isn't logged in, see the note below — that's
expected the first time and isn't a broken setup.

**First-time Claude auth over SSH:** Claude Code's login is normally tied to
your Mac's GUI session/Keychain, which an SSH-spawned process doesn't always
have access to — so you may need to authenticate again even if `claude` is
already logged in when you run it locally. Either run `/login` right there
in the SSH session (it supports pasting a code from a URL you open on any
device, so it works fine headless), or run `claude setup-token` once
**locally** on the Mac (normal Terminal window, not over SSH) to create a
long-lived token that doesn't depend on Keychain at all.

**If `claude: command not found` over SSH:** non-interactive SSH sessions
(what `ssh host command` uses) only source `~/.zshenv` for zsh, not
`.zshrc`/`.zprofile` — so if `claude`'s install directory is only added to
`PATH` in one of those, it won't resolve. Either add it to `~/.zshenv`
instead, or use `claude`'s full path (`which claude` locally to find it).

That's the whole minimum path: SSH to the reMarkable once to set it up →
triple-tap → Terminal → one `ssh` command → real `claude`.

## Part 2 — Advanced: stop typing your password

Every connection from the reMarkable currently prompts for your Mac's
account password. Set up SSH key auth once to skip that.

From inside the reMarkable's terminal (the "Terminal" app from Part 1):

```sh
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
ssh-copy-id eunsang@192.168.0.85
# if ssh-copy-id isn't available on-device:
cat ~/.ssh/id_ed25519.pub | ssh eunsang@192.168.0.85 \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

This prompts for your Mac password one last time, to install the key. After
that, this connects with no password:

```sh
ssh -t eunsang@192.168.0.85 claude --ax-screen-reader
```

### Optional: a stable address (so the IP doesn't keep changing on you)

`192.168.0.85` is a DHCP-assigned LAN IP — it can and will change if the Mac
joins a different network, reconnects, or you move to a hotspot. Two ways to
stop caring about that:

**Quick, same-network-only fix — use the `.local` hostname instead of the
IP.** Every Mac advertises one via mDNS/Bonjour; find yours at **System
Settings → General → Sharing**, shown at the top (e.g.
`Marks-Mac-mini.local`). Substitute it for the IP anywhere in this guide:

```sh
ssh -t eunsang@Marks-Mac-mini.local claude --ax-screen-reader
```

This still requires the reMarkable and the Mac to be on the *same* network
at the time (mDNS doesn't route across networks) — it just means you don't
have to look up a fresh IP every time that network changes. It can
occasionally be flaky depending on the router/network.

**Robust fix, works across any network — Tailscale.** It gives both devices
a stable address that doesn't change no matter what physical network either
one is on (home WiFi, a hotspot, somewhere else entirely) — closer to a
private always-on VPN between just your own devices than a LAN trick.

1. Install the [Tailscale](https://tailscale.com/download) app on the Mac
   and sign in.
2. On the reMarkable: `vellum add tailscale`, then follow its on-screen
   instructions to authenticate (it'll print a URL to open on any device).
3. Once both are connected, use the Mac's Tailscale name (shown in the
   Tailscale admin console / menu bar app, something like
   `mac-mini.<your-tailnet>.ts.net`) or its `100.x.x.x` Tailscale IP instead
   of the LAN IP — same substitution as above, everywhere in this guide.

Either way, once you've picked a stable address, use it in place of the IP
everywhere in this guide and you won't need to touch it again.

### Optional: an e-ink-tuned wrapper, if streaming flickers

Running `claude` interactively streams its response token-by-token, which
may cause visible flicker/ghosting on e-ink even with `--ax-screen-reader`
(untested on-device — try the plain command first and judge for yourself).
If it's rough, the fix is a small host-side wrapper that makes one
`claude -p --ax-screen-reader` call per message and prints a single clean
block of text back instead of streaming — not currently part of this repo,
but straightforward to add if the plain interactive command turns out to be
unusable on the actual display.

## Open ends

- `yaft` + `rm2fb` (a simpler, standalone terminal path) is blocked because
  Vellum doesn't package `rm2fb` yet — worth revisiting if that changes.
- Whether `--ax-screen-reader`'s streaming actually flickers on this display
  hasn't been directly observed yet.
- `reterm` (Type Folio-oriented terminal) hasn't been evaluated on this
  setup.
- `mosh` instead of plain `ssh` might handle WiFi drops more gracefully than
  a hung SSH session — untested.
