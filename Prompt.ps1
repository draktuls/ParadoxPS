#requires -Version 7.4
# Custom PowerShell prompt, with Windows Terminal working-directory reporting.
# Ordinary PowerShell variables are local to this process, not inherited by tabs.
if (-not (Get-Variable TerminalCensorMode -Scope Global -ErrorAction SilentlyContinue)) {
    $global:TerminalCensorMode = 0
}
$global:TerminalCensorNames = @('OFF', 'Bash / Zsh style', 'Linux server', 'macOS', 'PowerShell', 'Command Prompt', 'Minimal')

if (-not (Get-Variable TerminalColorMode -Scope Global -ErrorAction SilentlyContinue)) {
    $global:TerminalColorMode = 0
}
$global:TerminalPalettes = @(
    @{ Name = 'Default'; User = '#3B82B5'; Path = '#BAE6FD'; Background = '#142B49'; Accent = '#87CEFA'; Elevated = '#FF8C00'; Root = '#FFE9AA'; Python = '#7CC4EF' },
    @{ Name = 'Purple'; User = '#8040B0'; Path = '#D8B4FE'; Background = '#32184D'; Accent = '#B56CFF'; Elevated = '#008080'; Root = '#5EEAD4'; Python = '#A855F7' },
    @{ Name = 'Orange'; User = '#B45309'; Path = '#FED7AA'; Background = '#4D2A18'; Accent = '#F97316'; Elevated = '#007ACC'; Root = '#93C5FD'; Python = '#FB923C' },
    @{ Name = 'Green'; User = '#15803D'; Path = '#BBF7D0'; Background = '#183D29'; Accent = '#22C55E'; Elevated = '#DB2777'; Root = '#F9A8D4'; Python = '#4ADE80' }
)
# Output colors complement the prompt while retaining red/yellow diagnostics.
$global:TerminalOutputPalettes = @(
    @{ Background = '#142B49'; Foreground = '#DCE6F2'; Muted = '#8BAABD'; Primary = '#87CEFA'; Secondary = '#BAE6FD'; Dark = '#4B8BB5'; Selection = '#25466B' },
    @{ Background = '#160F20'; Foreground = '#EDE4F5'; Muted = '#A18EAE'; Primary = '#C084FC'; Secondary = '#E9D5FF'; Dark = '#704C8D'; Selection = '#54336F' },
    @{ Background = '#21150E'; Foreground = '#F5E9DF'; Muted = '#B49A86'; Primary = '#FB923C'; Secondary = '#FED7AA'; Dark = '#9A642D'; Selection = '#704221' },
    @{ Background = '#0F1B14'; Foreground = '#E3F0E7'; Muted = '#8CA995'; Primary = '#4ADE80'; Secondary = '#BBF7D0'; Dark = '#3C8156'; Selection = '#28563B' }
)

function global:Get-TerminalColorSequences {
    param([int]$Mode)
    $esc = [char]27
    $end = "$esc\"
    $colors = $global:TerminalOutputPalettes[$Mode]
    $palette = @(
        $colors.Background, '#E06C75', $colors.Primary, '#E5C07B',
        $colors.Dark, $colors.Secondary, $colors.Primary, $colors.Foreground,
        $colors.Muted, '#FF7B86', $colors.Secondary, '#F9D98C',
        $colors.Primary, $colors.Secondary, $colors.Secondary, '#FFFFFF'
    )
    # Preserve configured default text, canvas, neutral colors and error reds.
    # Resets also remove foreground/background overrides from older versions.
    $output = "$esc]110${end}$esc]111${end}$esc]104;0;1;7;9;15${end}"
    for ($index = 1; $index -lt 16; $index++) {
        if ($index -in @(1, 7, 9, 15)) { continue }
        $hex = $palette[$index].TrimStart('#')
        $rgb = 'rgb:{0}/{1}/{2}' -f $hex.Substring(0, 2), $hex.Substring(2, 2), $hex.Substring(4, 2)
        $output += "$esc]4;$index;$rgb$end"
    }
    foreach ($entry in @(@(12, $colors.Primary), @(17, $colors.Selection))) {
        $output += "$esc]$($entry[0]);$($entry[1])$end"
    }
    return $output
}

