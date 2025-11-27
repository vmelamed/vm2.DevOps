# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

<#
.SYNOPSIS
    Adds SPDX license headers to C# source files.

.DESCRIPTION
    Recursively scans the specified directory for .cs files and adds
    SPDX-License-Identifier headers if they don't already exist.
    Skips auto-generated files in obj/, bin/, and AssemblyInfo.cs files.

.PARAMETER Directory
    The root directory to scan for .cs files. Defaults to current directory.

.PARAMETER WhatIf
    Shows what would happen if the script runs without making changes.

.EXAMPLE
    .\Add-SPDXHeaders.ps1
    Adds headers to all .cs files in the current directory.

.EXAMPLE
    .\Add-SPDXHeaders.ps1 -Directory "C:\repos\my\vm2.DevOps"
    Adds headers to all .cs files in the specified directory.

.EXAMPLE
    .\Add-SPDXHeaders.ps1 -Directory src -WhatIf
    Preview what files would be modified in the src directory.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string]$Directory = (Get-Location).Path
)

$header = @"
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed


"@

# Validate directory exists
if (-not (Test-Path -Path $Directory -PathType Container)) {
    Write-Error "Directory not found: $Directory"
    exit 1
}

$Directory = Resolve-Path $Directory

Write-Host "Scanning directory: $Directory" -ForegroundColor Cyan
Write-Host ""

$filesProcessed = 0
$filesSkipped = 0
$filesModified = 0

Get-ChildItem -Path $Directory -Recurse -Filter "*.cs" |
    Where-Object {
        # Skip auto-generated files
        $_.FullName -notmatch '\\obj\\' -and
        $_.FullName -notmatch '\\bin\\' -and
        $_.FullName -notmatch 'AssemblyInfo\.cs$' -and
        $_.FullName -notmatch '\.g\.cs$' -and
        $_.FullName -notmatch '\.designer\.cs$'
    } |
    ForEach-Object {
        $filesProcessed++
        $content = Get-Content $_.FullName -Raw

        # Check if header already exists
        if ($content -notmatch "SPDX-License-Identifier") {
            if ($PSCmdlet.ShouldProcess($_.Name, "Add SPDX header")) {
                Write-Host "Adding header to: $($_.FullName.Replace($Directory, '.'))" -ForegroundColor Green

                # Preserve UTF-8 BOM if it exists
                $encoding = [System.Text.Encoding]::UTF8
                if ($content.StartsWith([char]0xFEFF)) {
                    $encoding = New-Object System.Text.UTF8Encoding $true
                }

                # Add header
                $newContent = $header + $content
                [System.IO.File]::WriteAllText($_.FullName, $newContent, $encoding)
                $filesModified++
            }
        } else {
            Write-Host "Skipping (has header): $($_.FullName.Replace($Directory, '.'))" -ForegroundColor Yellow
            $filesSkipped++
        }
    }

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Files scanned:  $filesProcessed" -ForegroundColor White
Write-Host "  Files modified: $filesModified" -ForegroundColor Green
Write-Host "  Files skipped:  $filesSkipped" -ForegroundColor Yellow
Write-Host ""
Write-Host "Done! SPDX headers added to $filesModified file(s)." -ForegroundColor Cyan