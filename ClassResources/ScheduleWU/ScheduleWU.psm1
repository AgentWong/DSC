enum Ensure {
    Absent
    Present
}

<#
   This resource manages the file in a specific path.
   [DscResource()] indicates the class is a DSC resource
#>

[DscResource()]
class ScheduleWU {
    <#
       This property is a specified day when patching can occur.

       The [DscProperty(Key)] attribute indicates the property is a
       key and its value uniquely identifies a resource instance.
       Defining this attribute also means the property is required
       and DSC will ensure a value is set before calling the resource.

       A DSC resource must define at least one key property.
    #>
    [DscProperty(Mandatory)]
    [string]$MaintenanceDay

    <#
       This property defines the start time in UTC when the maintenance window begins.

       NOTE: This property is required because [DscProperty(Mandatory)] is
        set.
    #>
    [DscProperty(Key)]
    [string] $MaintenanceStart

    <#
       This property defines the end time in UTC when the maintenance window ends.

       [DscProperty(NotConfigurable)] attribute indicates the property is
       not configurable in DSC configuration.  Properties marked this way
       are populated by the Get() method to report additional details
       about the resource when it is present.

    #>
    [DscProperty(Mandatory)]
    [string] $MaintenanceEnd

    [DscProperty(NotConfigurable)]
    [bool] $Result

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set() {
        $Updates = Start-WUScan -SearchCriteria "IsInstalled=0 AND IsHidden=0 AND IsAssigned=1"
        Install-WUUpdates -Updates $Updates
        if (Get-WUIsPendingReboot) {
            $global:DSCMachineStatus = '1'
            Write-Verbose "Setting DSC Reboot Needed flag to $global:DSCMachineStatus."
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
        if (($Now.DayOfWeek -eq $this.MaintenanceDay) -and ($Min.TimeOfDay -le $Now.TimeOfDay) -and `
            ($Max.TimeOfDay -ge $Now.TimeOfDay)) {
            $Updates = Start-WUScan -SearchCriteria "IsInstalled=0 AND IsHidden=0 AND IsAssigned=1"
            if ($Updates.Count -eq '0') {
                return $true
            }
            else {
                return $false
            }
        }
        else {
            return $true
        }
    }

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
         properties.
    #>
    [ScheduleWU] Get() {
        $Min = Get-Date $this.MaintenanceStart
        $Max = Get-Date $this.MaintenanceEnd
        $Now = Get-Date
        if (($Now.DayOfWeek -eq $this.MaintenanceDay) -and ($Min.TimeOfDay -le $Now.TimeOfDay) -and `
            ($Max.TimeOfDay -ge $Now.TimeOfDay)) {
            return @{ 'Result' = $false }
        }
        else {
            return @{ 'Result' = $true }
        }
    }
} # This module defines a class for a DSC "FileResource" provider.