function global:Set-TerminalOutputColors {
    if (-not (Get-Variable TerminalOriginalColors -Scope Global -ErrorAction SilentlyContinue)) {
        Import-Module PSReadLine -ErrorAction SilentlyContinue
        $original = @{ FileInfo = @{}; Extension = @{}; Formatting = @{}; ReadLine = @{}; Progress = $PSStyle.Progress.Style }
        foreach ($name in @('Directory', 'Executable', 'SymbolicLink')) { $original.FileInfo[$name] = $PSStyle.FileInfo.$name }
        foreach ($name in $PSStyle.FileInfo.Extension.Keys) { $original.Extension[$name] = $PSStyle.FileInfo.Extension[$name] }
        foreach ($name in @('FormatAccent', 'TableHeader', 'CustomTableHeaderLabel', 'Verbose', 'Debug', 'FeedbackName', 'FeedbackText', 'FeedbackAction')) {
            $original.Formatting[$name] = $PSStyle.Formatting.$name
        }
        if (Get-Module PSReadLine) {
            $options = Get-PSReadLineOption
            foreach ($name in @('ContinuationPrompt', 'DefaultToken', 'Comment', 'Keyword', 'String', 'Operator', 'Variable', 'Command', 'Parameter', 'Type', 'Number', 'Member', 'Emphasis', 'Error', 'Selection', 'InlinePrediction', 'ListPrediction', 'ListPredictionSelected', 'ListPredictionTooltip')) {
                $key = if ($name -eq 'DefaultToken') { 'Default' } else { $name }
                $original.ReadLine[$key] = $options."${name}Color"
            }
        }
        $global:TerminalOriginalColors = $original
    }
    if ((Get-Variable TerminalAppliedOutputMode -Scope Global -ErrorAction SilentlyContinue) -and $global:TerminalAppliedOutputMode -eq $global:TerminalColorMode) { return }

    $colors = $global:TerminalOutputPalettes[$global:TerminalColorMode]
    $primary = $PSStyle.Foreground.FromRgb([Convert]::ToInt32($colors.Primary.TrimStart('#'), 16))
    $secondary = $PSStyle.Foreground.FromRgb([Convert]::ToInt32($colors.Secondary.TrimStart('#'), 16))
    $muted = $PSStyle.Foreground.FromRgb([Convert]::ToInt32($colors.Muted.TrimStart('#'), 16))
    $selection = $PSStyle.Background.FromRgb([Convert]::ToInt32($colors.Selection.TrimStart('#'), 16)) + $secondary
    $PSStyle.FileInfo.Directory = $PSStyle.Bold + $primary
    $PSStyle.FileInfo.Executable = $PSStyle.Bold + $secondary
    $PSStyle.FileInfo.SymbolicLink = $secondary
    foreach ($name in @($PSStyle.FileInfo.Extension.Keys)) { $PSStyle.FileInfo.Extension[$name] = $secondary }
    foreach ($name in @('.ps1', '.psm1', '.psd1', '.ps1xml', '.json', '.yaml', '.yml', '.xml', '.toml', '.md')) { $PSStyle.FileInfo.Extension[$name] = $secondary }
    foreach ($name in @('FormatAccent', 'TableHeader', 'FeedbackName')) { $PSStyle.Formatting.$name = $primary }
    $PSStyle.Formatting.CustomTableHeaderLabel = $PSStyle.Bold + $primary
    foreach ($name in @('Verbose', 'Debug', 'FeedbackText', 'FeedbackAction')) { $PSStyle.Formatting.$name = $secondary }
    $PSStyle.Progress.Style = $primary
    if (Get-Module PSReadLine) {
        Set-PSReadLineOption -Colors @{
            Default = $global:TerminalOriginalColors.ReadLine.Default; Command = $primary; Keyword = $primary
            String = $secondary; Variable = $secondary; Parameter = $secondary
            Type = $primary; Number = $secondary; Member = $secondary
            Operator = $muted; Comment = $muted; ContinuationPrompt = $primary
            Emphasis = $PSStyle.Bold + $secondary; Selection = $selection
            InlinePrediction = $muted; ListPrediction = $primary
            ListPredictionSelected = $selection; ListPredictionTooltip = $muted
            Error = $global:TerminalOriginalColors.ReadLine.Error
        }
    }
    # Emit pane-local terminal colors without rewriting global Terminal settings.
    if ($env:WT_SESSION -and -not [Console]::IsOutputRedirected) {
        [Console]::Write((Get-TerminalColorSequences -Mode $global:TerminalColorMode))
    }
    $global:TerminalAppliedOutputMode = $global:TerminalColorMode
}

