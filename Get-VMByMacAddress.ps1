#Requires -Version 4 -Modules VMware.VimAutomation.Core

function Get-VMByMacAddress {
<#
.SYNOPSIS
Find one or more VMware VMs from given MAC addresses.

.DESCRIPTION
Assumes an active PowerCLI connection (Connect-VIServer).
Credit to lucd from a VMware {code} discussion in Slack on the fastest method to perform this task.

.EXAMPLE
Get-VMByMacAddress -MacAddress 12:34:56:78:90:ab
Returns any VM name(s) with a network adapter matching the given physical network address.

.EXAMPLE
aabb-ccdd-eeff | Get-VMByMacAddress -Verbose
Will strip any non-alphanumeric characters and format into VMware's preferred syntax.
Pipeline input is accepted. Verbose output notes the reformatted string it tries to match.

.EXAMPLE
1234567890ab, aabbccddeeff | Get-VMByMacAddress
Multiple addresses are accepted, with or without pipeline input.

.LINK
https://github.com/brianbunke/vCmdlets
#>

    [CmdletBinding()]
    param (
        # The physical address for the network adapter; expects 12 hexadecimal characters
        # Will strip any combination of .:- characters, reformatting into desired aa:bb:cc:dd:ee:ff format
        [Parameter(ValueFromPipeline)]
        [string[]]$MacAddress
    )
    
    begin {
        # `Get-View -Filter` does not support arrays, so we cannot filter any further here
        $view = Get-View -ViewType VirtualMachine -Property Name, Config.Hardware.Device
    }
    
    process {
        ForEach ($mac in $MacAddress) {
            # Strip "non-word" characters with RegEx (keeps only a-z 0-9)
            $mac = $mac -replace '\W'

            If ($mac.Length -ne 12) {
                Write-Warning "$mac is not a 12 character hexadecimal string"
                continue
            }

            # Using RegEx again, add a colon after every two characters, then trim the last one off the end
            # This is the most readable regular expression I could find ;)
            $mac = ($mac -replace '(..)','$1:').trim(':')
            
            Write-Verbose "Looking for address $mac"

            # For the results from Get-View,
            # where we only care about the "Network Adapter" hardware devices,
            # return only the objects matching the supplied MAC address

            # The .Where{} method is faster than piping to Where-Object
            ($view.Where{$_.Config.Hardware.Device.Where{$_ -is [VMware.Vim.VirtualEthernetCard] -and $_.MacAddress.Equals($mac)}}).Name
        }
    }
}
