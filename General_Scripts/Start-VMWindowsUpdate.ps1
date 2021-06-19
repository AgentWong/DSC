<#
.SYNOPSIS
Triggers pending Windows Updates on Windows 10 virtual machines as of 1607, may need to be changed to use MSFT_WUOPerations CimClass after a feature upgrade to a new version.

.NOTES
Author: Herman Wong

Prerequisites:
VMWare Powercli

This should need a different list and credential set for SA/DA (DC and Exchange) and standalone machines.  Domain joined computers require the domain name and a backslash before
the username (ex: Microsoft\ladmin)
#>

function Show-Menu
{
    param (
        [string]$Title = 'Input Files',
        [string[]]$FilePaths
    )
    #Enumerates all files in the filepath and list each filename for the user to select an input file.
    Clear-Host
    Write-Host "================ $Title ================"
    Write-Host "Choose a file with computers you want to run this script against."
    foreach($Path in $FilePaths){
    $Index = ([array]::IndexOf($FilePaths, $Path)) + 1
        Write-Host $Index : $Path
    }
}
function Get-InputFiles{
    param(
        [string]$FilePath
    )
    #This constructs a switch statement using variables as a string, then executes the switch statement.
    #By constructing the statement as a string, it is effectively dynamically building the switch statement based on
    #the number of files in a folder.
    [string[]]$Paths = Get-ChildItem -Path $FilePath\Input -File | Select-Object -ExpandProperty Name
    Show-Menu -FilePaths $Paths
    $Selection = Read-Host "Please choose an input file to use."
    $switch = 'switch($Selection){'

    for($i=1;$i -le $Paths.length; $i++)
    {
        $switch += "`n`t$i { '$($Paths[$i-1])'; break }" 
    }
    $switch += "default { Write-Warning 'Entry out of range or empty, exiting script.'; Start-Sleep -Seconds 10; Exit }"
    $switch += "`n}"

    #Just here to avoid annoying PSScriptAnalyzer warnings.
    $Selection | Out-Null

    $Choice = Invoke-Expression $switch
    $HostVMComputers = Get-Content "$FilePath\Input\$Choice"
    Write-Host "You chose $Choice."
    Write-Output $HostVMComputers
}

function Test-Cred {
    #This function will test your domain credentials so your account doesn't get locked out if you mistyped your password.
    [CmdletBinding()]
    [OutputType([String])] 
       
    Param ( 
        [Parameter( 
            Mandatory = $false, 
            ValueFromPipeLine = $true, 
            ValueFromPipelineByPropertyName = $true
        )] 
        [Alias( 
            'PSCredential'
        )] 
        [ValidateNotNull()] 
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()] 
        $Credentials
    )
    $Domain = $null
    $Root = $null
    $Username = $null
    $Password = $null
      
    If($Credentials -eq $null)
    {
        Try
        {
            $Credentials = Get-Credential "domain\$env:username" -ErrorAction Stop
        }
        Catch
        {
            $ErrorMsg = $_.Exception.Message
            Write-Warning "Failed to validate credentials: $ErrorMsg "
            Pause
            Break
        }
    }
      
    # Checking module
    Try
    {
        # Split username and password
        $Username = $credentials.username
        $Password = $credentials.GetNetworkCredential().password
  
        # Get Domain
        $Root = "LDAP://" + ([ADSI]'').distinguishedName
        $Domain = New-Object System.DirectoryServices.DirectoryEntry($Root,$UserName,$Password)
    }
    Catch
    {
        $_.Exception.Message
        Continue
    }
  
    If(!$domain)
    {
        Write-Warning "Something went wrong"
    }
    Else
    {
        If ($null -ne $domain.name)
        {
            return "Authenticated"
        }
        Else
        {
            return "Not authenticated"
        }
    }
}

