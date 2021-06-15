<#
.SYNOPSIS
Aggregation of built-in AD check tools (dcdiag, dfsdiag) along with commonly seen network issue checks.  Checks Domain Controller health.  Output is curated to be easier to read.

.NOTES
Original Reference Source: Adam Bertram (Microsoft MVP)
https://adamtheautomator.com/active-directory-heatlth-check-1/

Author: Herman Wong

This is intended to be run on Domain Controllers.  The original class-based calls were edited out due to 
issues using them on Windows Server 2012 R2.
#>

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Relaunch as an elevated process:
    Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    exit
}

Function Test-AdhcDCDiag {
    [cmdletbinding()]
    param(
        # Name of the DC
        [parameter(ValueFromPipeline)]
        [string]$ComputerName,

        # What DCDiag tests would you like to run?
        [ValidateSet(
            "All",
            "Advertising",
            "DNS",
            "DFSREvent",
            "NCSecDesc",
            "KccEvent",
            "Services",
            "NetLogons",
            "CrossRefValidation",
            "CheckSecurityError",
            "Intersite",
            "CheckSDRefDom",
            "Connectivity",
            "SysVolCheck",
            "Replications",
            "ObjectsReplicated",
            "DcPromo",
            "RidManager",
            "MachineAccount",
            "LocatorCheck",
            "OutboundSecureChannels",
            "RegisterInDNS",
            "VerifyEnterpriseReferences",
            "KnowsOfRoleHolders",
            "VerifyReplicas",
            "VerifyReferences"
        )]
        [string[]]$Tests = "All",

        # Excluded tests
        [ValidateSet(
            "Advertising",
            "DNS",
            "DFSREvent",
            "NCSecDesc",
            "KccEvent",
            "Services",
            "NetLogons",
            "CrossRefValidation",
            "CheckSecurityError",
            "Intersite",
            "CheckSDRefDom",
            "Connectivity",
            "SysVolCheck",
            "Replications",
            "ObjectsReplicated",
            "DcPromo",
            "RidManager",
            "MachineAccount",
            "LocatorCheck",
            "OutboundSecureChannels",
            "RegisterInDNS",
            "VerifyEnterpriseReferences",
            "KnowsOfRoleHolders",
            "VerifyReplicas",
            "VerifyReferences"
        )]
        [string[]]$ExcludedTests
        
    )
    Begin {

        $DCDiagTests = @{
            Advertising                = @{}
            CheckSDRefDom              = @{}
            CheckSecurityError         = @{
                ExtraArgs = @(
                    "/replsource:$((Get-ADDomainController -Filter *).HostName | Where-Object {$_ -notmatch $env:computername} | Get-Random)"
                )
            }
            Connectivity               = @{}
            CrossRefValidation         = @{}
            DcPromo                    = @{
                ExtraArgs = @(
                    "/ReplicaDC",
                    "/DnsDomain:$((Get-ADDomain).DNSRoot)",
                    "/ForestRoot:$((Get-ADDomain).Forest)"
                )
            }
            DNS                        = @{}
            DFSREvent                  = @{}
            SysVolCheck                = @{}
            LocatorCheck               = @{}
            Intersite                  = @{}
            KccEvent                   = @{}
            KnowsOfRoleHolders         = @{}
            MachineAccount             = @{}
            NCSecDesc                  = @{}
            NetLogons                  = @{}
            ObjectsReplicated          = @{}
            OutboundSecureChannels     = @{}
            RegisterInDNS              = @{
                ExtraArgs = "/DnsDomain:$((Get-ADDomain).DNSRoot)"
            }
            Replications               = @{}
            RidManager                 = @{}
            Services                   = @{}
            VerifyEnterpriseReferences = @{}
            VerifyReferences           = @{}
            VerifyReplicas             = @{}
        }

        $TestsToRun = $DCDiagTests.Keys | Where-Object { $_ -notin $ExcludedTests }

        If ($Tests -ne 'All') {
            $TestsToRun = $Tests
        }
        
        if (($Tests | Measure-Object).Count -gt 1 -and $Tests -contains "All") {
            Write-Error "Invalid Tests parameter value: You can't use 'All' with other tests." -ErrorAction Stop
        }

        Write-Verbose "Executing tests: $($DCDiagTests.Keys -join ", ")"
    }
    Process {
        if (![string]::IsNullOrEmpty($ComputerName)) {
            $ServerArg = "/s:$ComputerName"
        }
        else {
            $ComputerName = $env:COMPUTERNAME
            $ServerArg = "/s:$env:COMPUTERNAME"
        }
        
        Write-Host -f Yellow "Starting DCDiag tests on $ComputerName"

        $TestsToRun | ForEach-Object {

            $TestName = $_
            $ExtraArgs = $DCDiagTests[$_].ExtraArgs

            
            if ($_ -in @("DcPromo", "RegisterInDNS")) {
                if ($env:COMPUTERNAME -ne $ComputerName) {

                    Write-Verbose "Test cannot be performed remote, invoking dcdiag"
                    $Output = Invoke-Command -ComputerName $ComputerName -ArgumentList @($TestName, $ExtraArgs) -ScriptBlock {
                        $TestName = $args[0]
                        $ExtraArgs = $args[1]
                        dcdiag /test:$TestName $ExtraArgs
                    }
                }
                else {
                    $Output = dcdiag /test:$TestName $ExtraArgs
                }
            }
            else {
                $Output = dcdiag /test:$TestName $ExtraArgs $ServerArg    
            }
            

            $Fails = ($Output | Select-String -AllMatches -Pattern "fail" | Measure-Object).Count
            $Passes = ($Output | Select-String -AllMatches -Pattern "passed" | Measure-Object).Count 
            $Pass = ($Fails -eq 0 -and $Passes -gt 0)
            $PassValue = @()
            $Color = @()
            if ($Pass) {
                $PassValue = "Passed"
                $Color = "Green"
            }
            else {
                $PassValue = "Failed"
                $Color = "Red"
            }
            Write-Host "The DcDiag test $Testname has " -nonewline
            Write-Host "$PassValue" -f $Color -NoNewline
            Write-Host " with $Fails fails and $Passes passes."
        }
    }
    End {

    }
}

