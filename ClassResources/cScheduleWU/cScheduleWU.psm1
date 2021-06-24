<#
   This resource will run Windows Update within a specified maintenance window.
   [DscResource()] indicates the class is a DSC resource
#>

enum MaintenanceDay {
    Sunday
    Monday
    Tuesday
    Wednesday
    Thursday
    Friday
    Saturday
}

[DscResource()]
class cScheduleWU {
    <#
       This property is a specified day when patching can occur.

       The [DscProperty(Key)] attribute indicates the property is a
       key and its value uniquely identifies a resource instance.
       Defining this attribute also means the property is required
       and DSC will ensure a value is set before calling the resource.

       A DSC resource must define at least one key property.
    #>
    [DscProperty(Mandatory)]
    [MaintenanceDay]$MaintenanceDay

    <#
       This property defines the start time (local computer time) when the maintenance window begins.

       NOTE: This property is required because [DscProperty(Mandatory)] is
        set.
    #>
    [DscProperty(Key)]
    [string] $MaintenanceStart

    <#
       This property defines the end time (local computer time) when the maintenance window ends.
    #>
    [DscProperty(Mandatory)]
    [string] $MaintenanceEnd

    <#
    [DscProperty(NotConfigurable)] attribute indicates the property is
       not configurable in DSC configuration.  Properties marked this way
       are populated by the Get() method to report additional details
       about the resource when it is present.
    #>
    [DscProperty(NotConfigurable)]
    [bool] $InMaintenanceWindow

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
         properties.
    #>
    [cScheduleWU] Get() {
        $Min = Get-Date $this.MaintenanceStart
        $Max = Get-Date $this.MaintenanceEnd
        $Now = Get-Date
        if (($Now.DayOfWeek -eq $this.MaintenanceDay) -and ($Min.TimeOfDay -le $Now.TimeOfDay) -and `
            ($Max.TimeOfDay -ge $Now.TimeOfDay)) {
            return @{ 'InMaintenanceWindow' = $true }
        }
        else {
            return @{ 'InMaintenanceWindow' = $false }
        }
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set() {
        try {
            $Updates = Start-WUScan -SearchCriteria 'IsInstalled=0 AND IsHidden=0 AND IsAssigned=1' -ErrorAction 'Stop'
            Write-Verbose "Starting patch installation."
            Install-WUUpdates -Updates $Updates -ErrorAction 'Stop'
            if (Get-WUIsPendingReboot) {
                $global:DSCMachineStatus = '1'
                Write-Verbose "Patches applied, setting DSC Reboot Needed flag to $global:DSCMachineStatus to trigger a restart."
            }
        }
        catch {
            Write-Verbose 'Error occurred running Set().'
            Write-Error $_.Exception
            Write-Debug $_
        }
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test() {
        $Min = Get-Date $this.MaintenanceStart
        $Max = Get-Date $this.MaintenanceEnd
        $Now = Get-Date
        Write-Verbose "Checking if it is within the specified maintenance window of $($this.MaintenanceDay), starting at $($this.MaintenanceStart),`
        ending at $($this.MaintenanceEnd)."
        if (($Now.DayOfWeek -eq $this.MaintenanceDay) -and ($Min.TimeOfDay -le $Now.TimeOfDay) -and `
            ($Max.TimeOfDay -ge $Now.TimeOfDay)) {
            $Updates = @()
            try {
                Write-Verbose "It is within the specified maintenance window, starting a check for updates."
                $Updates = Start-WUScan -SearchCriteria 'IsInstalled=0 AND IsHidden=0 AND IsAssigned=1' -ErrorAction 'Stop'
            }
            catch {
                Write-Verbose 'Error occurred running Test().'
                Write-Error $_.Exception
                Write-Debug $_
            }
            Start-Process -FilePath 'wuauclt.exe' -ArgumentList '/reportnow'
            if ($Updates.Count -eq '0') {
                Write-Verbose "No pending updates, resource is in the desired state."
                return $true
            }
            else {
                Write-Verbose "Pending updates found, resource is not in the desired state."
                return $false
            }
        }
        else {
            Write-Verbose "It is not within the specified maintenance window, no action will be taken outside the maintenance window."
            return $true
        }
    }

    
} # This module defines a class for a DSC "cScheduleWU" provider.