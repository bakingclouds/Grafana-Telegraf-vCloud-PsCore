$ConfigFile = "$PSScriptRoot/Config.json"
$Configs = Get-Content -Raw -Path $ConfigFile -ErrorAction Continue | ConvertFrom-Json -ErrorAction Continue

if (!($Configs)) {
    Throw "Import JSON Config Failed"
    }

$VcdHost = $Configs.Base.VcdHost
$BasicAuth = $Configs.Base.BasicAuth

#region: Login
$Uri = "https://$VcdHost/api/sessions"
$Authorization = 'Basic {0}' -f $BasicAuth
$Headers =  @{'accept' = 'application/vnd.vmware.vcloud.session+xml;version=32.0'; 'Authorization' = $Authorization}
$ResponseHeaders = $null
try {
    $Login = Invoke-RestMethod -uri $Uri -Method Post -Headers $Headers -ResponseHeadersVariable 'ResponseHeaders'
}
catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Exit
}
#endregion

#region: Cleanup Confidential Data
Clear-Variable -Name BasicAuth, Authorization, Headers
#endregion

#region: Get vApps
$Uri = "https://$VcdHost/api/query?type=orgVdc"
$Headers =  @{'accept' = 'application/*+xml;version=32.0'; 'x-vcloud-authorization' = [String]$ResponseHeaders.'x-vcloud-authorization'}
[XML]$orgVdcs = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
#endregion

#region: Get vApps
## vApp Details
foreach ($item in [Array]$vApps.QueryResultRecords.VAppRecord) {
    if($item.numberOfVMs -ne 0){
$body = "vCloudStats,vApp=$($item.name.Replace(' ','-')),status=$($item.status) numberOfVMs=$($item.numberOfVMs),numberOfCpus=$($item.numberOfCpus),cpuAllocationInMhz=$($item.cpuAllocationInMhz),memoryAllocationMB=$($item.memoryAllocationMB),storageKB=$($item.storageKB)"
        Write-Host $body
}}

#region: Get VMs
$Uri = "https://$VcdHost/api/query?type=vm"
$Headers =  @{'accept' = 'application/*+xml;version=32.0'; 'x-vcloud-authorization' = [String]$ResponseHeaders.'x-vcloud-authorization'}
[XML]$VMs = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
#endregion

#region: Get orgNetworks
$Uri = "https://$VcdHost/api/query?type=orgNetwork"
$Headers =  @{'accept' = 'application/*+xml;version=32.0'; 'x-vcloud-authorization' = [String]$ResponseHeaders.'x-vcloud-authorization'}
[XML]$orgNetworks = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
#endregion

#region: Get edgeGateway
$Uri = "https://$VcdHost/api/query?type=edgeGateway"
$Headers =  @{'accept' = 'application/*+xml;version=32.0'; 'x-vcloud-authorization' = [String]$ResponseHeaders.'x-vcloud-authorization'}
[XML]$edgeGateways = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
#endregion

#region: Output
## Simple Stats
$orgVdcsTotal = ([Array]$orgVdcs.QueryResultRecords.OrgVdcRecord).Count
$body="vCloudStats orgVdcCountTotal=$orgVdcsTotal"
Write-Host $body
$vAppsTotal = ([Array]$vApps.QueryResultRecords.VAppRecord).Count
$body="vCloudStats vAppCountTotal=$vAppsTotal"
Write-Host $body
$VMsTotal = ([Array]$VMs.QueryResultRecords.VMRecord | Where-Object {$_.isVAppTemplate -ne "true"}).Count
$body="vCloudStats VMCountTotal=$VMsTotal"
Write-Host $body
$VMsPoweredOff = ([Array]$VMs.QueryResultRecords.VMRecord | Where-Object {$_.isVAppTemplate -ne "true" -and  $_.status -eq "POWERED_OFF"}).Count
$body="vCloudStats VMCountPoweredOff=$VMsPoweredOff"
Write-Host $body
$orgNetworksTotal = $orgNetworks.QueryResultRecords.OrgNetworkRecord.Count
$body="vCloudStats orgNetworkCountTotal=$orgNetworksTotal"
Write-Host $body
$edgeGatewaysTotal = ([Array]$edgeGateways.QueryResultRecords.EdgeGatewayRecord).Count
$body="vCloudStats edgeGatewaysTotal=$edgeGatewaysTotal"
Write-Host $body

## OrgVdc Details
foreach ($item in [Array]$orgVdcs.QueryResultRecords.OrgVdcRecord) {
    $body = "vCloudStats,orgVdc=$($item.name),isEnabled=$($item.isEnabled) cpuUsedMhz=$($item.cpuUsedMhz),memoryUsedMB=$($item.memoryUsedMB),numberOfMedia=$($item.numberOfMedia),numberOfVAppTemplates=$($item.numberOfVAppTemplates),numberOfVApps=$($item.numberOfVApps),storageUsedMB=$($item.storageUsedMB)"
        Write-Host $body
}
## vApp Details
foreach ($item in [Array]$vApps.QueryResultRecords.VAppRecord) {
    $body = "vCloudStats,vApp=$($item.name),status=$($item.status) numberOfVMs=$($item.numberOfVMs),numberOfCpus=$($item.numberOfCpus),cpuAllocationInMhz=$($item.cpuAllocationInMhz),memoryAllocationMB=$($item.memoryAllocationMB),storageKB=$($item.storageKB)"
        Write-Host $body
}
## orgNetwork Details
foreach ($item in [Array]$orgNetworks.QueryResultRecords.OrgNetworkRecord) {
    $Uri = [string]$item.href + "/allocatedAddresses"
    $Headers =  @{'accept' = 'application/*+xml;version=32.0'; 'x-vcloud-authorization' = [String]$ResponseHeaders.'x-vcloud-authorization'}
    [XML]$orgNetworkAllocated = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
    $AllocatedIpAddressesTotal = $orgNetworkAllocated.AllocatedIpAddresses.IpAddress.Count
    $body = "vCloudStats,orgNetwork=$($item.name),gateway=$($item.gateway) AllocatedIpAddressesTotal=$AllocatedIpAddressesTotal"
        Write-Host $body
}
## Edge Details
foreach ($item in [Array]$edgeGateways.QueryResultRecords.EdgeGatewayRecord) {
    $body = "vCloudStats,edgeGateway=$($item.name),gatewayStatus=$($item.gatewayStatus),haStatus=$($item.haStatus) numberOfExtNetworks=$($item.numberOfExtNetworks),numberOfOrgNetworks=$($item.numberOfOrgNetworks)"
        Write-Host $body
}
#endregion

#region: Logout
$Uri = "https://$VcdHost/api/session"
$Headers =  @{'accept' = 'application/vnd.vmware.vcloud.session+xml;version=32.0'; 'x-vcloud-authorization' = [String]$ResponseHeaders.'x-vcloud-authorization'}
$Logout = Invoke-RestMethod -uri $Uri -Method Delete -Headers $Headers
#endregion

#region: Cleanup Confidential Data
Clear-Variable -Name ResponseHeaders, Headers
#endregion
