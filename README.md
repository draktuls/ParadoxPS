# PowerShell Terminal Profile

A Windows Terminal profile with an Oh My Posh prompt, Git branch information, four color palettes, a shortcut guide, and optional dummy prompts.

Requires Windows, PowerShell **7.4+**, and Windows Terminal **1.22+**. Your configured background, default text, and error colors are preserved.

## Install

1. Install any missing prerequisites:

   ```powershell
   winget install --id Microsoft.WindowsTerminal -e
   winget install --id Microsoft.PowerShell -e
   winget install --id JanDeDobbeleer.OhMyPosh -e
   winget install --id Git.Git -e
   ```

2. Open a **PowerShell 7** tab in Windows Terminal. Install the font:

   ```powershell
   oh-my-posh font install meslo
   ```

3. Download or clone this repository into a permanent folder. Open PowerShell in that folder and run:

   ```powershell
   .\Install-Profile.ps1
   ```

4. Choose **PowerShell Custom** from Terminal's profile dropdown. In **Settings > PowerShell Custom > Appearance > Font face**, select the installed **Meslo Nerd Font** and save.

The installer adds a separate profile. It does not modify your normal PowerShell startup script or change Terminal's default profile. Keep the repository folder in place: the installed profile loads its scripts directly. No Administrator session is required.

### Install pane and tab shortcuts

To also install the Terminal shortcuts listed below:

```powershell
.\Install-Profile.ps1 -InstallTerminalKeybindings
```

Terminal shortcuts apply to **all Terminal profiles** and replace conflicting bindings. Without this option, existing Terminal shortcuts remain unchanged. Ctrl+B, Ctrl+H and Ctrl+E are PowerShell bindings loaded by the custom profile itself.

### Installation options

```powershell
# Choose a display name; rerunning updates the same custom profile.
.\Install-Profile.ps1 -ProfileName 'Development Shell'

# Specify the active settings file if automatic detection fails or finds multiple editions.
.\Install-Profile.ps1 -TerminalSettingsPath 'C:\path\to\settings.json'

# Optional: load into normal PowerShell sessions instead of a separate Terminal profile.
.\Install-Profile.ps1 -CurrentUserProfile
```

Options can be combined. `-SeparateProfile` remains supported and has the same behavior as the default installation. The installer backs up settings and any existing startup script before changing them. Settings are parsed and saved as JSON; comments and formatting are not retained.

If scripts are blocked, review the files and run `Unblock-File .\*.ps1`. On a personal machine where policy permits, `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` allows local scripts. Organization policies may override this setting.

## Usage

### Colors

Press **Ctrl+B** to cycle **Default > Purple > Orange > Green > Default**.

| Palette | Accents | Elevated username |
| --- | --- | --- |
| Default | Light blue | Bright orange |
| Purple | Purple shades | Teal |
| Orange | Orange shades | Blue |
| Green | Green shades | Pink |

Colors apply to the prompt, file listings, command syntax, predictions, headings, progress, and Terminal accent colors. Background, default text, neutral black/white, and error reds remain configured by your Terminal settings. Applications with their own RGB colors may retain them.

The selected palette is shared across this Windows Terminal process. New custom tabs and panes inherit it; existing ones update at their next prompt. A fresh Terminal process starts with Default. If process detection is unavailable, the selection stays local to the shell.

### Censor mode

Press **Ctrl+H** to cycle these dummy prompts, then return to the normal Oh My Posh prompt:

```text
user@host:/tmp$      Colored Bash/Zsh style
[user@server tmp]$   Linux server style
user@Mac tmp %      macOS style
PS C:\>             PowerShell style
C:\>                Command Prompt style
>                   Minimal
OFF                 Normal prompt
```

A banner announces each change. Censor mode is local to the current PowerShell session. It changes the prompt only: it does not redact commands, output, scrollback, titles, or directory metadata, and the shell remains PowerShell.

### Shortcuts

| Shortcut | Action |
| --- | --- |
| Ctrl+B | Cycle colors |
| Ctrl+H | Cycle censor mode |
| Ctrl+E | Open Explorer in the current folder |
| Tab / Ctrl+Space | Open the completion menu |
| F1 | Show help for the current PowerShell command |
| F2 | Switch between inline and list predictions when enabled |
| Ctrl+L | Clear the screen |
| Ctrl+W | Delete the word before the cursor |
| Ctrl+R / Ctrl+S | Search older / newer history matches |
| `cd -` / `cd +` | Move backward / forward through location history |
| Ctrl+Shift+F | Search terminal scrollback (Windows Terminal default) |
| Ctrl+Shift+P | Open the Terminal command palette (Windows Terminal default) |
| Ctrl+Shift+T | New tab in the current directory * |
| Alt+Shift+V / Alt+Shift+H | Split side by side / top and bottom * |
| Alt+Shift+D | Split automatically * |
| Alt+Arrow | Focus another pane * |
| Alt+Shift+Arrow | Resize pane * |
| Alt+Shift+Z | Zoom pane / restore * |
| Ctrl+D / Ctrl+Shift+W | Close pane or tab * |

`*` Installed by `-InstallTerminalKeybindings`. Ctrl+D can close a pane even while a command is running. Shell shortcuts work at the PowerShell prompt; applications can handle keys differently.

For history search, press **Ctrl+R**, type `git`, then press **Ctrl+R** repeatedly for older matches or **Ctrl+S** for newer ones. **Right Arrow** keeps a match for editing; **Enter** runs it immediately.

The colored guide appears on startup. Display it again with:

```powershell
Show-TerminalKeys
```

`Get-History` lists only the current session. To read saved history:

```powershell
Get-Content -LiteralPath (Get-PSReadLineOption).HistorySavePath -Tail 50
```

## Update or customize

Update the repository in place, then open a new custom tab. If you move the folder, rerun the installer from its new location. Edit `paradox.omp.json` for prompt layout and `Prompt.ps1` for palette values or shell shortcuts. Do not add another `oh-my-posh init` after this package loads; it would replace the censor-mode wrapper.

The theme is a local customization of [Paradox from Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/paradox.omp.json). Oh My Posh is optional at runtime: the profile falls back to its built-in prompt if initialization fails.

## Troubleshooting

- **Icons show as boxes:** select the installed Nerd Font in the custom profile's Appearance settings, then reopen the tab.
- **Oh My Posh is not found:** restart Terminal after installation and check `oh-my-posh version`.
- **Invalid starting directory:** use `%USERPROFILE%` as the Terminal profile's starting folder, not `%CD%`, `%PWD%`, or `$PWD`. Open a fresh custom tab and retry.
- **Normal PowerShell still uses this prompt:** an earlier installation may have added a loader to `$PROFILE`. Remove that package-specific dot-source line, then open a fresh normal tab. The separate installation does not remove existing customizations.

## Uninstall

Delete **PowerShell Custom** in Windows Terminal's profile settings. If you used `-CurrentUserProfile`, remove this package's dot-source line from `$PROFILE` too. Remove any installed global shortcuts in Terminal's Actions settings, or restore the appropriate `settings.json.backup-*` file beside your settings file. Restoring a backup also reverts settings changed since that backup. Open a fresh session before deleting the repository folder.

## Verify

Run the dependency-free checks in PowerShell 7:

```powershell
.\Test-Profile.ps1
```

The checks use temporary Terminal settings and do not edit your installed profiles.
