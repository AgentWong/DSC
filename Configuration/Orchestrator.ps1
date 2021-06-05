Configuration Set-Domain {
    Import-DscResource -Module PSDesiredStateConfiguration,cWSUS
    Node $AllNodes.Where{ $_.Role -eq 'WSUS' }.NodeName
    {
        cWSUS ConfigWSUS {
            SourcePath      = '\\ds\Software\Scripts'
            DestinationPath = 'G:\Scripts'
        }
    }
}