@{
    AllNodes = 
    @(
        @{
            NodeName = '*'
            MaintenanceDay = 'Tuesday'
        }
        @{
            NodeName = 'WSUS'
            Role     = 'WSUS'
            UpdateSchedule = 'Primary'
            SourcePath      = '\\ds\Software\Scripts'
            DestinationPath = 'G:\Scripts'
        }
    );
    PrimaryUpdate =
    @{
        MaintenanceStart = Get-Date '17:00'
        MaintenanceEnd = Get-Date '21:00'
    }
    SecondaryUpdate =
    @{
        MaintenanceStart = Get-Date '18:00'
        MaintenanceEnd = Get-Date '22:00'
    }
}