function global:Get-TerminalPaletteStatePath {
    if (-not $env:WT_SESSION) { return $null }
    # WT_SESSION identifies a pane, so use the actual Terminal ancestor instead.
    try {
        $ancestorId = $PID
        for ($depth = 0; $depth -lt 16 -and $ancestorId -gt 0; $depth++) {
            $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$ancestorId" -ErrorAction Stop
            if (-not $processInfo) { break }
            if ($processInfo.Name -eq 'WindowsTerminal.exe') {
                $started = $processInfo.CreationDate.ToUniversalTime().Ticks
                return Join-Path ([IO.Path]::GetTempPath()) "TerminalProfile-Palette-$ancestorId-$started.txt"
            }
            $ancestorId = $processInfo.ParentProcessId
        }
    }
    catch { }
    return $null
}

$global:TerminalPaletteStatePath = Get-TerminalPaletteStatePath

function global:Sync-TerminalPalette {
    if (-not $global:TerminalPaletteStatePath) { return }
    try {
        if ([IO.File]::Exists($global:TerminalPaletteStatePath)) {
            $mode = 0
            $value = [IO.File]::ReadAllText($global:TerminalPaletteStatePath).Trim()
            if ([int]::TryParse($value, [ref]$mode) -and $mode -ge 0 -and $mode -lt $global:TerminalPalettes.Count) {
                $global:TerminalColorMode = $mode
            }
        }
    }
    catch { }
    if ($global:TerminalAppliedOutputMode -ne $global:TerminalColorMode) {
        Set-TerminalPalette
    }
}

function global:Set-TerminalPalette {
    $palette = $global:TerminalPalettes[$global:TerminalColorMode]
    # Oh My Posh reads these for each render.
    foreach ($key in @('User', 'Path', 'Background', 'Accent', 'Elevated', 'Root', 'Python')) {
        [Environment]::SetEnvironmentVariable("TERMINAL_PROMPT_$key", $palette[$key], 'Process')
    }
    Set-TerminalOutputColors
}

function global:ConvertTo-TerminalRgb([string]$HexColor) {
    return ((1, 3, 5 | ForEach-Object { [Convert]::ToInt32($HexColor.Substring($_, 2), 16) }) -join ';')
}

function global:Switch-TerminalPalette {
    Sync-TerminalPalette
    $global:TerminalColorMode = ($global:TerminalColorMode + 1) % $global:TerminalPalettes.Count
    Set-TerminalPalette
    if ($global:TerminalPaletteStatePath) {
        $temporaryPath = "$global:TerminalPaletteStatePath.$([guid]::NewGuid()).tmp"
        try {
            [IO.File]::WriteAllText($temporaryPath, [string]$global:TerminalColorMode)
            [IO.File]::Move($temporaryPath, $global:TerminalPaletteStatePath, $true)
        }
        catch {
            Write-Warning 'Could not share the color selection; this pane will keep its local palette.'
            $global:TerminalPaletteStatePath = $null
        }
        finally {
            if ([IO.File]::Exists($temporaryPath)) { [IO.File]::Delete($temporaryPath) }
        }
    }
    $palette = $global:TerminalPalettes[$global:TerminalColorMode]
    $esc = [char]27
    $color = ConvertTo-TerminalRgb $palette.Path
    Write-Host "`n${esc}[1;38;2;${color}m  COLOR THEME: $($palette.Name) [$($global:TerminalColorMode + 1)/4]  ${esc}[0m"
}

# Reapply on reload, including removing background overrides from older versions.
Remove-Variable TerminalAppliedOutputMode -Scope Global -ErrorAction Ignore
Set-TerminalPalette
Sync-TerminalPalette

function global:Get-CensorPrompt {
    $esc = [char]27
    switch ($global:TerminalCensorMode) {
        # Zsh themes vary; use familiar green identity and blue directory colors.
        1 { return "${esc}[32muser@host${esc}[0m:${esc}[34m/tmp${esc}[0m$ " }
        2 { return '[user@server tmp]$ ' }
        3 { return 'user@Mac tmp % ' }
        4 { return 'PS C:\> ' }
        5 { return 'C:\> ' }
        6 { return '> ' }
    }
}

function global:Switch-CensorMode {
    $global:TerminalCensorMode = ($global:TerminalCensorMode + 1) % 7
    $esc = [char]27
    $label = $global:TerminalCensorNames[$global:TerminalCensorMode]
    Write-Host "`n${esc}[1;30;103m  CENSOR MODE: $label [$global:TerminalCensorMode/6]  ${esc}[0m"
}

