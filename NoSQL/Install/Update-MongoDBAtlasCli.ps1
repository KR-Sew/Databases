# PowerShell script to update MongoDB Atlas CLI on Windows with msi package

$ErrorActionPreference = "Stop"

function Get-LatestAtlasCliVersion {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/mongodb/mongodb-atlas-cli/releases/latest" -Headers @{ 'User-Agent' = 'PowerShell' }
    $rawTag = $latestRelease.tag_name
    if ($rawTag -match ".*?/v(?<version>\d+\.\d+\.\d+)") {
        return $matches['version']
    } else {
        throw "Unexpected tag_name format: $rawTag"
    }
}

function Get-InstalledAtlasCliVersion {
    try {
        $versionOutput = atlas.exe version 2>$null
        if ($versionOutput -match "atlas version (\d+\.\d+\.\d+)") {
            return $matches[1]
        }
    } catch {
        return $null
    }
}

function Update-AtlasCli {
    $latestVersion = Get-LatestAtlasCliVersion
    $installedVersion = Get-InstalledAtlasCliVersion

    Write-Host "Installed version: $installedVersion"
    Write-Host "Latest version:    $latestVersion"

    # Exit if the installed version is already the latest version
    if ($installedVersion -eq $latestVersion) {
        Write-Host "MongoDB Atlas CLI is already up to date." -ForegroundColor Green
        return
    }

    Write-Host "Updating MongoDB Atlas CLI to version $latestVersion..." -ForegroundColor Yellow

    # Corrected URL for downloading the latest MSI installer
    $baseUrl = "https://github.com/mongodb/mongodb-atlas-cli/releases/download/atlascli%2Fv$latestVersion"
    $msiFileName = "mongodb-atlas-cli_${latestVersion}_windows_x86_64.msi"

    # Full URL for the MSI download
    $msiUrl = "$baseUrl/$msiFileName"
    Write-Host "Attempting to download from: $msiUrl"

    try {
        $response = Invoke-WebRequest -Uri $msiUrl -OutFile "$env:TEMP\mongodb-atlas-cli.msi"
        
        # Check if the file was downloaded successfully (file size > 0)
        if ((Get-Item "$env:TEMP\mongodb-atlas-cli.msi").length -eq 0) {
            Write-Error "Downloaded file is empty. Please check if the URL is correct or if the release exists."
            return
        } else {
            Write-Host "Download succeeded with status code: $($response.StatusCode)" -ForegroundColor Cyan
        }
    } catch {
        Write-Error "Failed to download the MSI file. Please check if the URL is correct or if the release exists."
        return
    }

    # Install the MSI package
    Write-Host "Installing MongoDB Atlas CLI..." -ForegroundColor Yellow
    $msiPath = "$env:TEMP\mongodb-atlas-cli.msi"
    Start-Process msiexec.exe -ArgumentList "/i", "`"$msiPath`"", "/quiet", "/norestart" -Wait

    Write-Host "MongoDB Atlas CLI updated to version $latestVersion successfully." -ForegroundColor Green

    # Clean up the MSI file
    Remove-Item -Force -Path $msiPath
}

Update-AtlasCli
