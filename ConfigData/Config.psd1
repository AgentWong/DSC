@{
    AllNodes = 
    @(
        @{
            NodeName = '*'
            MaintenanceDay = 'Tuesday'
        }
        @{
            NodeName = 'EDEN-WSUS-01'
            Role     = 'WSUS'
            UpdateSchedule = 'Primary'
            SourcePath      = '\\FILESHARE\Share\Software\Scripts'
            DestinationPath = 'C:\Scripts'
        }
    );
    PrimaryUpdate =
    @{
        MaintenanceStart = '17:00'
        MaintenanceEnd = '23:00'
    }
    SecondaryUpdate =
    @{
        MaintenanceStart = '18:00'
        MaintenanceEnd = '22:00'
    }
}