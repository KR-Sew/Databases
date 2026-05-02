# Load the SQL Server SMO assembly
Add-Type -AssemblyName "Microsoft.SqlServer.Smo"

# Define the SQL Server instance and database name
$serverName = "YourServerName"  # Replace with your SQL Server instance name
$databaseName = "YourDatabaseName"  # Replace with your database name
$backupDirectory = "C:\Backups"  # Replace with your desired backup directory
$backupFileName = "$databaseName-$(Get-Date -Format 'yyyyMMddHHmmss').bak"
$compressedBackupFileName = "$backupFileName.gz"

# Create a new SQL Server Management Objects Server object
$server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName

# Create a new Backup object
$backup = New-Object Microsoft.SqlServer.Management.Smo.Backup
$backup.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database
$backup.Database = $databaseName
$backup.Devices.AddDevice("$backupDirectory\$backupFileName", [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
$backup.Initialize = $true
$backup.CompressionOption = [Microsoft.SqlServer.Management.Smo.BackupCompressionOptions]::On

# Perform the backup
try {
    $backup.SqlBackup($server)
    Write-Host "Backup of database '$databaseName' completed successfully."

    # Compress the backup file using GZip
    $inputFile = "$backupDirectory\$backupFileName"
    $outputFile = "$backupDirectory\$compressedBackupFileName"

    # Compress the backup file
    $fileStream = [System.IO.File]::Open($inputFile, [System.IO.FileMode]::Open)
    $compressedStream = [System.IO.File]::Create($outputFile)
    $gzipStream = New-Object System.IO.Compression.GZipStream($compressedStream, [System.IO.Compression.CompressionMode]::Compress)

    $fileStream.CopyTo($gzipStream)

    # Clean up
    $gzipStream.Close()
    $compressedStream.Close()
    $fileStream.Close()

    # Optionally, delete the uncompressed backup file
    Remove-Item $inputFile

    Write-Host "Backup file compressed to '$compressedBackupFileName'."
} catch {
    Write-Host "An error occurred: $_"
}
