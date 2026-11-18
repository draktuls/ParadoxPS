#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$TerminalSettingsPath,
    [ValidateNotNullOrEmpty()][string]$ProfileName = 'PowerShell Custom',
    [switch]$InstallTerminalKeybindings,
    [switch]$CurrentUserProfile,
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
    # Retained for compatibility; separate installation is now the default.
    [switch]$SeparateProfile
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This profile requires Windows and PowerShell 7.4 or newer.' }
if ($SeparateProfile -and ($CurrentUserProfile -or $PSBoundParameters.ContainsKey('ProfilePath'))) {
    throw 'Use either a separate Terminal profile or -CurrentUserProfile, not both.'
}
$useShellProfile = $CurrentUserProfile -or $PSBoundParameters.ContainsKey('ProfilePath')
$customGuid = '{a57fc032-e5b3-4b5f-a2e2-0dde5c311e5c}'
foreach ($file in @('Prompt.ps1', 'Start-Profile.ps1', 'paradox.omp.json', 'Terminal-Keybindings.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) {
        throw "Missing $file. Keep all repository files together."
    }
}
$promptPath = Join-Path $PSScriptRoot 'Prompt.ps1'
$launcher = Join-Path $PSScriptRoot 'Start-Profile.ps1'
$bundle = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Terminal-Keybindings.json') -Raw | ConvertFrom-Json
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'paradox.omp.json') -Raw | ConvertFrom-Json | Out-Null

if (-not $TerminalSettingsPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    if (@($candidates).Count -eq 1) { $TerminalSettingsPath = @($candidates)[0] }
    elseif (@($candidates).Count -gt 1) {
        throw 'Multiple Terminal settings files found. Specify -TerminalSettingsPath with the active settings.json path.'
    }
    else { throw 'Open Windows Terminal once, or specify -TerminalSettingsPath with its settings.json path.' }
}
$TerminalSettingsPath = (Resolve-Path -LiteralPath $TerminalSettingsPath).Path
$originalSettings = [IO.File]::ReadAllText($TerminalSettingsPath)
# PowerShell accepts Terminal JSON with comments and trailing commas.
$settings = ConvertFrom-Json -InputObject $originalSettings
if (-not $settings -or $settings -is [array] -or $settings -isnot [pscustomobject]) {
    throw 'Terminal settings must contain a JSON object.'
}

if (-not $useShellProfile) {
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { throw 'ProfileName must not be blank.' }
    $pwshPath = Join-Path $PSHOME 'pwsh.exe'
    if (-not $settings.profiles) { $settings | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force }
    if ($settings.profiles -isnot [pscustomobject]) { throw 'Terminal profiles must be a JSON object.' }
    $existing = @($settings.profiles.list | Where-Object guid -eq $customGuid)
    if ($existing.Count -gt 1) { throw 'Duplicate custom profile GUIDs found in settings.json.' }
    if (@($settings.profiles.list | Where-Object { $_.name -eq $ProfileName -and $_.guid -ne $customGuid }).Count) {
        throw "Another Terminal profile is named '$ProfileName'. Choose a different -ProfileName."
    }
    $entry = if ($existing.Count) { $existing[0] } else {
        [pscustomobject]@{ guid = $customGuid; name = $ProfileName; hidden = $false; startingDirectory = '%USERPROFILE%' }
    }
    $entry | Add-Member -NotePropertyName name -NotePropertyValue $ProfileName -Force
    $command = '"{0}" -NoLogo -NoProfile -NoExit -File "{1}"' -f $pwshPath, $launcher
    $entry | Add-Member -NotePropertyName commandline -NotePropertyValue $command -Force
    $entries = @($settings.profiles.list | Where-Object { $_ -and $_.guid -ne $customGuid }) + @($entry)
    $settings.profiles | Add-Member -NotePropertyName list -NotePropertyValue $entries -Force
}

if ($InstallTerminalKeybindings) {
    $replacedKeys = @($bundle.keybindings.keys) + @('ctrl+h', 'ctrl+e', 'ctrl+b')
    $actions = @($settings.actions | Where-Object { $_ -and $_.id -notin $bundle.actions.id })
    # Older Terminal files can store shortcut keys directly on actions.
    foreach ($action in $actions) {
        if ($action.PSObject.Properties['keys']) {
            $remaining = @($action.keys | Where-Object { $_ -notin $replacedKeys })
            if ($remaining.Count) { $action.keys = $remaining }
            else { $action.PSObject.Properties.Remove('keys') }
        }
    }
    $actions += @($bundle.actions)
    $bindings = @($settings.keybindings | Where-Object { $_ -and $_.keys -notin $replacedKeys }) + @($bundle.keybindings)
    $settings | Add-Member -NotePropertyName actions -NotePropertyValue $actions -Force
    $settings | Add-Member -NotePropertyName keybindings -NotePropertyValue $bindings -Force
}

$loader = ". '$($promptPath.Replace("'", "''"))'"
$originalProfile = if (Test-Path -LiteralPath $ProfilePath -PathType Leaf) { [IO.File]::ReadAllText($ProfilePath) } else { '' }
$updateProfile = $useShellProfile -and -not $originalProfile.Contains($loader)
$newSettings = $settings | ConvertTo-Json -Depth 100
$newSettings | ConvertFrom-Json | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fffffff'
$settingsBackup = "$TerminalSettingsPath.backup-$stamp"
$tempPath = "$TerminalSettingsPath.$([guid]::NewGuid()).tmp"
try {
    # Write beside the target, then atomically replace it. Abort on concurrent edits.
    [IO.File]::WriteAllText($tempPath, $newSettings + [Environment]::NewLine)
    if ([IO.File]::ReadAllText($TerminalSettingsPath) -cne $originalSettings) {
        throw 'Terminal settings changed during installation. Please run the installer again.'
    }
    Copy-Item -LiteralPath $TerminalSettingsPath -Destination $settingsBackup
    if ($updateProfile) {
        if (Test-Path -LiteralPath $ProfilePath) { Copy-Item -LiteralPath $ProfilePath -Destination "$ProfilePath.backup-$stamp" }
        New-Item -ItemType Directory -Path (Split-Path $ProfilePath) -Force | Out-Null
        [IO.File]::WriteAllText($ProfilePath, $originalProfile + "`r`n# Custom Terminal profile`r`n$loader`r`n")
    }
    [IO.File]::Move($tempPath, $TerminalSettingsPath, $true)
}
catch {
    if ($updateProfile -and (Test-Path -LiteralPath "$ProfilePath.backup-$stamp")) {
        Copy-Item -LiteralPath "$ProfilePath.backup-$stamp" -Destination $ProfilePath -Force
    }
    elseif ($updateProfile -and (Test-Path -LiteralPath $ProfilePath) -and -not $originalProfile) {
        # Preserve a new file as empty if installation could not finish.
        [IO.File]::WriteAllText($ProfilePath, '')
    }
    throw
}
finally {
    if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) }
}

if ($useShellProfile) { Write-Output "Installed into $ProfilePath. Reload with: . `$PROFILE" }
else { Write-Output "Installed '$ProfileName'. Open it from Windows Terminal's profile menu." }
if ($InstallTerminalKeybindings) { Write-Output 'Installed Terminal shortcuts (these apply to all Terminal profiles).' }
else { Write-Output 'Terminal shortcuts unchanged. Add -InstallTerminalKeybindings to install them.' }
Write-Output "Settings backup: $settingsBackup"
