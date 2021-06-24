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
            ContentDir = 'F:\WSUS'
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
            NodeName = 'EDEN-FS-01'
        }
        @{
            NodeName = 'EDEN-FS-02'
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
    WSUS            = 
    @{
        Classifications = @('E6CF1350-C01B-414D-A61F-263D14D133B4', '0FA1201D-4330-4FA8-8AE9-B877473B6441', 'B4832BD8-E735-4761-8DAF-37F882276DAB', `
                '28BC880E-0592-4CBF-8F95-C79B17911D5F', 'CD5FFD1E-E932-4E3A-BF74-18BF0B1BBD83')
        Products        = @('Microsoft SQL Server 2019', 'Microsoft SQL Server Management Studio v18', 'Windows 10, version 1903 and later', 'Windows Admin Center', `
                'Windows Admin Center', 'Windows Server 2019')
    }
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