# Mac/Linux boxes don't come with Pester
# Windows has the old v3 in-box version of Pester
# Use $null to suppress console log output
$null = Install-Module Pester, VMware.PowerCLI -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force

# Log the newly installed versions of the modules
Get-Module Pester, VMware.VimAutomation.Core -ListAvailable | Select Version, Name | Format-Table -Autosize

# Initial PowerCLI configuration after module installation
Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -ParticipateInCEIP $false -Confirm:$false

# Connect to the vcsim Docker container running locally
Connect-VIServer -Server localhost -Port 443 -User u -Password p

# Invoke-Pester runs all .Tests.ps1 in the order found by "Get-ChildItem -Recurse"
Invoke-Pester -OutputFormat NUnitXml -OutputFile ".\TestResults.xml"
