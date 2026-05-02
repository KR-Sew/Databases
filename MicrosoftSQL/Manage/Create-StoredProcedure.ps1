# Define parameters
$serverName = "localhost"  # Replace with your SQL Server name
$databaseName = "AdventureWorks"  # Replace with your database name
$storedProcedureName = "YourStoredProcedureName"  # Replace with your stored procedure name

# Define the SQL for the stored procedure
$sql = @"
CREATE PROCEDURE [$storedProcedureName]
AS
BEGIN
    -- Your SQL logic here
    SELECT 'Hello, World!' AS Message;  -- Example logic
END
"@

# Load the SQL Server module
Import-Module SqlServer

# Create a SQL connection string
$connectionString = "Server=$serverName;Database=$databaseName;Integrated Security=True;"

# Execute the SQL command to create the stored procedure
try {
    # Create a new SQL connection
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $sqlConnection.Open()

    # Create a SQL command
    $sqlCommand = $sqlConnection.CreateCommand()
    $sqlCommand.CommandText = $sql

    # Execute the command
    $sqlCommand.ExecuteNonQuery()
    Write-Host "Stored procedure '$storedProcedureName' created successfully."
}
catch {
    Write-Host "An error occurred: $_"
}
finally {
    # Close the SQL connection
    if ($sqlConnection.State -eq 'Open') {
        $sqlConnection.Close()
    }
}