#DCDiag tests.
Test-AdhcDCDiag -ComputerName $env:COMPUTERNAME
Write-Host -f Yellow "`nDCDiag tests completed, if you see a failure run 'dcdiag /test:<testname>' to get more information on the failed test."
Write-Host "`n**********************************************************************"

$LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$Date = Get-Date
$BootSpan = (New-TimeSpan -Start $LastBoot -End $Date).days
$BootColor = @()
if ($BootSpan -lt 2) {
    $BootColor = "Red"
}
else {
    $BootColor = "Green"
}
Write-Host "`nThis DC last booted " -NoNewline
Write-Host -f $BootColor "$BootSpan days" -NoNewline
Write-Host " ago.  Some tests that check the Event Log such as DFSREvent may fail when a DC is rebooted within the past 48 hours."

#Tests observed to have failed when a DC is offline: DNS, CheckSecurityError, Replications, DFSREvent.
#Tests that were observed to have hung tests when DC is offline have been removed.
#Removed tests: CutoffServers, Topology.
#Tests that still fail after recent DC shutdown: Replications, DFSREvent.

Write-Host "`n**********************************************************************"

#DFSR Tests
Write-Host -f Yellow "`nRunning DFSR Tests."
$CimDfs = Get-CimInstance -Namespace 'root/MicrosoftDfs' -Classname 'DfsrReplicatedFolderInfo'
$DfsState = @()
switch ($CimDfs.State) {
    0 { $DfsState = 'Uninitiated' }
    1 { $DfsState = 'Initiated' }
    2 { $DfsState = 'Initial Sync' }
    3 { $DfsState = 'Auto Recovery' }
    4 { $DfsState = 'Normal' }
    5 { $DfsState = 'In Error' }
}
$DfsStateColor = @()
if ($DfsState -eq 'Normal') {
    $DfsStateColor = 'Green'
}
else {
    $DfsStateColor = 'Red'
}

