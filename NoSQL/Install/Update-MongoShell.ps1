# Update-MongoShell.ps1
# Checks for the latest mongosh version and updates if needed.

function Get-LatestMongoshVersion {
    $apiUrl = "https://api.github.com/repos/mongodb-js/mongosh/releases/latest"
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'PowerShell' }
        return $response.tag_name.TrimStart("v")
    } catch {
        Write-Error "Failed to fetch latest version: $_"
        return $null
    }
}

function Get-InstalledMongoshVersion {
    try {
        $versionOutput = mongosh --version 2>&1
        if ($versionOutput -match '([0-9]+\.[0-9]+\.[0-9]+)') {
            return $matches[1]
        }
    } catch {
        Write-Warning "mongosh is not installed or not in PATH."
    }
    return $null
}

function Install-Mongosh {
    param(
        [string]$Version
    )

    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $url = "https://downloads.mongodb.com/compass/mongosh-${Version}-win32-${arch}.zip"
    $tempPath = "$env:TEMP\mongosh-$Version.zip"
    $installPath = "$env:ProgramFiles\mongosh"

    Write-Output "Downloading mongosh $Version..."
    Invoke-WebRequest -Uri $url -OutFile $tempPath

    if (Test-Path $installPath) {
        Write-Output "Removing existing mongosh installation at $installPath"
        Remove-Item -Recurse -Force -Path $installPath
    }

    Expand-Archive -Path $tempPath -DestinationPath $installPath
    Remove-Item $tempPath

    # Optionally, add to PATH if not already
    if (-not ($env:PATH -split ";" | Where-Object { $_ -eq "$installPath" })) {
        Write-Output "Adding mongosh to system PATH"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";$installPath", [EnvironmentVariableTarget]::Machine)
    }

    Write-Output "mongosh $Version installed successfully at $installPath"
}

# Main logic
$latest = Get-LatestMongoshVersion
$current = Get-InstalledMongoshVersion

Write-Host "Installed version: $current"
Write-Host "Latest version:    $latest"

if (-not $latest) {
    Write-Error "Could not determine the latest mongosh version."
    exit 1
}

if ($current -ne $latest) {
    Write-Host "Updating mongosh to version $latest..."
    Install-Mongosh -Version $latest
} else {
    Write-Host "mongosh is already up to date."
}
