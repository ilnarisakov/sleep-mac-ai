# Sleep Mac AI

A tiny macOS menu bar app that keeps your MacBook awake with the lid closed — for long AI agent runs, builds, or downloads.

🇷🇺 [Инструкция на русском](README_RU.md)

![menu bar app](logo.jpg)

## Why

`caffeinate` does **not** prevent sleep when you close the lid. Only `pmset -a disablesleep 1` does. This app is a one-click switch for that flag, so you don't have to remember the command — or to turn it back off.

- **🌙 Normal mode** — stock macOS behaviour, sleeps on lid close
- **⚡ AI mode** — never sleeps, lid open or closed

## Install

**From the DMG** — download `AI Sleep.dmg` from [Releases](../../releases), open it, drag the app to Applications.

First launch: the app is signed with an ad-hoc signature, so macOS will warn about an unidentified developer. Right-click the app → **Open** → **Open**. Once only.

**From source** — requires Xcode Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/ilnarisakov/sleep-mac-ai.git
cd sleep-mac-ai
./build.sh                 # builds "AI Sleep.app"
cp -R "AI Sleep.app" /Applications/
```

## No-password toggling (recommended)

`pmset` needs root. Without setup, every toggle shows a password prompt. Run once:

```bash
./nopasswd.sh
```

It installs `/etc/sudoers.d/aimode` allowing exactly two commands without a password:

```
pmset -a disablesleep 1
pmset -a disablesleep 0
```

Nothing else. To undo: `sudo rm /etc/sudoers.d/aimode`.

## Start at login

System Settings → General → Login Items & Extensions → **Open at Login** → **+** → `AI Sleep`.

## Language

Menu → **Language** → System / English / Русский. Follows your macOS language by default.

## Resource usage

| Metric | Value |
|---|---|
| Memory | ~15 MB |
| Idle CPU | 0.0 % |
| Timers / polling | none |

The app does nothing in the background — it reads `pmset -g` only when you open the menu.

## Build a DMG

```bash
./build-dmg.sh
```

## Tests

```bash
./test.sh    # verifies the pmset parser matches the real flag
```

## Caveat

AI mode drains the battery with the lid closed — the machine stays fully awake. Switch back to Normal mode when you're done, or keep it plugged in.

## License

MIT
