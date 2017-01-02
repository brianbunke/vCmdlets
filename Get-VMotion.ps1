<#PSScriptInfo
.VERSION 1.0.0
.GUID e4945281-2135-4365-a194-739fcf54456b
.AUTHOR Brian Bunke
.DESCRIPTION Report on recent vMotion events in your VMware environment.
.COMPANYNAME 
.COPYRIGHT 
.TAGS vmware powercli vmotion vcenter
.LICENSEURI https://github.com/brianbunke/vCmdlets/blob/master/LICENSE
.PROJECTURI https://github.com/brianbunke/vCmdlets
.ICONURI 
.EXTERNALMODULEDEPENDENCIES VMware.VimAutomation.Core
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

#Requires -Version 3 -Module VMware.VimAutomation.Core

function Get-VMotion {
<#
.SYNOPSIS
Report on recent vMotion events in your VMware environment.

.DESCRIPTION
Use to check DRS history, or to help with troubleshooting.
vMotion and Storage vMotion events are returned by default.
Can filter to view only results from recent days, hours, or minutes (default is 1 day).

For performance, "Get-VMotion" is good. "Get-VM | Get-VMotion" is very slow.
The cmdlet gathers and parses each entity's events one by one.
This means that while one VM and one datacenter will have similar speeds,
a "Get-VM | Get-VMotion" that contains 50 VMs will take a while.

"Get-Help Get-VMotion -Examples" for some common usage tips.

.NOTES
Thanks to lucdekens/alanrenouf/sneddo for doing the hard work long ago.
http://www.lucd.info/2013/03/31/get-the-vmotionsvmotion-history/
https://github.com/alanrenouf/vCheck-vSphere

.EXAMPLE
Get-VMotion
By default, searches $global:DefaultVIServers (all open Connect-VIServer sessions).
For all datacenters found by Get-Datacenter, view all s/vMotion events in the last 24 hours.
VM name, type of vMotion (compute or storage), and vMotion start time & duration are returned by default.

.EXAMPLE
Get-VMotion -Verbose | Format-List *
For each s/vMotion event found in Example 1, show all properties instead of the default four.
Verbose output tracks current progress, and helps when troubleshooting results.

.EXAMPLE
Get-Cluster '*arcade' | Get-VMotion -Hours 8 | Where-Object {$_.Type -eq 'vmotion'}
For the cluster Flynn's Arcade, view all vMotions in the last eight hours.
NOTE: Piping "Get-Datacenter" or "Get-Cluster" will be much faster than an unfiltered "Get-VM".

.EXAMPLE
Get-VM 'Sam' | Get-VMotion -Days 30 | Format-List *
View hosts/datastores the VM "Sam" has been on in the last 30 days,
when changes happened, and how long any migrations took to complete.
When supplying VM objects, a generic warning displays once about result speed.

.EXAMPLE
$Grid = $global:DefaultVIServers | Where-Object {$_.Name -eq 'Grid'}
PS C:\>Get-VM -Name 'Tron','Rinzler' | Get-VMotion -Days 7 -Server $Grid

View all s/vMotion events for only VMs "Tron" and "Rinzler" in the last week.
If connected to multiple servers, will only search for events on vCenter server Grid.

.EXAMPLE
Get-VMotion | Select-Object Name,Type,Duration | Sort-Object Duration
For all s/vMotions in the last day, return only VM name, vMotion type, and total migration time.
Sort all events from fastest to slowest.
Selecting < 5 properties automatically formats output in a table, instead of a list.

.INPUTS
[VMware.VimAutomation.ViCore.Types.V1.Inventory.InventoryItem[]]
PowerCLI cmdlets Get-Datacenter / Get-Cluster / Get-VM

.OUTPUTS
[System.Collections.ArrayList]
[System.Management.Automation.PSCustomObject]
[vMotion.Object] = arbitrary PSCustomObject typename, to enable default property display

.LINK
http://www.brianbunke.com/blog/2017/01/03/get-vmotion/

.LINK
https://github.com/brianbunke/vCmdlets
#>
    [CmdletBinding(DefaultParameterSetName='Days')]
    [OutputType([System.Collections.ArrayList])]
    param (
        # Filter results to only the specified object(s)
        # Tested with datacenter, cluster, and VM entities
        [Parameter(ValueFromPipeline = $true)]
        [ValidateScript({$_.GetType().Name -match 'VirtualMachine|Cluster|Datacenter'})]
        [Alias('Name','VM','Cluster','Datacenter')]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.InventoryItem[]]$Entity,

        # Number of days to return results from. Defaults to 1
        # Mutually exclusive from Hours, Minutes
        [Parameter(ParameterSetName='Days')]
        [ValidateRange(0,[int]::MaxValue)]
        [int]$Days = 1,
        # Number of hours to return results from
        # Mutually exclusive from Days, Minutes
        [Parameter(ParameterSetName='Hours')]
        [ValidateRange(0,[int]::MaxValue)]
        [int]$Hours,
        # Number of minutes to return results from
        # Mutually exclusive from Days, Hours
        [Parameter(ParameterSetName='Minutes')]
        [ValidateRange(0,[int]::MaxValue)]
        [int]$Minutes,

        # Specifies the vCenter Server system(s) on which you want to run the cmdlet.
        # If no value is passed to this parameter, the command runs on the default servers.
        # For more information about default servers, see the description of Connect-VIServer.
        [VMware.VimAutomation.Types.VIServer[]]$Server = $global:DefaultVIServers
    )

    BEGIN {
        If (-not $Server) {
            throw 'Please open a vCenter session with Connect-VIServer first.'
        }
        Write-Verbose "Processing against vCenter server(s) $("'$Server'" -join ' | ')"

        # Based on parameter supplied, set $Time for $EventFilter below
        switch ($PSCmdlet.ParameterSetName) {
            'Days'    {$Time = (Get-Date).AddDays(-$Days).ToUniversalTime()}
            'Hours'   {$Time = (Get-Date).AddHours(-$Hours).ToUniversalTime()}
            'Minutes' {$Time = (Get-Date).AddMinutes(-$Minutes).ToUniversalTime()}
        }
        Write-Verbose "Using parameter set $($PSCmdlet.ParameterSetName)"
        Write-Verbose "Searching for all vMotion events since $($Time.ToString()) UTC"

        # Construct an empty array for events returned
        # Performs faster than @() when appending; matters if running against many VMs
        $Events = New-Object System.Collections.ArrayList

        # Build a vMotion-specific event filter query
        # http://pubs.vmware.com/vsphere-60/index.jsp#com.vmware.wssdk.apiref.doc/vim.event.EventManager.html
        $EventFilter        = New-Object VMware.Vim.EventFilterSpec
        $EventFilter.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
        $EventFilter.Time   = New-Object VMware.Vim.EventFilterSpecByTime
        $EventFilter.Time.BeginTime = $Time
        $EventFilter.Category = 'Info'
        $EventFilter.DisableFullMessage = $true
        $EventFilter.EventTypeID = 'VmMigratedEvent', 'DrsVmMigratedEvent', 'VmBeingHotMigratedEvent', 'VmBeingMigratedEvent'
    } #Begin

    PROCESS {
        ForEach ($vCenter in $Server) {
            Write-Verbose "Searching for events in vCenter server '$vCenter'"
            Write-Verbose "Calling Get-View for EventManager against server '$vCenter'"
            $EventMgr = Get-View EventManager -Server $vCenter -Verbose:$false

            If ($Entity) {
                # Acknowledge user-supplied inventory item(s)
                $InventoryObjects = $Entity
            } Else {
                # If -Entity was not specified, return datacenter object(s)
                Write-Verbose "Calling Get-Datacenter to process all objects in server '$vCenter'"
                $InventoryObjects = Get-Datacenter -Server $vCenter -Verbose:$false
            }

            $InventoryObjects | ForEach-Object {
                Write-Verbose "Processing $($_.GetType().Name) inventory object $($_.Name)"

                # Warn once against using VMs in -Entity parameter
                If ($_.GetType().Name -match 'VirtualMachine' -and $AlreadyWarnedAboutVMs -eq $null) {
                    Write-Warning 'Script must process VM objects one by one, which slows down results.'
                    Write-Warning 'Consider supplying parent Cluster(s) or Datacenter(s) to -Entity parameter, if possible.'
                    $AlreadyWarnedAboutVMs = $true
                }

                # Add the entity details for the current loop of the Process block
                $EventFilter.Entity.Entity = $_.ExtensionData.MoRef
                $EventFilter.Entity.Recursion = &{
                    If ($_.ExtensionData.MoRef.Type -eq 'VirtualMachine') {'self'} Else {'all'}
                }
                # Create the event collector, and collect 100 events at a time
                Write-Verbose "Calling Get-View to gather event results for object $($_.Name)"
                $Collector = Get-View ($EventMgr).CreateCollectorForEvents($EventFilter) -Server $vCenter -Verbose:$false
                $Buffer = $Collector.ReadNextEvents(100)

                $EventCount = ($Buffer | Measure-Object).Count
                If ($EventCount -lt 1) {
                    Write-Verbose "No vMotion events found for object $($_.Name)"
                }

                While ($Buffer) {
                    Write-Verbose "Processing $EventCount events from object $($_.Name)"

                    # Append up to 100 results into the $Events array
                    If ($EventCount -gt 1) {
                        # .AddRange if more than one event
                        $Events.AddRange($Buffer) | Out-Null
                    } Else {
                        # .Add if only one event; should never happen since gathering begin & end events
                        $Events.Add($Buffer) | Out-Null
                    }
                    # Were there more than 100 results? Get the next batch and restart the While loop
                    $Buffer = $Collector.ReadNextEvents(100)
                }
                # Destroy the collector after each entity to avoid running out of memory :)
                $Collector.DestroyCollector()
            } #ForEach $Entity

            $InventoryObjects = $null
        } #ForEach $vCenter
    } #Process

    END {
        # Construct an empty array for results within the ForEach
        $Results = New-Object System.Collections.ArrayList

        # Group together by ChainID; each vMotion has begin/end events
        ForEach ($vMotion in ($Events | Sort-Object CreatedTime | Group-Object ChainID)) {
            # Each vMotion should have start and finish events
            # "% 2" correctly processes duplicate vMotion results
            # (duplicate results can occur, for example, if you have duplicate vCenter connections open)
            If ($vMotion.Group.Count % 2 -eq 0) {
                # Mark the current vMotion as vMotion / Storage vMotion / Both
                If ($vMotion.Group[0].Ds.Name -eq $vMotion.Group[0].DestDatastore.Name) {
                    $Type = 'vMotion'
                } ElseIf ($vMotion.Group[0].Host.Name -eq $vMotion.Group[0].DestHost.Name) {
                    $Type = 's-vMotion'
                } Else {
                    $Type = 'Both'
                }

                # Add the current vMotion into the $Results array
                $Results.Add([PSCustomObject][Ordered]@{
                    PSTypeName = 'vMotion.Object'
                    Name       = $vMotion.Group[0].Vm.Name
                    Type       = $Type
                    SrcHost    = $vMotion.Group[0].Host.Name
                    DstHost    = $vMotion.Group[0].DestHost.Name
                    SrcDS      = $vMotion.Group[0].Ds.Name
                    DstDS      = $vMotion.Group[0].DestDatastore.Name
                    # Hopefully people aren't performing vMotions that take >24 hours, because I'm ignoring days in the string
                    Duration   = (New-TimeSpan -Start $vMotion.Group[0].CreatedTime -End $vMotion.Group[1].CreatedTime).ToString('hh\:mm\:ss')
                    StartTime  = $vMotion.Group[0].CreatedTime
                    EndTime    = $vMotion.Group[1].CreatedTime
                    # Making an assumption that all events with an empty username are DRS-initiated
                    Username   = &{If ($vMotion.Group[0].UserName) {$vMotion.Group[0].UserName} Else {'DRS'}}
                    ChainID    = $vMotion.Group[0].ChainID
                }) | Out-Null
            } #If vMotion Group % 2
            ElseIf ($vMotion.Group.Count % 2 -eq 1) {
                Write-Verbose "vMotion chain ID $($vMotion.Group[0].ChainID) had an odd number of events. Cannot match start/end times; skipping"
            }
        } #ForEach ChainID

        # Reduce default property set for readability
        $TypeData = @{
            TypeName = 'vMotion.Object'
            DefaultDisplayPropertySet = 'Name','Duration','Type','StartTime'
        }
        # Include -Force to avoid errors after the first run
        Update-TypeData @TypeData -Force

        # Display all results found
        $Results
    } #End
}
