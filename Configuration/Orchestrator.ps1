Configuration SetDomain {
    Import-DscResource -Module PSDesiredStateConfiguration, CompositeResources, ComputerManagementDsc, ScheduleWU
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
        cDiskCleanup MonthlyDiskCleanup {}
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
        ScheduleWU WindowsUpdate {
            MaintenanceDay   = $Node.MaintenanceDay
            MaintenanceStart = $ConfigurationData.PrimaryUpdate.MaintenanceStart
            MaintenanceEnd   = $ConfigurationData.PrimaryUpdate.MaintenanceEnd
        }
        PendingReboot WindowsUpdateReboot {
            Name      = 'WindowsUpdateReboot'
            DependsOn = '[ScheduleWU]WindowsUpdate'
        }
    }
    Node $AllNodes.Where{ $_.UpdateSchedule -eq 'Secondary' }.NodeName 
    {
        $NodeRole = $Node.Role
        WaitForAny WaitForPrimary {
            ResourceName     = '[ScheduleWU]WindowsUpdate'
            NodeName         = $AllNodes.Where{ ($_.Role -eq $NodeRole) -and ( $_.UpdateSchedule -eq 'Primary') }.NodeName
            RetryCount       = '23'
            RetryIntervalSec = '900'
        }
        ScheduleWU WindowsUpdate {
            MaintenanceDay   = $Node.MaintenanceDay
            MaintenanceStart = $ConfigurationData.SecondaryUpdate.MaintenanceStart
            MaintenanceEnd   = $ConfigurationData.SecondaryUpdate.MaintenanceEnd
        }
        PendingReboot WindowsUpdateReboot {
            Name      = 'WindowsUpdateReboot'
            DependsOn = '[ScheduleWU]WindowsUpdate'
        }
    }
}