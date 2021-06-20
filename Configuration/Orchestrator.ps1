<#
This is an orchestrator, or master configuration.  Ideally any unique configuration parameters (such as your maintenance windows)
should be set in the Configuration Data file.  Any role specific configurations should be kept in a Composite Resource (i.e. I have one for WSUS).

This file should only be edited to reference new configurations, by separating the Configuration Data and Composite Resources in this manner,
the execution flow is much cleaner and easy to see from a 1000-foot view.
#>

Configuration SetDomain {
    Import-DscResource -Module PSDesiredStateConfiguration, CompositeResources, ComputerManagementDsc, cScheduleWU, cDscInventory
    #These are base OS settings that everything should have.
    Node $AllNodes.NodeName 
    {
        Registry DirtyShutdown {
            Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability'
            ValueName = 'DirtyShutdown'
            Ensure    = 'Absent'
        }
        Registry DirtyShutdownTime {
            Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability'
            ValueName = 'DirtyShutdownTime'
            Ensure    = 'Absent'
        }
        cDiskCleanup MonthlyDiskCleanup {
            CleanupSet = $Node.CleanupSet
            SkipCleanupSet = $Node.SkipCleanupSet
            DiskCleanupDay = $Node.DiskCleanupDay
            DiskCleanupStart = $Node.DiskCleanupStart
        }
        cDscInventory MonthlySoftwareInventory {
        InventoryExists = 'False'
        }
    }
    Node $AllNodes.Where{ $_.Role -eq 'WSUS' }.NodeName 
    {
        cWSUS ConfigWSUS {
            SourcePath      = $Node.SourcePath
            DestinationPath = $Node.DestinationPath
            ContentDir      = $Node.ContentDir
        }
    }
    Node $AllNodes.Where{ $_.UpdateSchedule -eq 'Primary' }.NodeName 
    {
        $PrimaryUpdate = $ConfigurationData.PrimaryUpdate
        cScheduleWU WindowsUpdate {
            MaintenanceDay   = $Node.MaintenanceDay
            MaintenanceStart = $PrimaryUpdate.MaintenanceStart
            MaintenanceEnd   = $PrimaryUpdate.MaintenanceEnd
        }
    }
    Node $AllNodes.Where{ $_.UpdateSchedule -eq 'Secondary' }.NodeName 
    {
        $SecondaryUpdate = $ConfigurationData.SecondaryUpdate
        $NodeRole = $Node.Role
        WaitForAny WaitForPrimary {
            ResourceName     = '[cScheduleWU]WindowsUpdate'
            NodeName         = $AllNodes.Where{ ($_.Role -eq $NodeRole) -and ( $_.UpdateSchedule -eq 'Primary') }.NodeName
            RetryCount       = $SecondaryUpdate.RetryCount
            RetryIntervalSec = $SecondaryUpdate.RetryIntervalSec
        }
        cScheduleWU WindowsUpdate {
            MaintenanceDay   = $Node.MaintenanceDay
            MaintenanceStart = $SecondaryUpdate.MaintenanceStart
            MaintenanceEnd   = $SecondaryUpdate.MaintenanceEnd
            DependsOn        = '[WaitForAny]WaitForPrimary'
        }
    }
}