# Capture the engine's module-bound prompt before installing our censor wrapper.
# Re-sourcing this file reuses it rather than accidentally capturing the wrapper.
if (-not (Get-Variable TerminalOmpPrompt -Scope Global -ValueOnly -ErrorAction SilentlyContinue)) {
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        try {
            $ompConfig = Join-Path $PSScriptRoot 'paradox.omp.json'
            $ompInit = & oh-my-posh init pwsh --config $ompConfig
            if ($LASTEXITCODE -ne 0 -or -not $ompInit) { throw 'Oh My Posh initialization failed.' }
            $ompInit | Out-String | Invoke-Expression
            $global:TerminalOmpPrompt = (Get-Command prompt -CommandType Function).ScriptBlock
        }
        catch {
            Write-Warning "Oh My Posh unavailable; using the original prompt. $($_.Exception.Message)"
        }
    }
}

function global:prompt {
    $savedExitCode = $global:LASTEXITCODE
    try {
        Sync-TerminalPalette
        $esc = [char]27
        $location = $ExecutionContext.SessionState.Path.CurrentLocation
        if ($global:TerminalCensorMode -gt 0) {
            if (Get-Module PSReadLine) {
                Set-PSReadLineOption -ExtraPromptLineCount 0
            }
            $report = ''
            if ($env:WT_SESSION -and $location.Provider.Name -eq 'FileSystem') {
                $report = "$esc]9;9;`"$($location.ProviderPath)`"$esc\"
            }
            return $report + (Get-CensorPrompt)
        }
        if (Get-Variable TerminalOmpPrompt -Scope Global -ValueOnly -ErrorAction SilentlyContinue) {
            return & $global:TerminalOmpPrompt
        }
        $userName = [Environment]::UserName
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        try {
            $principal = [Security.Principal.WindowsPrincipal]::new($identity)
            $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        finally {
            $identity.Dispose()
        }
        $palette = $global:TerminalPalettes[$global:TerminalColorMode]
        $userColor = ConvertTo-TerminalRgb $(if ($isAdmin) { $palette.Elevated } else { $palette.User })
        $pathColor = ConvertTo-TerminalRgb $palette.Path
        $prefix = if ($isAdmin) { 'Elevated ' } else { '' }
        $branch = $null
        $directoryReport = ''

        if ($location.Provider.Name -eq 'FileSystem') {
            $path = $location.ProviderPath
            if ($env:WT_SESSION) {
                $directoryReport = "$esc]9;9;`"$path`"$esc\"
            }
            if (Get-Command git -CommandType Application -ErrorAction SilentlyContinue) {
                $branch = & git -C $path symbolic-ref --quiet --short HEAD 2>$null
                # Exit 1 means HEAD is detached. Other failures need no second lookup.
                if ($LASTEXITCODE -eq 1) {
                    $branch = & git -C $path rev-parse --short HEAD 2>$null
                    if ($LASTEXITCODE -ne 0) { $branch = $null }
                }
            }
        }

        $text = "${directoryReport}${esc}[38;2;${pathColor}mPS${esc}[0m ${esc}[38;2;${userColor}m$prefix${userName}${esc}[0m ${esc}[38;2;${pathColor}m${location}${esc}[0m"
        if ($branch) {
            $text += " (${esc}[38;2;139;0;0m${branch}${esc}[0m)"
        }
        return "${text}: "
    }
    finally {
        $global:LASTEXITCODE = $savedExitCode
    }
}

