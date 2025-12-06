<#
.SYNOPSIS
  Configure firewall and SQL network settings for SQL Server 2022 management.

.DESCRIPTION
  - Opens common SQL Server ports in Windows Firewall.
  - Optionally configures a fixed TCP port for a named instance and enables TCP.
  - Restarts SQL Server service to apply network changes.

.PARAMETER InstanceName
  (Optional) Named instance to configure. If omitted, script configures default instance.

.PARAMETER FixedTcpPort
  (Optional) If provided with InstanceName, sets the instance to use this fixed TCP port.

.PARAMETER AllowedRemoteRange
  (Optional) Remote IP/CIDR allowed to connect. Default: "Any" (not recommended for production).

.EXAMPLE
  .\Configure-SQLPorts.ps1 -InstanceName "MSSQLSERVER" -FixedTcpPort 1433 -AllowedRemoteRange "192.0.2.0/24"
#>

param(
  [string]$InstanceName = "",            # empty = default instance
  [int]$FixedTcpPort = 0,                # 0 = do not set fixed port
  [string]$AllowedRemoteRange = "Any"    # e.g. "10.0.0.0/22 " or "Any"
)

function New-FWRule {
  param(
    [string]$Name,
    [string]$Protocol,
    [string]$LocalPort,
    [string]$Direction = "Inbound",
    [string]$Action = "Allow",
    [string]$RemoteAddress = "Any",
    [string]$Description = ""
  )
  if (-not (Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $Name `
                        -Direction $Direction `
                        -Action $Action `
                        -Protocol $Protocol `
                        -LocalPort $LocalPort `
                        -RemoteAddress $RemoteAddress `
                        -Profile Any `
                        -Description $Description | Out-Null
    Write-Host "Created firewall rule: $Name"
  } else {
    Write-Host "Firewall rule exists: $Name"
  }
}

# Validate admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Error "Run this script as Administrator."
  exit 1
}

# Determine service names
if ([string]::IsNullOrWhiteSpace($InstanceName) -or $InstanceName -eq "MSSQLSERVER") {
  $sqlServiceName = "MSSQLSERVER"
  $sqlSvc = Get-Service -Name $sqlServiceName -ErrorAction SilentlyContinue
  if (-not $sqlSvc) {
    # try the default service name "MSSQLSERVER" as service display name may differ; try any MSSQL* service
    $sqlSvc = Get-Service | Where-Object { $_.Name -like "MSSQL*" } | Select-Object -First 1
    if ($sqlSvc) { $sqlServiceName = $sqlSvc.Name }
    else { Write-Warning "Could not find SQL Server service. Ensure SQL Server is installed."; }
  }
} else {
  $sqlServiceName = "MSSQL`$InstanceName"   # service name for named instance
}

# Firewall: common SQL ports
$remote = if ($AllowedRemoteRange -eq "Any") { "Any" } else { $AllowedRemoteRange }

# Core DB Engine default port (1433). If user set a fixed port for an instance, open that instead.
if ($FixedTcpPort -gt 0) {
  New-FWRule -Name "SQL Server TCP $FixedTcpPort" -Protocol TCP -LocalPort $FixedTcpPort -RemoteAddress $remote -Description "SQL Server Database Engine fixed TCP port"
} else {
  New-FWRule -Name "SQL Server TCP 1433" -Protocol TCP -LocalPort 1433 -RemoteAddress $remote -Description "SQL Server Database Engine default TCP port"
}

# SQL Browser (UDP 1434)
New-FWRule -Name "SQL Server Browser UDP 1434" -Protocol UDP -LocalPort 1434 -RemoteAddress $remote -Description "SQL Server Browser service (instance discovery)"

# SSAS (Analysis Services) default ports
New-FWRule -Name "SSAS TCP 2383" -Protocol TCP -LocalPort 2383 -RemoteAddress $remote -Description "SQL Server Analysis Services default instance"
New-FWRule -Name "SSAS TCP 2382" -Protocol TCP -LocalPort 2382 -RemoteAddress $remote -Description "SSAS redirector for named instances"

# Database Mirroring / Always On AG default endpoint (5022)
New-FWRule -Name "SQL Mirroring TCP 5022" -Protocol TCP -LocalPort 5022 -RemoteAddress $remote -Description "Database mirroring / Availability Groups endpoint"

# Common alternates and supporting ports
$additionalPorts = @(135, 445, 5985, 5986)
foreach ($p in $additionalPorts) {
  New-FWRule -Name "SQL Support TCP $p" -Protocol TCP -LocalPort $p -RemoteAddress $remote -Description "Support port often used with SQL Server management ($p)"
}

# RPC dynamic high ports (Windows default ephemeral range) - opens a range; adjust if your environment uses narrower range
$rpcHighStart = 49152
$rpcHighEnd   = 65535
if (-not (Get-NetFirewallRule -DisplayName "RPC High Ports for SQL Support" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName "RPC High Ports for SQL Support" `
                      -Direction Inbound -Action Allow -Protocol TCP `
                      -LocalPort "$rpcHighStart-$rpcHighEnd" -RemoteAddress $remote -Profile Any `
                      -Description "RPC high ephemeral ports required by certain remote management/cluster operations" | Out-Null
  Write-Host "Created firewall rule: RPC High Ports for SQL Support ($rpcHighStart-$rpcHighEnd)"
} else {
  Write-Host "Firewall rule exists: RPC High Ports for SQL Support"
}

# If the user specified a named instance and a fixed port, configure SQL Server network settings via registry
if ($InstanceName -and $FixedTcpPort -gt 0) {
  # SQL Server network configuration registry path differs for instance. Use SQL Server Network Configuration registry area.
  $regBase = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\"
  # Determine instance ID from InstalledInstances mapping
  $instKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
  try {
    $instanceId = (Get-ItemProperty -Path $instKey -ErrorAction Stop).$InstanceName
  } catch {
    Write-Warning "Could not determine instance ID for '$InstanceName'. Will attempt to set via SQL Server WMI provider instead."
    $instanceId = $null
  }

  if ($instanceId) {
    $tcpKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"
    if (-not (Test-Path $tcpKey)) {
      New-Item -Path $tcpKey -Force | Out-Null
    }
    Set-ItemProperty -Path $tcpKey -Name "TcpPort" -Value $FixedTcpPort -Type String
    Set-ItemProperty -Path $tcpKey -Name "TcpDynamicPorts" -Value "" -Type String
    Write-Host "Set fixed TCP port $FixedTcpPort for instance $InstanceName in registry ($tcpKey)."
  } else {
    # Fallback: use WMI/SMO via SQL Server WMI provider to set network config
    try {
      $wmi = New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') "localhost"
      $ins = if ($InstanceName) { $wmi.ServerInstances[$InstanceName] } else { $wmi.ServerInstances["MSSQLSERVER"] }
      if ($ins) {
        $ins.NetConfiguration.IPAll.Properties["TcpPort"].Value = "$FixedTcpPort"
        $ins.NetConfiguration.IPAll.Properties["TcpDynamicPorts"].Value = ""
        $ins.Alter()
        Write-Host "Set fixed TCP port $FixedTcpPort for instance $InstanceName via SMO WMI provider."
      } else {
        Write-Warning "Could not locate instance via SMO WMI provider."
      }
    } catch {
      Write-Warning "Failed to set fixed port via WMI/SMO: $_"
    }
  }
}

# Ensure TCP is enabled for the instance via registry (if possible)
if ($InstanceName) {
  $tcpEnumKey = if ($InstanceName -eq "MSSQLSERVER" -or [string]::IsNullOrEmpty($InstanceName)) {
    "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\MSSQLServerNetwork\Tcp"
  } else {
    # For named instances, network settings are under instance id discovered earlier
    if ($instanceId) {
      "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp"
    } else {
      $null
    }
  }
    if ($tcpEnumKey -and (Test-Path $tcpEnumKey)) {
    try {
      Set-ItemProperty -Path $tcpEnumKey -Name "Enabled" -Value 1 -ErrorAction Stop
      Write-Host "Enabled TCP protocol in registry path: $tcpEnumKey"
    } catch {
      Write-Warning ("Unable to set TCP Enabled value in registry path {0}: {1}" -f $tcpEnumKey, $_)
    }
  }

}

# Restart SQL Server service to apply changes (only if service found)
if ($sqlServiceName) {
  try {
    Write-Host "Restarting SQL Server service: $sqlServiceName"
    Restart-Service -Name $sqlServiceName -Force -ErrorAction Stop
    Write-Host "SQL Server service restarted."
  } catch {
    Write-Warning ("Unable to set TCP Enabled value in registry path {0}: {1}" -f $tcpEnumKey, $_)

  }
} else {
  Write-Warning "SQL Server service name not determined; please restart SQL Server manually to apply network changes."
}

Write-Host "Finished configuring firewall rules and SQL network settings. Verify ports and service endpoints as needed."
