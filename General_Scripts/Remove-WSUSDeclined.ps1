If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  # Relaunch as an elevated process:
  Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
  exit
}

Get-WsusUpdate -Classification All -Approval Unapproved -Status Any | Deny-WsusUpdate

[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer();
$declined=$wsus.GetUpdates().Where{$_.IsDeclined -eq $true}
foreach($obj in $Declined){$wsus.DeleteUpdate($obj.Id.UpdateId.ToString()); Write-Host $obj.Title removed }