# Run Show-TerminalKeys to display the guide again at any time.
function global:Show-TerminalKeys {
    $esc = [char]27
    $palette = $global:TerminalPalettes[$global:TerminalColorMode]
    $blue = "$esc[38;2;$(ConvertTo-TerminalRgb $palette.Path)m"
    $teal = "$esc[38;2;$(ConvertTo-TerminalRgb $palette.Accent)m"
    $muted = "$esc[38;2;145;155;170m"
    $reset = "$esc[0m"

    Write-Host ""
    Write-Host "${blue}  TERMINAL  ${muted}/  shortcut guide${reset}"
    Write-Host "${muted}  ----------------------------------------------------------${reset}"
    Write-Host "${teal}  PANES & TABS${reset}"
    $paneKeys = @(
        @('Ctrl+Shift+T', 'New tab in current directory'),
        @('Alt+Shift+V', 'Split side by side'),
        @('Alt+Shift+H', 'Split top and bottom'),
        @('Alt+Shift+D', 'Split automatically'),
        @('Alt+Arrow', 'Focus another pane'),
        @('Alt+Shift+Arrow', 'Resize pane'),
        @('Alt+Shift+Z', 'Zoom pane / restore'),
        @('Ctrl+Shift+W', 'Close pane or tab'),
        @('Ctrl+D', 'Close pane or tab'),
        @('Ctrl+E', 'Open current folder in Explorer'),
        @('Ctrl+H', 'Cycle censor prompts; after 6: OFF'),
        @('Ctrl+B', 'Colors: Default / Purple / Orange / Green')
    )
    foreach ($row in $paneKeys) {
        Write-Host ("  ${blue}{0,-21}${reset}{1}" -f $row[0], $row[1])
    }

    Write-Host ""
    Write-Host "${teal}  WINDOWS TERMINAL DEFAULTS${reset}"
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'Ctrl+Shift+F', 'Search terminal scrollback')
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'Ctrl+Shift+P', 'Open the Terminal command palette')
    Write-Host ""
    Write-Host "${teal}  COMMAND EDITING${reset}"
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'Tab / Ctrl+Space', 'Open the completion menu')
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'F1', 'Show help for the current PowerShell command')
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'F2', 'Switch between inline and list predictions')
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'Ctrl+L', 'Clear the screen')
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'Ctrl+W', 'Delete the word before the cursor')
    Write-Host ""
    Write-Host "${teal}  DIRECTORY HISTORY${reset}"
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'cd -', 'Go back to the previous location')
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'cd +', 'Go forward to the next location')
    Write-Host ""
    Write-Host "${teal}  COMMAND HISTORY${reset}"
    if (Get-Module PSReadLine) {
        $handlers = @(Get-PSReadLineKeyHandler -Bound)
        $historyActions = @(
            @('PreviousHistory', 'Previous command'),
            @('NextHistory', 'Next command'),
            @('ReverseSearchHistory', 'Search history backward'),
            @('ForwardSearchHistory', 'Search history forward'),
            @('HistorySearchBackward', 'Older command matching typed prefix'),
            @('HistorySearchForward', 'Newer command matching typed prefix'),
            @('ClearHistory', 'Clear in-memory history')
        )
        foreach ($row in $historyActions) {
            $keys = ($handlers | Where-Object Function -eq $row[0] | ForEach-Object Key) -join ', '
            if ($keys) {
                Write-Host ("  ${blue}{0,-21}${reset}{1}" -f $keys, $row[1])
            }
        }
    }
    Write-Host ("  ${blue}{0,-21}${reset}{1}" -f 'Get-History', 'List commands from this session')
    Write-Host ""
    Write-Host "${teal}  EXAMPLE / find a previous git command${reset}"
    Write-Host "  ${blue}Ctrl+R${reset}  then type ${blue}git${reset} to find a matching command."
    Write-Host "  ${blue}Ctrl+R${reset}  again: older match; repeat to keep searching."
    Write-Host "  ${blue}Ctrl+S${reset}  newer match if you went too far."
    Write-Host "  ${blue}Right Arrow${reset}  keep the match and edit before running."
    Write-Host "  ${blue}Enter${reset}  run the displayed command immediately."
    Write-Host "  ${muted}Type more letters to narrow the search.${reset}"
    Write-Host "${muted}  ----------------------------------------------------------${reset}"
    Write-Host "${muted}  Show-TerminalKeys  /  display this guide again${reset}"
    Write-Host "${muted}  Pane/tab shortcuts require -InstallTerminalKeybindings.${reset}"
    Write-Host ""
}

# Shell shortcuts also apply when this profile is reloaded manually.
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord Ctrl+b -BriefDescription CycleColorTheme -Description 'Cycle Default, Purple, Orange and Green prompt colors' -ScriptBlock {
        Switch-TerminalPalette
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
    Set-PSReadLineKeyHandler -Chord Ctrl+h -BriefDescription CycleCensorMode -Description 'Cycle six dummy prompts, then restore the normal prompt' -ScriptBlock {
        Switch-CensorMode
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
    Set-PSReadLineKeyHandler -Chord Ctrl+e -BriefDescription OpenExplorer -Description 'Open the current folder in File Explorer' -ScriptBlock {
        $currentLocation = $ExecutionContext.SessionState.Path.CurrentLocation
        if ($currentLocation.Provider.Name -eq 'FileSystem') {
            & explorer.exe $currentLocation.ProviderPath
        }
    }
}

# Keep scripts and noninteractive commands quiet; show once per session.
$startupArguments = [Environment]::GetCommandLineArgs()
$isScriptInvocation = @($startupArguments | Where-Object {
    $_ -match '^-(Command|CommandWithArgs|c|cwa|EncodedCommand|ec|e|File|f|NonInteractive|noni)$'
}).Count -gt 0
if ($env:WT_SESSION -and (-not $isScriptInvocation -or (Get-Variable TerminalProfileInteractiveLaunch -Scope Global -ValueOnly -ErrorAction Ignore)) -and -not $global:TerminalKeysShown) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    Show-TerminalKeys
    $global:TerminalKeysShown = $true
}
