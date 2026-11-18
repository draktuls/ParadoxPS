#requires -Version 7.4
param([switch]$Worker)

# Run in a child process so checks do not change the caller's shell configuration.
if (-not $Worker) {
    & (Join-Path $PSHOME 'pwsh.exe') -NoLogo -NoProfile -NonInteractive -File $PSCommandPath -Worker
    if ($LASTEXITCODE) { throw 'Profile checks failed.' }
    return
}
$ErrorActionPreference = 'Stop'
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$root = Join-Path ([IO.Path]::GetTempPath()) ('TerminalProfile-Test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$settingsPath = Join-Path $root 'settings.json'
$shellPath = Join-Path $root 'startup.ps1'
$installer = Join-Path $PSScriptRoot 'Install-Profile.ps1'
$fixture = @'
{
    // Existing settings must survive installation.
    "defaultProfile": "original",
    "profiles": {"list": [{"guid": "original", "name": "PowerShell", "font": {"face": "Consolas"}}]},
    "actions": [{"id": "Keep", "command": "paste", "keys": ["ctrl+b", "alt+p"]}],
    "keybindings": [{"keys": "ctrl+b", "id": "Keep"}],
}
'@
Set-Content -LiteralPath $settingsPath -Value $fixture
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
    $tokens = $null; $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert ($parseErrors.Count -eq 0) "Syntax error in $($file.Name): $parseErrors"
}
& $installer -TerminalSettingsPath $settingsPath | Out-Null
& $installer -TerminalSettingsPath $settingsPath -ProfileName 'My Shell' | Out-Null
$s = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
Assert ($s.profiles.list.Count -eq 2) 'Repeat install created duplicate entries.'
Assert ($s.defaultProfile -eq 'original') 'Default Terminal profile changed.'
Assert ($s.profiles.list[0].font.face -eq 'Consolas') 'Original appearance changed.'
Assert ($s.profiles.list[1].commandline.Contains('-NoProfile -NoExit -File')) 'Launcher is not isolated.'
Assert ($s.profiles.list[1].name -eq 'My Shell') 'Rename failed.'
Assert ($s.keybindings.Count -eq 1 -and $s.keybindings[0].id -eq 'Keep') 'Shortcuts installed without opt-in.'
$beforeConflict = Get-Content -LiteralPath $settingsPath -Raw
try { & $installer -TerminalSettingsPath $settingsPath -ProfileName PowerShell | Out-Null; throw 'Expected name conflict.' }
catch { Assert ($_.Exception.Message -like 'Another Terminal profile*') 'Unexpected conflict error.' }
Assert ((Get-Content -LiteralPath $settingsPath -Raw) -ceq $beforeConflict) 'Failed validation changed settings.'

& $installer -TerminalSettingsPath $settingsPath -InstallTerminalKeybindings | Out-Null
& $installer -TerminalSettingsPath $settingsPath -InstallTerminalKeybindings | Out-Null
$s = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
Assert ($s.keybindings.Count -eq 15) 'Incorrect shortcut count.'
Assert (@($s.keybindings | Group-Object keys | Where-Object Count -gt 1).Count -eq 0) 'Duplicate shortcuts.'
Assert ((($s.actions | Where-Object id -eq Keep).keys -join ',') -eq 'alt+p') 'Legacy shortcut conflict not resolved.'
Set-Content -LiteralPath $shellPath -Value '# Existing customization'
& $installer -TerminalSettingsPath $settingsPath -CurrentUserProfile -ProfilePath $shellPath | Out-Null
& $installer -TerminalSettingsPath $settingsPath -CurrentUserProfile -ProfilePath $shellPath | Out-Null
$profileText = Get-Content -LiteralPath $shellPath -Raw
Assert ($profileText.StartsWith('# Existing customization')) 'Existing startup text lost.'
Assert ([regex]::Matches($profileText, "(?m)^\. '").Count -eq 1) 'Duplicate startup loader.'
Assert (@(Get-ChildItem -LiteralPath $root -Filter 'settings.json.backup-*').Count -gt 0) 'No settings backup.'
Set-Content -LiteralPath $settingsPath -Value '{}'
& $installer -TerminalSettingsPath $settingsPath | Out-Null
Assert ((Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).profiles.list.Count -eq 1) 'Empty settings unsupported.'

