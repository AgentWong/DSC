<#
   This resource manages the file in a specific path.
   [DscResource()] indicates the class is a DSC resource
#>

[DscResource()]
class cDscInventory {
    <#
       This property is a specified number of days to look for an inventory event.

       The [DscProperty(Key)] attribute indicates the property is a
       key and its value uniquely identifies a resource instance.
       Defining this attribute also means the property is required
       and DSC will ensure a value is set before calling the resource.

       A DSC resource must define at least one key property.
    #>
    [DscProperty(Key)]
    [int] $DaysToCheck

    <#
       This property defines whether or not an inventory event exists within the specified period.

       [DscProperty(NotConfigurable)] attribute indicates the property is
       not configurable in DSC configuration.  Properties marked this way
       are populated by the Get() method to report additional details
       about the resource when it is present.

    #>
    [DscProperty(NotConfigurable)]
    [bool] $InventoryExists
    
    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
         properties.
    #>
    [cDscInventory] Get() {
        $StartTime = (Get-Date).AddDays(-($this.DaysToCheck))
        $InventoryEvents = Get-WinEvent -FilterHashtable @{
            Logname      = 'Application'
            ProviderName = 'DSC Inventory'
            StartTime    = $StartTime
        }
        if($InventoryEvents.Count -ne '0'){
            return @{ 'InventoryExists' = "$true" }
        }
        else{
            return @{ 'InventoryExists' = "$false" }
        }
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>

    
    [void] Set() {
        $source = "DSC Inventory"

        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            New-EventLog -LogName Application -Source "DSC Inventory"
        }
        $Computer = $env:ComputerName

        #Gets installed 64-bit software.
        #Excludes null DisplayVersion (Microsoft patches) and DisplayVersion 1 (Hotfixes).
        $Software = Get-ChildItem -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" | Where-Object { ($null -ne $_.GetValue('DisplayVersion')) -and 
            ($_.GetValue('DisplayVersion') -ne "1") -and ($_.GetValue('DisplayName') -notlike "*Language*") -and ($_.GetValue('DisplayName') -notlike "*Hotfix*") }

        #Gets installed 32-bit software.
        $Software += Get-ChildItem -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | Where-Object { ($null -ne $_.GetValue('DisplayVersion')) -and 
            ($_.GetValue('DisplayVersion') -ne "1") -and ($_.GetValue('DisplayName') -notlike "*Language*") -and ($_.GetValue('DisplayName') -notlike "*Hotfix*") }

        $Result = foreach ($obj in $Software) {
            [PSCustomObject]@{
                Computer     = $Computer
                SoftwareName = $obj.GetValue('DisplayName')
                Version      = $obj.GetValue('DisplayVersion')
            }
        }

        $Data = $Result | Sort-Object -Property SoftwareName | Select-Object -Property Computer, SoftwareName, Version | ConvertTo-Csv -NoTypeInformation

        Write-EventLog -LogName Application -Source $source -EntryType Information -EventId 12345 -Category 0 -Message $data
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test() {
        $StartTime = (Get-Date).AddDays(-1)
        $InventoryEvents = Get-WinEvent -FilterHashtable @{
            Logname      = 'Application'
            ProviderName = 'DSC Inventory'
            StartTime    = $StartTime
        }
        if($InventoryEvents.Count -ne '0'){
            return $true
        }
        else{
            return $false
        }
    }

} # This module defines a class for a DSC "cDscInventory" provider.