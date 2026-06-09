#!/usr/bin/env pwsh
param(
    [string]$Version = "latest",
    [string]$InstallDir = ""
)

$Repo = "devstroop/gitctl"

function Write-Help {
    @"
Usage: irm https://github.com/$Repo/releases/latest/download/install.ps1 | iex

Options:
  --version <tag>   Version tag to install (default: latest)
  --dir <path>      Install directory (default: %LOCALAPPDATA%\gitctl)
  --help            Show this help
"@
    exit 0
}

# Parse arguments manually (since we support both named and positional-like)
$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        "--version" { $Version = $args[$i + 1]; $i += 2 }
        "--dir" { $InstallDir = $args[$i + 1]; $i += 2 }
        "--help" { Write-Help }
        default { Write-Host "Unknown option: $($args[$i])"; exit 1 }
    }
}

if (-not $InstallDir) {
    $InstallDir = "$env:LOCALAPPDATA\gitctl"
}

# Detect architecture
$Arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { "x86_64" }
    "ARM64" { "aarch64" }
    default { throw "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}

# Resolve latest version
if ($Version -eq "latest") {
    Write-Host "  Fetching latest release..."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
    $Version = $release.tag_name
}

$Archive = "gitctl-${Version}-${Arch}-windows.zip"
$Url = "https://github.com/$Repo/releases/download/$Version/$Archive"

Write-Host "  Repository:  $Repo"
Write-Host "  Version:     $Version"
Write-Host "  Platform:    $Arch-windows"
Write-Host "  Target:      $InstallDir\gitctl.exe"
Write-Host ""

# Download
$Tmp = "$env:TEMP\gitctl-install"
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
try {
    Write-Host "  Downloading $Archive..."
    Invoke-WebRequest -Uri $Url -OutFile "$Tmp\$Archive"

    # Extract
    Write-Host "  Extracting..."
    Expand-Archive -Path "$Tmp\$Archive" -DestinationPath $Tmp -Force

    # Install
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Move-Item -Force "$Tmp\gitctl.exe" "$InstallDir\gitctl.exe"

    # Add to user PATH if not already there
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        $NewPath = "$UserPath;$InstallDir"
        [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Host "  Added $InstallDir to user PATH (log out/in to apply)"
    }

    Write-Host ""
    Write-Host "  ✓ gitctl $Version installed to $InstallDir\gitctl.exe"
} finally {
    Remove-Item "$Tmp" -Recurse -Force -ErrorAction SilentlyContinue
}