# Stub the external engine; validate the wrapper and real PSReadLine.
$env:WT_SESSION = $null
$global:TerminalOmpPrompt = { 'engine> ' }
. (Join-Path $PSScriptRoot 'Prompt.ps1')
$defaultText = (Get-PSReadLineOption).DefaultTokenColor
$errorText = (Get-PSReadLineOption).ErrorColor
$errorOutput = $PSStyle.Formatting.Error
for ($mode = 0; $mode -lt 4; $mode++) {
    $global:TerminalColorMode = $mode
    Set-TerminalPalette
    $rgb = ConvertTo-TerminalRgb $global:TerminalOutputPalettes[$mode].Primary
    Assert ($PSStyle.FileInfo.Directory.Contains($rgb)) 'File listing did not use palette.'
    Assert ((Get-PSReadLineOption).DefaultTokenColor -eq $defaultText) 'Default text changed.'
    Assert ((Get-PSReadLineOption).ErrorColor -eq $errorText) 'Error highlighting changed.'
    Assert ($PSStyle.Formatting.Error -eq $errorOutput) 'PowerShell error formatting changed.'
    $seq = Get-TerminalColorSequences $mode
    foreach ($osc in @(10, 11)) { Assert (-not $seq.Contains("$([char]27)]$osc;")) 'Foreground/background overridden.' }
    foreach ($index in @(0, 1, 7, 9, 15)) { Assert (-not $seq.Contains("$([char]27)]4;$index;")) 'Protected ANSI color overridden.' }
}
Switch-TerminalPalette | Out-Null
Assert ($global:TerminalColorMode -eq 0) 'Palette cycle failed.'
$global:LASTEXITCODE = 37
for ($mode = 1; $mode -le 6; $mode++) {
    Switch-CensorMode | Out-Null
    Assert ($global:TerminalCensorMode -eq $mode) 'Censor cycle failed.'
    Assert (((prompt) -join '').EndsWith((Get-CensorPrompt))) 'Censor prompt mismatch.'
    Assert ($global:LASTEXITCODE -eq 37) 'Prompt changed command exit code.'
}
Switch-CensorMode | Out-Null
Assert ((prompt) -eq 'engine> ') 'Normal engine not restored.'
Assert ((Get-PSReadLineKeyHandler -Chord Tab).Function -eq 'MenuComplete') 'Tab completion menu not registered.'
Assert ((Get-PSReadLineKeyHandler -Chord Ctrl+b).Function -eq 'CycleColorTheme') 'Ctrl+B not registered.'
Assert ((Get-PSReadLineKeyHandler -Chord Ctrl+h).Function -eq 'CycleCensorMode') 'Ctrl+H not registered.'
Assert ((Get-PSReadLineKeyHandler -Chord Ctrl+e).Function -eq 'OpenExplorer') 'Ctrl+E not registered.'
$global:TerminalPaletteStatePath = Join-Path $root 'palette.txt'
[IO.File]::WriteAllText($global:TerminalPaletteStatePath, '2')
Sync-TerminalPalette
Assert ($global:TerminalColorMode -eq 2) 'Shared state not read.'
Switch-TerminalPalette | Out-Null
Assert ([IO.File]::ReadAllText($global:TerminalPaletteStatePath) -eq '3') 'Shared state not saved.'
[IO.File]::WriteAllText($global:TerminalPaletteStatePath, 'invalid')
Sync-TerminalPalette
Assert ($global:TerminalColorMode -eq 3) 'Invalid shared state changed the palette.'
Write-Output 'All checks passed: installer safety, repeat installation, shortcuts, palettes, censor mode, and shared state.'
Write-Output "Temporary fixtures: $root"
