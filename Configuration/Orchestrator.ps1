Configuration SetDomain {
    Import-DscResource -Module PSDesiredStateConfiguration,CompositeResources
    Node $AllNodes.NodeName 
    {
        Registry DirtyShutdown {
            Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability'
            ValueName = 'DirtyShutdown'
            Ensure = 'Absent'
        }
        Registry DirtyShutdownTime {
            Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability'
            ValueName = 'DirtyShutdownTime'
            Ensure = 'Absent'
        }
    }
    Node $AllNodes.Where{ $_.Role -eq 'WSUS' }.NodeName 
    {
        cWSUS ConfigWSUS {
            SourcePath      = '\\ds\Software\Scripts'
            DestinationPath = 'G:\Scripts'
        }
    }
}