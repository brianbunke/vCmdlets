
Describe 'Get-DatastoreProvisioned' -Tag unit {
    ### ARRANGE
    
    # Dot source the function
    . $PSScriptRoot\Get-DatastoreProvisioned.ps1
    
    # Import the mock object module
    If (Get-Module VMware.VimAutomation.Core) {
        Remove-Module VMware.VimAutomation.Core -Force
    }
    Import-Module $PSScriptRoot\TestHelpers\VMware.VimAutomation.Core.psd1

    ### ACT

    # Create the mock's script block
    $dsMockObject = {
        return [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.DatastoreImpl] @{
            Name        = 'asdf'
            CapacityGB  = [decimal]12.055664063
            CapacityMB  = [decimal]12345
            FreeSpaceGB = [decimal]6.629882813
            FreeSpaceMB = [decimal]6789

            ExtensionData = [VMware.Vim.Datastore] @{
                Summary = [VMware.Vim.DatastoreSummary] @{
                    Capacity    = [int64]12944670720
                    FreeSpace   = [int64]7118782464
                }
            }
        }
    }

    Mock -CommandName Get-Datastore -MockWith $dsMockObject

    # Capture the datastore for further interaction
    $ds = Get-Datastore

    # Run the command, storing the results for assertions
    $Pipe = $ds | Get-DatastoreProvisioned

    ### ASSERT
    
    It 'Receives expected ds values from the mock object' {
        $ds.CapacityMB  | Should -Be 12345
        $ds.FreeSpaceMB | Should -Be 6789
        $ds.ExtensionData.Summary.Capacity    | Should -Be 12944670720
        $ds.ExtensionData.Summary.FreeSpace   | Should -Be 7118782464
        $ds.ExtensionData.Summary.Uncommitted | Should -BeNullOrEmpty
    }

    It 'Correctly calculates values' {
        $Pipe.FreeSpaceGB    | Should -Be 6.63
        $Pipe.CapacityGB     | Should -Be 12.06
        $Pipe.ProvisionedGB  | Should -Be 5.43
        $Pipe.UsedPct        | Should -Be 45.01
        $Pipe.ProvisionedPct | Should -Be 45.01
    }
}
