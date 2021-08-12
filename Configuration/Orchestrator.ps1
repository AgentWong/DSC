<#
This is an orchestrator, or master configuration.  Ideally any unique configuration parameters (such as your maintenance windows)
should be set in the Configuration Data file.  Any role specific configurations should be kept in a Composite Resource (i.e. I have one for WSUS).

This file should only be edited to reference new configurations, by separating the Configuration Data and Composite Resources in this manner,
the execution flow is much cleaner and easy to see from a 1000-foot view.
#>

Configuration SetDomain {
    Import-DscResource -Module PSDesiredStateConfiguration, CompositeResources, ComputerManagementDsc, cScheduleWU, cDscInventory, xWindowsEventForwarding
    #These are base OS settings that everything should have.
    Node $AllNodes.NodeName 
    {
        #Due to a bug in Windows Server 2019, it will always prompt you for the reason why the server shutdown or restarted unexpectedly
        #unless the prompt is answered by a Local Administrator account on the server, this configuration removes that prompt.
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

        #Runs disk cleanup on a monthly schedule.
        cDiskCleanup MonthlyDiskCleanup {
            CleanupSet       = $Node.CleanupSet
            SkipCleanupSet   = $Node.SkipCleanupSet
            DiskCleanupDay   = $Node.DiskCleanupDay
            DiskCleanupStart = $Node.DiskCleanupStart
        }

        #Takes an inventory of the installed software and writes it to a custom event log entry for consumption by Log Insight.
        cDscInventory MonthlySoftwareInventory {
            InventoryExists = 'False'
        }
    }

    #Implements WSUS optimized configuration as specified by Microsoft Best Practices documentation.
    Node $AllNodes.Where{ $_.Role -eq 'WSUS' }.NodeName 
    {
        cWSUS ConfigWSUS {
        }
    }

    #Configures group membership of Event Log Readers to allow log server to query event logs
    #for forwarding to Log Insight.
    Node $AllNodes.Where{ $_.LogForward -eq 'True' }.NodeName 
    {
        Group LogForward {
            GroupName = 'Event Log Readers'
            Ensure    = 'Present'
            Members   = $ConfigurationData.LogServer.ComputerAccount
        }
    }

    #Configures Windows Syslog server to receive forwarded events for Log Insight to consume.
    Node $AllNodes.Where{ $_.Role -eq 'Kiwi Syslog Server' }.NodeName 
    {
        $Domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
        $ForwardBaseline = $AllNodes.Where{ $_.LogForward -eq 'True' }.NodeName
        $FQDNBase = foreach ($Hostname in $ForwardBaseline) {
            $Result = $Hostname + '.' + $Domain
            Write-Output $Result
        }
        xWEFCollector Enabled {
            Ensure = "Present"
            Name   = "Enabled"
        }
        xWEFSubscription Base {
            SubscriptionID   = "Base"
            DeliveryMode     = 'Pull'
            Ensure           = "Present"
            SubscriptionType = 'CollectorInitiated'
            Address          = $FQDNBase
            DependsOn        = "[xWEFCollector]Enabled"
            Query            = $ConfigurationData.LogInsightQuery.Baseline
        }
    }

    #Implements custom configuration to patch VMs based on node assignments + role.
    #The primary node will patch first, the secondary nodes will wait for the primary node to finish patching before starting its own updates.
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

SetDomain -ConfigurationData 'C:\Scripts\ConfigData\Config.psd1' -OutputPath 'C:\Configs'

Read-Host -Prompt 'Script completed, check for errors.'