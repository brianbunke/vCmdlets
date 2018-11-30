Describe 'Connectivity' -Tag unit {
    It 'Sees the Docker container' {
        Test-Connection localhost -TCPPort 443 | Should -BeTrue
    }
}

Describe 'Get-DatastoreProvisioned' -Tag unit {
    ### ARRANGE
    
    # Dot source the function
    . $PSScriptRoot\Get-DatastoreProvisioned.ps1

    ### ACT

    # Capture the datastore for further interaction
    $ds0 = Get-Datastore -Name LocalDS_0
    $ds1 = Get-Datastore -Name LocalDS_1

    # Run the command twice, storing the results for assertions
    $Pipe1 = $ds0 | Get-DatastoreProvisioned
    $Pipe2 = $ds0, $ds1 | Get-DatastoreProvisioned

    ### ASSERT
    
    It 'Receives expected ds0 values from vcsim' {
        # vcsim container defaults
        $ds0.CapacityMB  | Should -Be 124
        $ds0.FreeSpaceMB | Should -Be 92
        $ds0.ExtensionData.Summary.Capacity    | Should -Be 130046416
        $ds0.ExtensionData.Summary.FreeSpace   | Should -Be 96935068
        $ds0.ExtensionData.Summary.Uncommitted | Should -BeNullOrEmpty
    }

    It 'Receives expected ds1 values from vcsim' {
        # Second datastore will have the same values. Just check one
        $ds1.CapacityMB | Should -Be 124
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
