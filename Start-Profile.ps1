#requires -Version 7.4
# Used only by the separate Windows Terminal profile (-NoProfile -NoExit -File).
$global:TerminalProfileInteractiveLaunch = $true
. (Join-Path $PSScriptRoot 'Prompt.ps1')
