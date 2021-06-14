Configuration SetDomain {
    Import-DscResource -Module PSDesiredStateConfiguration, CompositeResources, ComputerManagementDsc
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
    }
    Node $AllNodes.Where{ $_.Role -eq 'WSUS' }.NodeName 
    {
        cWSUS ConfigWSUS {
            SourcePath      = $Node.SourcePath
            DestinationPath = $Node.DestinationPath
        }
    }
    Node $AllNodes.Where{ $_.UpdateSchedule -eq 'Primary' }.NodeName 
    {
        Script WindowsUpdate {
            GetScript  = {
                $Min = Get-Date $ConfigurationData.PrimaryUpdate.MaintenanceStart
                $Max = Get-Date $ConfigurationData.PrimaryUpdate.MaintenanceEnd
                $Now = Get-Date
                if (($Now.DayOfWeek -eq $Node.MaintenanceDay) -and ($Min.TimeOfDay -le $Now.TimeOfDay) -and `
                    ($Max.TimeOfDay -ge $Now.TimeOfDay)) {
                    return @{ 'Result' = $false }
                }
                else {
                    return @{ 'Result' = $true }
                }
            }
            TestScript = {
                $Min = Get-Date $ConfigurationData.PrimaryUpdate.MaintenanceStart
                $Max = Get-Date $ConfigurationData.PrimaryUpdate.MaintenanceEnd
                $Now = Get-Date
                if (($Now.DayOfWeek -eq $Node.MaintenanceDay) -and ($Min.TimeOfDay -le $Now.TimeOfDay) -and `
                    ($Max.TimeOfDay -ge $Now.TimeOfDay)) {
                    $Updates = Start-WUScan -SearchCriteria "IsInstalled=0 AND IsHidden=0 AND IsAssigned=1"
                    if ($null -eq $Updates) {
                        return $true
                    }
                    else {
                        return $false
                    }
                }
                else {
                    return $true
                }
            }
            SetScript  = {
                $Updates = Start-WUScan -SearchCriteria "IsInstalled=0 AND IsHidden=0 AND IsAssigned=1"
                Install-WUUpdates -Updates $Updates
                $global:DSCMachineStatus = '1'
                Write-Verbose "Setting DSC Reboot Needed flag to $global:DSCMachineStatus."
            }
        }
        PendingReboot WindowsUpdateReboot {
            Name      = 'WindowsUpdateReboot'
            DependsOn = '[Script]WindowsUpdate'
        }
    }
    Node $AllNodes.Where{ $_.UpdateSchedule -eq 'Secondary' }.NodeName 
    {
        $NodeRole = $Node.Role
        WaitForAny WaitForPrimary {
            ResourceName      = '[Script]WindowsUpdate'
            NodeName          = $AllNodes.Where{ ($_.Role -eq $NodeRole) -and ( $_.UpdateSchedule -eq 'Primary') }.NodeName
            RetryCount        = '20'
            RetryIntervalSec = '600'
        }
        Script WindowsUpdate {
            GetScript  = {
                $Min = Get-Date $ConfigurationData.PrimaryUpdate.MaintenanceStart
                $Max = Get-Date $ConfigurationData.PrimaryUpdate.MaintenanceEnd
                $Now = Get-Date
                if (($Now.DayOfWeek -eq $Node.MaintenanceDay) -and ($Min.TimeOfDay -le $Now.TimeOfDay) -and `
                    ($Max.TimeOfDay -ge $Now.TimeOfDay)) {
                    return @{ 'Result' = $false }
                }
                else {
                    return @{ 'Result' = $true }
                }
            }
            TestScript = {
                $Min = Get-Date $ConfigurationData.PrimaryUpdate.MaintenanceStart
                $Max = Get-Date $ConfigurationData.PrimaryUpdate.MaintenanceEnd
                $Now = Get-Date
                if (($Now.DayOfWeek -eq $Node.MaintenanceDay) -and ($Min.TimeOfDay -le $Now.TimeOfDay) -and `
                    ($Max.TimeOfDay -ge $Now.TimeOfDay)) {
                    $Updates = Start-WUScan -SearchCriteria "IsInstalled=0 AND IsHidden=0 AND IsAssigned=1"
                    if ($null -eq $Updates) {
                        return $true
                    }
                    else {
                        return $false
                    }
                }
                else {
                    return $true
                }
            }
            SetScript  = {
                $Updates = Start-WUScan -SearchCriteria "IsInstalled=0 AND IsHidden=0 AND IsAssigned=1"
                Install-WUUpdates -Updates $Updates
                $global:DSCMachineStatus = '1'
                Write-Verbose "Setting DSC Reboot Needed flag to $global:DSCMachineStatus."
            }
            DependsOn  = '[WaitForAny]WaitForPrimary'
        }
        PendingReboot WindowsUpdateReboot {
            Name      = 'WindowsUpdateReboot'
            DependsOn = '[Script]WindowsUpdate'
        }
    }
}