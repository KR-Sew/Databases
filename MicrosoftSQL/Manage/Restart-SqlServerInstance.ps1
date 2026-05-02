# Get all SQL Server services
$sqlServices = Get-Service | Where-Object { $_.Name -like "MSSQL*" }

# Check if any SQL Server instances were found
if ($sqlServices.Count -eq 0) {
    Write-Host "No SQL Server instances found."
    exit
}

# Display the list of SQL Server instances
Write-Host "Found SQL Server Instances:"
$sqlServices | ForEach-Object { Write-Host "$($_.Name) - Status: $($_.Status)" }

# Prompt the user for action
$action = Read-Host "Do you want to restart a specific instance (enter name) or all instances (type 'all')?"

if ($action -eq "all") {
    # Restart all SQL Server instances
    foreach ($service in $sqlServices) {
        try {
            Restart-Service -Name $service.Name -Force -ErrorAction Stop
            Write-Host "Successfully restarted service: $($service.Name)"
        } catch {
            Write-Host "Failed to restart service: $($service.Name)"
            Write-Host "Error: $_"
        }
    }
} else {
    # Restart a specific instance
    $serviceToRestart = $sqlServices | Where-Object { $_.Name -eq $action }

    if ($serviceToRestart) {
        try {
            Restart-Service -Name $serviceToRestart.Name -Force -ErrorAction Stop
            Write-Host "Successfully restarted service: $($serviceToRestart.Name)"
        } catch {
            Write-Host "Failed to restart service: $($serviceToRestart.Name)"
            Write-Host "Error: $_"
        }
    } else {
        Write-Host "No SQL Server instance found with the name: $action"
    }
}
