@{
    AllNodes = 
    @(
        @{
            NodeName = '*'
            MaintenanceDay = 'Saturday'
            CleanupSet = @('Active Setup Temp Folders', 'Delivery Optimization Files', 'Diagnostic Data Viewer database files', 'Old ChkDsk Files', 'Service Pack Cleanup', 'Setup Log Files'`
            , 'System error memory dump files', 'System error minidump files', 'Temporary Files', 'Update Cleanup', 'Windows Error Reporting Files')
            SkipCleanupSet = @('Downloaded Program Files', 'D3D Shader Cache', 'DownloadsFolder', 'Internet Cache Files', 'Recycle Bin', 'Thumbnail Cache')
            DiskCleanupDay = 'Sunday'
            DiskCleanupStart = '20:00:00'
        }
        @{
            NodeName = 'EDEN-WSUS-01'
            Role     = 'WSUS'
            UpdateSchedule = 'Primary'
        }
        @{
            NodeName = 'EDEN-DC-01'
            Role = 'Domain Controller'
            UpdateSchedule = 'Primary'
        }
        @{
            NodeName = 'EDEN-DC-02'
            Role = 'Domain Controller'
            UpdateSchedule = 'Secondary'
        }
        @{
            NodeName = 'EDEN-DSC-01'
            UpdateSchedule = 'Primary'
        }
        @{
            NodeName = 'EDEN-WAC-01'
            UpdateSchedule = 'Primary'
        }
        @{
            NodeName = 'EDEN-SQL-01'
            UpdateSchedule = 'Primary'
        }
    );
    PrimaryUpdate =
    @{
        MaintenanceStart = '19:00'
        MaintenanceEnd = '23:59'
    }
    SecondaryUpdate =
    @{
        MaintenanceStart = '20:00'
        MaintenanceEnd = '23:00'
        RetryCount = '23'
        RetryIntervalSec = '900'
    }
}