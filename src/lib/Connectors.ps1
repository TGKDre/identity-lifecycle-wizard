Set-StrictMode -Version Latest

# The single choke point for anything that touches a real system.
# In dry-run it returns a preview. With -DryRun $false it returns a [TODO]
# marker until you implement the actual provider call below.
function Invoke-SystemAction {
    param(
        [Parameter(Mandatory)][string]$System,
        [Parameter(Mandatory)][string]$Action,
        [string]$Target,
        [bool]$DryRun = $true
    )
    $who = if ($Target) { " for $Target" } else { '' }
    if ($DryRun) {
        return ("[DRY-RUN] Would run '{0}' on {1}{2}" -f $Action, $System, $who)
    }

    # Implement real provider calls here, for example:
    #   switch ($System) {
    #     'ActiveDirectory' { New-ADUser ... }
    #     'EntraID'         { New-MgUser ... }
    #     'Okta'            { Invoke-RestMethod ... }
    #   }
    return ("[TODO] Implement '{0}' against your {1} connector{2}" -f $Action, $System, $who)
}
