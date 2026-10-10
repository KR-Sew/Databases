# Define variables
$mongoVersion = "6.0.5"  # Change this to the desired version
$mongoDownloadUrl = "https://downloads.mongodb.com/win32/mongodb-windows-x86_64-enterprise-$mongoVersion.msi"
$mongoInstallerPath = "$env:TEMP\mongodb.msi"
$dataDirectory = "C:\data\db"
$mongoBinPath = "C:\Program Files\MongoDB\Server\$mongoVersion\bin"
$logDirectory = "C:\Program Files\MongoDB\Server\$mongoVersion\log"
$logFile = "$logDirectory\mongod.log"
$mongoServiceName = "MongoDB"

Write-Host "Starting MongoDB installation (version $mongoVersion)..."

# Check if running as Administrator
$currentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ Please run this script as Administrator."
    exit 1
}

# Check if MongoDB is already installed
if (Test-Path "$mongoBinPath\mongod.exe") {
    Write-Host "✅ MongoDB is already installed at $mongoBinPath."
    exit 0
}

# Download MongoDB MSI installer
Write-Host "⬇ Downloading MongoDB installer..."
try {
    Invoke-WebRequest -Uri $mongoDownloadUrl -OutFile $mongoInstallerPath -ErrorAction Stop
    Write-Host "✅ MongoDB installer downloaded successfully."
} catch {
    Write-Host "❌ Failed to download MongoDB installer: $_"
    exit 1
}

# Install MongoDB
Write-Host "🛠 Installing MongoDB..."
try {
    Start-Process msiexec.exe -ArgumentList "/i `"$mongoInstallerPath`" /quiet /norestart" -Wait -NoNewWindow
    Write-Host "✅ MongoDB installed successfully."
} catch {
    Write-Host "❌ MongoDB installation failed: $_"
    exit 1
}

# Create data and log directories if they don't exist
foreach ($dir in @($dataDirectory, $logDirectory)) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "📂 Created directory: $dir"
    }
}

# Add MongoDB to the system PATH
Write-Host "🔧 Adding MongoDB to system PATH..."
$existingPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if ($existingPath -notlike "*$mongoBinPath*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$existingPath;$mongoBinPath", [System.EnvironmentVariableTarget]::Machine)
    Write-Host "✅ MongoDB added to PATH."
} else {
    Write-Host "ℹ MongoDB is already in PATH."
}

# Install and start MongoDB as a service
Write-Host "🔄 Installing MongoDB as a service..."
try {
    & "$mongoBinPath\mongod.exe" --install --dbpath "$dataDirectory" --logpath "$logFile" --logappend
    Write-Host "✅ MongoDB service installed successfully."
} catch {
    Write-Host "❌ Failed to install MongoDB service: $_"
    exit 1
}

# Start the MongoDB service
Write-Host "🚀 Starting MongoDB service..."
try {
    Start-Service -Name "$mongoServiceName"
    Write-Host "✅ MongoDB service started successfully."
} catch {
    Write-Host "❌ Failed to start MongoDB service: $_"
    exit 1
}

# Verify service status
$serviceStatus = Get-Service -Name "$mongoServiceName" -ErrorAction SilentlyContinue
if ($serviceStatus.Status -eq "Running") {
    Write-Host "✅ MongoDB service is running."
} else {
    Write-Host "❌ MongoDB service failed to start."
    exit 1
}

# Clean up installer
Write-Host "🧹 Cleaning up installer..."
Remove-Item -Path "$mongoInstallerPath" -Force
Write-Host "✅ Cleanup completed."

Write-Host "🎉 MongoDB installation completed successfully."
