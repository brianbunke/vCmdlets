# These tests are so flaky because I can't dictate datastore size in vcsim right now :(

Describe 'Get-DatastoreProvisioned' -Tag integration {
    ### ARRANGE
    
    # Dot source the function
    . $PSScriptRoot\..\Get-DatastoreProvisioned.ps1

    ### ACT
    
    Connect-VIServer -Server localhost -Port 443 -User u -Pass p -Force

    # Capture the datastore for further interaction
    $ds0 = Get-Datastore -Name LocalDS_0

    # Run the command twice, storing the results for assertions
    $Pipe1 = $ds0 | Get-DatastoreProvisioned
    $Pipe2 = $ds0, $ds0 | Get-DatastoreProvisioned

    ### ASSERT
    
    It 'Receives expected ds0 values from vcsim' {
        # vcsim container defaults
        $ds0.CapacityMB  | Should -Be 124
        $ds0.FreeSpaceMB | Should -Be 92
    }

    It 'Correctly calculates values' {
        $Pipe1.FreeSpaceGB    | Should -Be .09
        $Pipe1.CapacityGB     | Should -Be .12
        $Pipe1.ProvisionedGB  | Should -Be .03
        $Pipe1.UsedPct        | Should -Be 25.81
        $Pipe1.ProvisionedPct | Should -Be 25.47
    }

    It 'Processes multiple objects via the pipeline' {
        $Pipe2.Count | Should -Be 2
    }
}