Function Start-VMScript{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string[]] $VMComputers,
        [Parameter( 
            Mandatory = $false, 
            ValueFromPipeLine = $true, 
            ValueFromPipelineByPropertyName = $true
        )] 
        [Alias( 
            'PSCredential'
        )] 
        [ValidateNotNull()] 
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()] 
        $Credentials,
        [Parameter()]
        [string] $VCServer,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,500)]
        [int]$MaxJobs = 5
    )
    Begin{
    #Place initial parameters here.
    $Count = $VMComputers.Count
    $JobCount = 0
    $Completed = 0
    $Jobs = @()
    $Start = Get-Date

    #If the newest job runs longer than this value in minutes, exit the script.
    $Timeout = 60

#Powershell scripttext to run using Here-String to pass an entire script through to the VM.
#Scripttext for Windows Server 2012 R2
$Win2012R2Update= @'
$Criteria = "IsInstalled=0 and Type='Software'"

$Searcher = New-Object -ComObject Microsoft.Update.Searcher

$SearchResult = $Searcher.Search($Criteria).Updates
$Session = New-Object -ComObject Microsoft.Update.Session

$Downloader = $Session.CreateUpdateDownloader()
$Downloader.Updates = $SearchResult
$Downloader.Download()

$Installer = New-Object -ComObject Microsoft.Update.Installer
$Installer.Updates = $SearchResult
$Result = $Installer.Install()
If ($Result.rebootRequired) { Restart-Computer -Force }
'@

#Scripttext for Windows 10 1607
$Win10Update = @'
$Updater = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -Classname MSFT_WUOperationsSession
Invoke-CimMethod -MethodName ScanForUpdates -Arguments @{SearchCriteria="IsInstalled=0";OnlineScan=$true} -InputObject $Updater
Invoke-CimMethod -MethodName ApplyApplicableUpdates -InputObject $Updater

$RebootPending = $null -ne (Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction Ignore)
$RebootRequired = $null -ne (Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction Ignore)

if($RebootPending -or $RebootRequired){
    $RebootPendingResult = $true
}
else{
    $RebootPendingResult = $false
}
if($RebootPendingResult){
    Restart-Computer -Force
}
'@
#IMPORTANT!  Due to a quirk in Powershell formatting, all scripttext should NOT be indented or else the script will break!

    }
    Process{
    $VIConnected = Connect-VIServer -Server $VCServer

    if($null -ne $VIConnected)
    {
        ForEach( $VMComputer in $VMComputers)
        {
            $Check = $false
            #Infinite loop until all computers listed have running jobs.
            while($Check -eq $false){
                $JobCount = ($Jobs | Where-Object { $_.State -eq 'Running' } | Measure-Object ).Count
                if ($JobCount -lt $MaxJobs) {
                    $CurrentCount = $JobCount + 1
                    $OS = Get-VM -Name $VMComputer
                    Write-Host "Running script on $VMComputer with $CurrentCount Jobs Running."

                    #Checks OS name and runs different patch commands depending on which one it is.
                    if($OS.Guest -like "*Windows 10*"){
                        $Jobs += Invoke-VMScript -ScriptText $Win10Update -VM $VMComputer -GuestCredential $Credentials -RunAsync
                    }
                    elseif($OS.Guest -like "*Windows Server 2012*"){
                        $Jobs += Invoke-VMScript -ScriptText $Win2012R2Update -VM $VMComputer -GuestCredential $Credentials -RunAsync
                    }
                    $Completed = ($Jobs | Where-Object { $_.State -eq 'Success' }).Count
                    Write-Progress -Activity "Running script against computers." -PercentComplete (($Completed / $Count) * 100)
                    Start-Sleep -Milliseconds 1000
                    $Check = $true
                }
            }
        }
        #Gets the latest running job by its StartTime property.
        $LatestJob = $Jobs | Sort-Object -Property StartTime -Descending | Select-Object -First 1

        Write-Host "Waiting for jobs to finish."
        #Loop until tasks are complete.
        while($Jobs.State -contains 'Running'){
            #Shows progress of the running tasks.
            $Completed = ($Jobs.State | Where-Object { $_ -eq 'Success' }).Count
            Write-Progress -Activity "Running script against computers." -PercentComplete (($Completed / $Count) * 100)
            Start-Sleep -Milliseconds 1000

            #If the latest job to run exceeds the set timeout value, the script will exit.  Intended to prevent hung jobs.
            $TimeoutStatus = (New-TimeSpan -Start $LatestJob.StartTime).TotalMinutes -ge $Timeout
            if( $TimeoutStatus ){
                $End = Get-Date
                Write-Warning "The script started at $Start, the script terminated at $End, the latest job started at $($LatestJob.StartTime)."
                Write-Warning "The last job to run has exceeded the set timeout of $Timeout minutes.  The script will now exit."
                Read-Host "Press enter to continue."
                Exit
            }
        }

        
    }
    else{
        Write-Warning "Failed to connect to vCenter server."
    }
    }
    End{
        Disconnect-VIServer -Confirm:$false -Force
    }
}



#######Script Execution######

#Gets the directory the script is currently executing from.
$Path = Split-Path $MyInvocation.MyCommand.Path -Parent

#Checks to see whether there is an "Input" folder where the script was run from and whether there are files in them.
if($null -ne (Get-ChildItem -Path $Path\Input)){
    #Lists the files in the folder and asks user to select one.
    $HostVMComputers = Get-InputFiles -FilePath $Path
}
else{
    Write-Warning "Input file not found, script needs an Input folder with a Computers.txt file containing the VM names you want to run against."
    Write-Warning "Example: C:\Scripts\Input\Computers.txt"
    Read-Host "Press enter to continue."
    Exit
}

#Import-Module required to use Invoke-VMScript.
Import-Module Vmware.PowerCLI

#Prompt for Credentials.
$HostCreds = Get-Credential -Message "Enter in your Credentials to login to the computers."
if($null -eq $HostCreds){
    Write-Warning "You did not enter any credentials, exiting script..."
    Read-Host "Press enter to continue."
    Exit
}

#Checks for domain credentials by looking for a backslash, then validates it.
#Otherwise if it doesn't have a backslash it will skip the validation.
if($Creds.UserName -match "\\"){
    $Auth = Test-Cred $HostCreds
}
else{
    $Auth = "Authenticated"
}
if($Auth -eq "Authenticated")
{
$HostVCServer = Read-Host -Prompt "Enter in the IP Address or hostname of the vCenter server."

#Run Powershell script against VMs, use MaxJobs parameter to adjust the number of concurrent jobs.
Start-VMScript -VMComputers $HostVMComputers -VCServer $HostVCServer -Credentials $HostCreds -MaxJobs 5
}
else{
    Write-Warning "Incorrect/missing username or password."
}

Read-Host "Script complete!  Press enter to continue."