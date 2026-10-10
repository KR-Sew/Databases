param (
    [string]$DatabaseName,
    [string]$SnapshotName,
    [string]$SnapshotPath
)

# Load the SQL Server SMO assembly
Add-Type -AssemblyName "Microsoft.SqlServer.SMO"

# Define the SQL Server instance
$SqlServerInstance = "localhost"  # Change this to your SQL Server instance name if needed

# Create a new Server object
$server = New-Object Microsoft.SqlServer.Management.Smo.Server $SqlServerInstance

# Check if the database exists
if (-not $server.Databases[$DatabaseName]) {
    Write-Host "Database '$DatabaseName' does not exist."
    exit
}

# Construct the full path for the snapshot file
$snapshotFilePath = Join-Path -Path $SnapshotPath -ChildPath "$SnapshotName.ss"

# Create the snapshot SQL command
$snapshotSql = @"
CREATE DATABASE [$SnapshotName] 
ON 
(NAME = [$DatabaseName], FILENAME = '$snapshotFilePath')
AS SNAPSHOT OF [$DatabaseName];
"@

# Execute the SQL command to create the snapshot
try {
    $server.ConnectionContext.ExecuteNonQuery($snapshotSql)
    Write-Host "Database snapshot '$SnapshotName' created successfully at '$snapshotFilePath'."
} catch {
    Write-Host "Error creating snapshot: $_"
}
