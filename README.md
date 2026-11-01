# Nocturne Terminal

A calm, near black terminal look for Windows Terminal, matching the [Nocturne Obsidian theme](https://github.com/dreyssechris/Nocturne).

## What you get

- **Nocturne color scheme:** background `#0B0D0E`, mint cursor `#57B083`, slate blue `#6E93A8`, muted accents and dimmed text that stays readable
- **Alternatives** to switch to anytime: Kanagawa Wave, Tokyo Night, Catppuccin Mocha
- **Dark tab bar**, no acrylic, no background image
- **JetBrainsMono Nerd Font** at 11pt with line height 1.25 and ClearType, so prompt icons (oh-my-posh) keep working
- **Bell notifications:** when a tab rings the bell, the taskbar flashes and the tab shows a bell icon. Handy with Claude Code: `/config` → Notifications → Terminal Bell

## Quick setup

Open PowerShell on the new machine (no admin needed) and run this one line:

```powershell
irm https://raw.githubusercontent.com/dreyssechris/nocturne-terminal/main/install.ps1 | iex
```

That's it. Windows Terminal reloads on its own; restart it once if the font does not show up yet.
Works with Windows PowerShell 5.1 and PowerShell 7, no git and no script file needed.

**With options** (for example when a company proxy blocks the font download):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/dreyssechris/nocturne-terminal/main/install.ps1))) -SkipFont -WithOhMyPosh
```

## Install from a clone

```powershell
git clone https://github.com/dreyssechris/nocturne-terminal.git
cd nocturne-terminal
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### Options

| Flag | Effect |
|---|---|
| `-SkipFont` | Do not download and install the font |
| `-WithOhMyPosh` | Also copy the oh-my-posh prompt theme (`oh-my-posh/chris-simple.omp.json`) |
| `-SettingsPath <file>` | Patch a specific `settings.json` instead of auto detecting it |

### What the script changes

- Installs JetBrainsMono Nerd Font for the current user
- In every Windows Terminal `settings.json` it finds (stable, preview, unpackaged):
  - writes a backup `settings.json.bak-<timestamp>` next to it
  - adds or replaces the color schemes and the `Nocturne` tab theme
  - sets font, colors, padding and bell style in `profiles.defaults`
  - removes the background image settings from `profiles.defaults`
- Your profiles, keybindings and other settings stay untouched

## Switching schemes

`Ctrl+,` → Defaults → Appearance → Color scheme. Windows Terminal shows a live preview.

## Other terminals

- **Orca:** Settings → Terminal → import the Ghostty config `ghostty/nocturne`, or enter the colors from that file under terminal color overrides
- **Ghostty:** copy `ghostty/nocturne` into your Ghostty themes folder and set `theme = nocturne`

## Undo

Copy the `settings.json.bak-<timestamp>` file back over `settings.json`.