Write-Host "`nReplicated Folder Name: $($CimDfs.ReplicatedFolderName)"
Write-Host "State:" -NoNewline; Write-Host -f $DfsStateColor "$DfsState"

Write-Host "`n"

Start-Process -FilePath 'dfsdiag.exe' -ArgumentList '/TestDCs' -NoNewWindow -Wait

Write-Host "`n**********************************************************************"


#Network profile check.
Write-Host -f Yellow "`nRunning checks on network connection profiles."
$Networks = Get-NetConnectionProfile
$NetprofileTest = $true
$BadNIC = @()
$BadNetCategory = @()
foreach ($Network in $Networks) {
    if ($Network.NetworkCategory -ne 'DomainAuthenticated') {
        $NetprofileTest = $false
        $BadNIC = $Network.InterfaceAlias
        $BadNetCategory = $Network.NetworkCategory
        Write-Host -f Yellow "`nThe network profile test has " -NoNewline
        Write-Host -f Red "Failed"
        Write-Host -f Yellow "The failed adapter is $BadNIC with a profile of $BadNetCategory."
        Write-Host -f Yellow "The network category of all adapters should be 'DomainAuthenticated'."
        Write-Host -f Yellow "Try restarting the Network Location Awareness service."
    }
}
if ($NetprofileTest) {
    Write-Host -f Yellow "`nThe network profile test has " -NoNewline
    Write-Host -f Green "Passed"
}

Write-Host "`n**********************************************************************"

#AD Replication Failure check
Write-Host -f Yellow "`nRunning AD Replication Failure check."
$Domain = (Get-ADDomain).DNSRoot
try {
    $ADReplError = $null
    $ADReplFail = (Get-ADReplicationFailure -Target $Domain -Scope Domain -ErrorAction Stop -ErrorVariable $ADReplError).FailureCount
    if (($ADReplFail -eq 0) -and ($null -eq $ADReplError)) {
        Write-Host -f Yellow "`nAD Replication Failure test " -NoNewline
        Write-Host -f Green "Passed"
    }
    else {
        Write-Host -f Yellow "`nAD Replication Failure test " -NoNewline
        Write-Host -f Red "Failed"
        Write-Host -f Yellow "`nCheck if a DC is currently offline or is having network issues."
        Write-Host -f Yellow "This may also show a failure if a DC was off or restarting during replication recently."
    }
}
catch {
    Write-Host -f Yellow "`nAD Replication Failure test " -NoNewline
    Write-Host -f Red "Failed"
    Write-Host -f Yellow "`nCheck if a DC is currently offline or is having network issues."
    Write-Host -f Yellow "This may also show a failure if a DC was off or restarting during replication recently."
}

Write-Host "`n**********************************************************************"

#Ping Test with other DCs
Write-Host -f Yellow "`nPinging every NIC on the other Domain Controllers."
$DCs = Get-ADDomainController -Filter { Name -ne "$env:COMPUTERNAME" }
$DCDnsRecords = @()
$PingResults = @()
foreach ($DC in $DCs) {
    $DCDnsRecords += Resolve-DnsName -Name $DC -NoHostsFile
}
foreach ($DCDnsRecord in $DCDnsRecords) {
    $PingResults += [PSCustomObject]@{
        Computer      = $DCDnsRecord.name
        IpAddress     = $DCDnsRecord.IpAddress
        PingSucceeded = Test-NetConnection -ComputerName $DCDnsRecord.IpAddress -InformationLevel Quiet
    }
}
foreach ($PingResult in $PingResults) {
    $PingResultColor = @()
    if ($PingResult.PingSucceeded) {
        $PingResultColor = "Green"
    }
    else {
        $PingResultColor = "Red"
    }
    Write-Host "`nPing $($PingResult.Computer) $($PingResult.IpAddress) " -NoNewLine
    Write-Host -f $PingResultColor "$($PingResult.PingSucceeded)"
}

Write-Host "`n**********************************************************************"

Read-Host -Prompt "`nScripted check completed, please review the results."