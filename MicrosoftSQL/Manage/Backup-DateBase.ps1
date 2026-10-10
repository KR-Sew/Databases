# Load the SQL Server SMO assembly
Add-Type -AssemblyName "Microsoft.SqlServer.Smo"

# Define parameters
$serverName = "YourServerName"  # Replace with your SQL Server instance name
$databaseName = "YourDatabaseName"  # Replace with your database name
$backupDirectory = "C:\Backups"  # Replace with your desired backup directory
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
$backupFileName = "$databaseName-$timestamp.bak"
$compressedBackupFileName = "$backupFileName.gz"

# Ensure the backup directory exists
if (!(Test-Path $backupDirectory)) {
    Write-Host "Backup directory does not exist. Creating: $backupDirectory"
    New-Item -ItemType Directory -Path $backupDirectory | Out-Null
}

# Create a new SQL Server Management Objects Server object
try {
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
    if ($null -eq $server.Databases[$databaseName]) {
        Write-Host "Error: Database '$databaseName' not found on server '$serverName'."
        exit 1
    }
} catch {
    Write-Host "Error connecting to SQL Server: $_"
    exit 1
}

# Create a new Backup object
$backup = New-Object Microsoft.SqlServer.Management.Smo.Backup
$backup.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database
$backup.Database = $databaseName
$backup.Devices.AddDevice("$backupDirectory\$backupFileName", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
$backup.Initialize = $true
$backup.CompressionOption = [Microsoft.SqlServer.Management.Smo.BackupCompressionOptions]::On

# Perform the backup
try {
    Write-Host "Starting backup of '$databaseName'..."
    $backup.SqlBackup($server)
    Write-Host "Backup completed: $backupFileName"

    # Compress the backup file using GZip
    $inputFile = "$backupDirectory\$backupFileName"
    $outputFile = "$backupDirectory\$compressedBackupFileName"

    Write-Host "Compressing backup file..."
    try {
        $inputStream = [System.IO.File]::OpenRead($inputFile)
        $outputStream = [System.IO.File]::Create($outputFile)
        $gzipStream = New-Object System.IO.Compression.GZipStream($outputStream, [System.IO.Compression.CompressionMode]::Compress)

        $inputStream.CopyTo($gzipStream)

        # Clean up resources
        $gzipStream.Dispose()
        $outputStream.Dispose()
        $inputStream.Dispose()

        # Delete original backup file
        Remove-Item $inputFile -Force

        Write-Host "Backup compressed successfully: $compressedBackupFileName"
    } catch {
        Write-Host "Error during compression: $_"
    }
} catch {
    Write-Host "Error during backup: $_"
    exit 1
}
