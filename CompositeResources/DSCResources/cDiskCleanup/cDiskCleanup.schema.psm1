<#
This configuration defines the settings for disk cleanup to automatically run.  It sets the State Flags in the registry and then creates a scheduled
task to call that resulting sageset on a 4-week basis.  Choosing a day of the week allows for better control of the schedule and timing.
#>
Configuration cDiskCleanup {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$CleanupSet,
        [ValidateNotNullOrEmpty()]
        [string[]]$SkipCleanupSet,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DiskCleanupStart,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DiskCleanupDay
    )

    $Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'

    Import-DscResource -ModuleName PSDesiredStateConfiguration, ComputerManagementDsc
    
    foreach ($Reg2 in $CleanupSet) {
        Registry $Reg2 {
            Key       = "$Path\$Reg2"
            ValueName = 'StateFlags0001'
            ValueType = 'Dword'
            ValueData = '2'
            Ensure    = 'Present'
            Force     = $true
        }
    }
    foreach ($Reg0 in $SkipCleanupSet) {
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
        DaysOfWeek         = $DiskCleanupDay
        WeeksInterval      = '4'
        ExecutionTimeLimit = '02:00:00'
        Enable             = $true
        RandomDelay        = '01:00:00'
        StartTime          = $DiskCleanupStart
        RunLevel           = 'Highest'
        RunOnlyIfIdle      = $false
        Priority           = 7
        Ensure             = 'Present'
    }
}
