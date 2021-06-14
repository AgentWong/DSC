[DSCLocalConfigurationManager()]
configuration DSCClientNodeConfiguration
{
    param
    (
        [ValidateNotNullOrEmpty()]
        [string] $NodeName = 'localhost'
    )

    Node $NodeName
    {
        Settings {
            RefreshMode          = 'Push'
            RebootNodeIfNeeded   = $true
            AllowModuleOverwrite = $true
            ActionAfterReboot = 'ContinueConfiguration'
        }
    }
}