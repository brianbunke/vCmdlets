Describe 'Get-DatastoreProvisioned' -Tag unit {
    ### ARRANGE
    
    # Dot source the function
    . $PSScriptRoot\..\Get-DatastoreProvisioned.ps1

    ### ACT
    
    Connect-VIServer -Server localhost -Port 443 -User u -Pass p

    # Capture the datastore for further interaction
    $ds0 = Get-Datastore -Name LocalDS_0

    # Run the command twice, storing the results for assertions
    $Pipe1 = $ds0 | Get-DatastoreProvisioned
    $Pipe2 = $ds0, $ds0 | Get-DatastoreProvisioned

    ### ASSERT
    
    It 'Receives expected ds0 values from vcsim' {
        # vcsim container defaults
        $ds0.CapacityMB  | Should -Be 58
        $ds0.FreeSpaceMB | Should -Be 53
    }

    It 'Correctly calculates values' {
        $Pipe1.FreeSpaceGB    | Should -Be .05
        $Pipe1.CapacityGB     | Should -Be .06
        $Pipe1.ProvisionedGB  | Should -Be 0
        $Pipe1.UsedPct        | Should -Be 8.62
        $Pipe1.ProvisionedPct | Should -Be 8.37
    }

    It 'Processes multiple objects via the pipeline' {
        $Pipe2.Count | Should -Be 2
    }
}
