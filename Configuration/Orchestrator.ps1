Configuration SetDomain {
    Import-DscResource -Module PSDesiredStateConfiguration, CompositeResources, ComputerManagementDsc, cScheduleWU
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
            ResourceName     = '[ScheduleWU]WindowsUpdate'
            NodeName         = $AllNodes.Where{ ($_.Role -eq $NodeRole) -and ( $_.UpdateSchedule -eq 'Primary') }.NodeName
            RetryCount       = '23'
            RetryIntervalSec = '900'
        }
        cScheduleWU WindowsUpdate {
            MaintenanceDay   = $Node.MaintenanceDay
            MaintenanceStart = $SecondaryUpdate.MaintenanceStart
            MaintenanceEnd   = $SecondaryUpdate.MaintenanceEnd
        }
    }
}