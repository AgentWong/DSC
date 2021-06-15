<#
.Synopsis
   Script to automatically take an Exchange 2013 Server out of Maintenance Mode.
   
   Current Version: 1.5

   Version History:
   v1.5: remove the need to dot-source the script before running
   v1.4: included code to restart transport services after changing the component states. Added additional check for component states.
         General code improvements. Better remoting support (script can now be executed from a remote server, even for DAG members)
         Better error-handling, improved logic
   v1.3: included code to redirect messages from the server that is to be put in maintenance mode to another server.
   v1.2: included code to exclude poision a Shadow Redundancy queue when checking if all queues were empty

.DESCRIPTION
   This script is created to automatically take an Exchange 2013 Server out of Maintenance Mode. 
   It will automatically detect if the server is a Mailbox Server and then take appropriate additional actions, if any.

   To execute the script, you will have to dot-source it first after which you can call the cmdlet: "Stop-ExchangeServerMaintenanceMode"
.NOTES
Original Author: Michael Van Horenbeeck (Microsoft Exchange MVP)
Modified By: Herman Wong
Modifications:
Modified to execute without user provided paramaters, to self-elevate, and to load Exchange snap-in.
#>

[CmdletBinding()]
param()
#Self-elevation code.
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Relaunch as an elevated process:
    Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    exit
}
$Server = $env:COMPUTERNAME

#Loads Exchange Management Shell
. 'RemoteExchange.ps1'
Connect-ExchangeServer -auto

$DAG = Get-DatabaseAvailabilityGroup | Where-Object { $_.Servers -match $Server }

$discoveredServer = Get-ExchangeServer -Identity $Server | Select-Object IsHubTransportServer, IsFrontendTransportServer, AdminDisplayVersion

#Check for Administrative credentials
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

if ($discoveredServer.AdminDisplayVersion.Major -ne "15") {
    Write-Warning "The specified Exchange Server is not an Exchange 2013 server!"
    Write-Warning "Aborting script..."
    Break
}


Write-Host "INFO: Reactivating all server components..." -ForegroundColor Yellow
Set-ServerComponentState $server -Component ServerWideOffline -State Active -Requester Maintenance
Write-Host "INFO: Server component states changed back into active state using requester 'Maintenance'" -ForegroundColor Yellow

if ($discoveredServer.IsHubTransportServer -eq $true) {
                
    $mailboxserver = Get-MailboxServer -Identity $Server | Select-Object DatabaseAvailabilityGroup
    
    if ($null -ne $mailboxserver.DatabaseAvailabilityGroup) {
        Write-Host "INFO: Server $server is a member of a Database Availability Group. Resuming the node now." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "INFO: Node information:" -ForegroundColor Green
        Write-Host "-----------------------" -ForegroundColor Green
        Invoke-Command -ComputerName $Server -ArgumentList $Server { Resume-ClusterNode $args[0] }
        Set-MailboxServer $Server -DatabaseCopyActivationDisabledAndMoveNow $false
        Set-MailboxServer $Server -DatabaseCopyAutoActivationPolicy Unrestricted
        $DBStatus = Get-MailboxDatabaseCopyStatus
        if (!$DBStatus.ActiveCopy) {
            Write-Host "INFO: Server $Server is not hosting the active copy of the database, moving database to $Server." -ForegroundColor Yellow
            Move-ActiveMailboxDatabase $DBStatus.DatabaseName -ActivateOnServer $Server -MountDialOverride:None
        }
        Write-Host ""
        Write-Host ""
    }
    
    Write-Host "INFO: Resuming Transport Service..." -ForegroundColor Yellow
    Set-ServerComponentState –Identity $Server -Component HubTransport -State Active -Requester Maintenance

    Write-Host "INFO: Restarting the MSExchangeTransport Service on server $Server..." -ForegroundColor Yellow
    Restart-Service MSExchangeTransport

}

#restart FE Transport Services if server is also CAS
if ($discoveredServer.IsFrontendTransportServer -eq $true) {
    Write-Host "INFO: Restarting the MSExchangeFrontEndTransport Service on server $Server..." -ForegroundColor Yellow
    Restart-Service MSExchangeFrontEndTransport
}

Write-Host ""
Write-Host "INFO: Done! Server $server successfully taken out of Maintenance Mode." -ForegroundColor Green
Write-Host ""

$ComponentStates = (Get-ServerComponentstate $Server).LocalStates | Where-Object { $_.State -eq "InActive" }
if ($ComponentStates) {
    Write-Warning "There are still some components inactive on server $Server."
    Write-Warning "Some features might not work until all components are back in an Active state."
    Write-Warning "Check the information below to see what components are still in an inactive state and which requester put them in that state."
    $ComponentStates
    Clear-Variable ComponentStates
}

#Post Stop-MaintenanceMode checks.
Write-Host "CHECK: Component State" -ForegroundColor Yellow
Get-ServerComponentState -Identity $Server | Select-Object Component, State | Format-Table

Write-Host "CHECK: Database Activation Policy" -ForegroundColor Yellow
Get-MailboxServer -Identity $Server | Select-Object Name, DatabaseAvailabilityGroup, DatabaseCopyAutoActivationPolicy | Format-Table

Write-Host "CHECK: Cluster State" -ForegroundColor Yellow
Get-ClusterNode -Name $Server | Select-Object Cluster, Name, State | Format-Table

Write-Host "Check that most Components = Active, DatabaseCopyAutoActivationPolicy = Unrestricted, State = Up." -ForegroundColor Yellow
Write-Host "Waiting 30 seconds before running additional checks." -ForegroundColor Yellow

Start-Sleep -Seconds 30

Write-Host "`nCHECK: Active Database Location" -ForegroundColor Yellow
Get-MailboxDatabaseCopyStatus | Select-Object Name, ActiveDatabaseCopy, ActiveCopy, Status | Format-Table

Write-Host "CHECK: Replication Health" -ForegroundColor Yellow
Test-ReplicationHealth | Select-Object Check, CheckDescription, Result | Format-List

Write-Host "CHECK: MAPI Connectivity" -ForegroundColor Yellow
$DB = Get-MailboxDatabase | Where-Object { $_.MasterServerOrAvailabilityGroup -eq $DAG.Name }
$DBServer = $DB.ServerName
Test-MAPIConnectivity -Server $DBServer | Select-Object MailboxServer, Database, Result, Error | Format-Table

Write-Host "CHECK: Edge Synchronization" -ForegroundColor Yellow
Test-EdgeSynchronization | Select-Object Name, SyncStatus | Format-Table

Write-Host "CHECK: Service Health" -ForegroundColor Yellow
Test-ServiceHealth | Format-List

Read-Host "Script complete."