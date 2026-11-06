BeforeAll {
    $repo = Split-Path $PSScriptRoot -Parent
    . (Join-Path $repo 'src/lib/Common.ps1')
    . (Join-Path $repo 'src/lib/Connectors.ps1')
    . (Join-Path $repo 'src/steps/Onboarding.Steps.ps1')
}

Describe 'Onboarding step definitions' {
    It 'returns ordered steps with all required fields' {
        $steps = Get-OnboardingSteps
        $steps.Count | Should -BeGreaterThan 5
        foreach ($s in $steps) {
            $s.Id          | Should -Not -BeNullOrEmpty
            $s.Title       | Should -Not -BeNullOrEmpty
            $s.Description | Should -Not -BeNullOrEmpty
            $s.Verify      | Should -Not -BeNullOrEmpty
            $s.Type        | Should -BeIn @('auto', 'manual')
            $s.Action      | Should -Not -BeNullOrEmpty
        }
    }

    It 'includes at least one manual step (IdP import)' {
        $steps = Get-OnboardingSteps
        @($steps | Where-Object { $_.Type -eq 'manual' }).Count | Should -BeGreaterThan 0
    }
}

Describe 'Connector safety' {
    It 'never performs real work in dry-run' {
        $r = Invoke-SystemAction -System 'Test' -Action 'Something' -DryRun $true
        $r | Should -Match 'DRY-RUN'
    }
    It 'refuses to do real work until implemented' {
        $r = Invoke-SystemAction -System 'Test' -Action 'Something' -DryRun $false
        $r | Should -Match 'TODO'
    }
}
