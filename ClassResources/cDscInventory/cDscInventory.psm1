<#
   This resource reads the uninstall registry keys for installed software and writes the result
   in JSON format to a custom Windows Event log intended for vRealize Log Insight to consume.
   [DscResource()] indicates the class is a DSC resource
#>

[DscResource()]
class cDscInventory {

    <#
       This property defines whether or not an inventory event exists within the specified period.

       The [DscProperty(Key)] attribute indicates the property is a
       key and its value uniquely identifies a resource instance.
       Defining this attribute also means the property is required
       and DSC will ensure a value is set before calling the resource.

       A DSC resource must define at least one key property.
    #>
    [DscProperty(Key)]
    [string] $InventoryExists
    
    <#
        Checks the Event Log to see whether a custom Event Log has been written within the
        past 24 hours.  Log Insight only looks back up to 48 hours so a new inventory is
        regularly kept.  It also helps to keep the inventory up-to-date.

        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
         properties.
    #>
    [cDscInventory] Get() {
        $source = "DSC Inventory"

        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            New-EventLog -LogName Application -Source "DSC Inventory"
        }

        $ErrorActionPreference = "Stop"
        try {
            $StartTime = (Get-Date).AddDays( -1)
            $InventoryEvents = Get-WinEvent -FilterHashtable @{
                Logname      = 'Application'
                ProviderName = 'DSC Inventory'
                Id           = '10001'
                StartTime    = $StartTime
            }
            if ($InventoryEvents.Count -ne '0') {
                return @{ 'InventoryExists' = "$true" }
            }
            else {
                return @{ 'InventoryExists' = "$false" }
            }
        }
        catch {
            throw "Error occurred.  $($PSItem.Exception.Message)"
        }
        finally {
            $ErrorActionPreference = "Continue"
        }
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>

    
    [void] Set() {
        class InventoryItem {
            [string] $SoftwareName
            [string] $Version
        }
        $source = "DSC Inventory"

        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            New-EventLog -LogName Application -Source "DSC Inventory"
        }

        #Gets installed 64-bit software.
        #Gets installed 64-bit software.
        #Excludes null DisplayVersion (Microsoft patches) and DisplayVersion 1 (Hotfixes).
        $Software = (Get-ChildItem -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall").Where{ ($null -ne $_.GetValue('DisplayVersion')) `
                -and ($_.GetValue('DisplayVersion') -ne "1") -and ($_.GetValue('DisplayName') -notlike "*Language*") -and ($_.GetValue('DisplayName') `
                    -notlike "*Hotfix*") }

        #Gets installed 32-bit software.
        $32BitSoftware = ( (Get-ChildItem -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall").Where{ ($null -ne $_.GetValue('DisplayVersion')) -and 
                ($_.GetValue('DisplayVersion') -ne "1") -and ($_.GetValue('DisplayName') -notlike "*Language*") -and ($_.GetValue('DisplayName') -notlike "*Hotfix*") } )
        foreach ($32Bit in $32BitSoftware) {
            $Software.Add($32Bit)
        }

        $Result = foreach ($obj in $Software) {
            $InventoryItem = [InventoryItem]::new()
            $InventoryItem.SoftwareName = $obj.GetValue('DisplayName')
            $InventoryItem.Version = $obj.GetValue('DisplayVersion')
            Write-Output $InventoryItem
        }

        $Data = $Result | Sort-Object -Property SoftwareName | Select-Object -Property SoftwareName, Version | ConvertTo-Json

        Write-EventLog -LogName Application -Source $source -EntryType Information -EventId 10001 -Category 0 -Message $Data
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test() {
        $source = "DSC Inventory"

        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            New-EventLog -LogName Application -Source "DSC Inventory"
        }

        $ErrorActionPreference = "SilentlyContinue"
        $StartTime = (Get-Date).AddDays( -1)
        $InventoryEvents = Get-WinEvent -FilterHashtable @{
            Logname      = 'Application'
            ProviderName = 'DSC Inventory'
            Id           = '10001'
            StartTime    = $StartTime
        }
        if ($InventoryEvents.Count -ne '0') {
            return $true
        }
        else {
            return $false
        }
        $ErrorActionPreference = "Continue"
    }

} # This module defines a class for a DSC "cDscInventory" provider.