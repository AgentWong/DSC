Configuration cDiskCleanup {
    $Reg2Set = @('Active Setup Temp Folders', 'Delivery Optimization Files', 'Diagnostic Data Viewer database files', 'Old ChkDsk Files', 'Service Pack Cleanup', 'Setup Log Files'`
            , 'System error memory dump files', 'System error minidump files', 'Temporary Files', 'Update Cleanup', 'Windows Error Reporting Files')
    $Reg0Set = @('Downloaded Program Files', 'D3D Shader Cache', 'DownloadsFolder', 'Internet Cache Files', 'Recycle Bin', 'Thumbnail Cache')
    $Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'

    Import-DscResource -ModuleName PSDesiredStateConfiguration, ComputerManagementDsc
    
    foreach ($Reg2 in $Reg2Set) {
        Registry $Reg2 {
            Key       = "$Path\$Reg2"
            ValueName = 'StateFlags0001'
            ValueType = 'Dword'
            ValueData = '2'
            Ensure    = 'Present'
            Force     = $true
        }
    }
    foreach ($Reg0 in $Reg0Set) {
        Registry $Reg0 {
            Key       = "$Path\$Reg0"
            ValueName = 'StateFlags0001'
            ValueType = 'Dword'
            ValueData = '0'
            Ensure    = 'Present'
            Force     = $true
        }
    }
    ScheduledTask RunDiskCleanup {
        TaskName           = 'Monthly Disk Cleanup'
        ActionExecutable   = 'C:\Windows\System32\cleanmgr.exe'
        ActionArguments    = '/sagerun:1'
        BuiltInAccount     = 'SYSTEM'
        ScheduleType       = 'Weekly'
        DaysOfWeek         = 'Sunday'
        WeeksInterval      = '4'
        ExecutionTimeLimit = '02:00:00'
        Enable             = $true
        RandomDelay        = '01:00:00'
        RunLevel           = 'Highest'
        RunOnlyIfIdle      = $false
        Priority           = 7
        Ensure             = 'Present'
    }
}
