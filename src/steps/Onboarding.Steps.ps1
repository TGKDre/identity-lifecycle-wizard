Set-StrictMode -Version Latest

# Ordered onboarding steps. Each step is a hashtable:
#   Id          short identifier
#   Title       what the operator sees
#   Type        'auto' (runs) or 'manual' (operator does it, wizard waits)
#   Description what this step does
#   Verify      how to confirm it worked
#   Action      scriptblock receiving $ctx (Config, User, DryRun, IsWindows)
function Get-OnboardingSteps {
    return @(
        @{
            Id = 'elevation'; Title = 'Confirm administrator elevation'; Type = 'auto'
            Description = 'Directory writes and AD sync need an elevated session.'
            Verify = 'The terminal is running as administrator.'
            Action = {
                param($ctx)
                if (-not $ctx.IsWindows) { return 'Non-Windows host: elevation check skipped (dry-run preview).' }
                $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                if (-not $admin) { return 'NOT ELEVATED: restart the terminal as administrator, then rerun.' }
                return 'Elevated session confirmed.'
            }
        },
        @{
            Id = 'intake'; Title = 'Validate the intake record'; Type = 'auto'
            Description = 'Check the new-hire record has every required field before we touch any system.'
            Verify = 'No required field is missing.'
            Action = {
                param($ctx)
                $missing = @()
                foreach ($f in $ctx.Config.Onboarding.RequiredFields) {
                    if (-not $ctx.User.ContainsKey($f) -or -not $ctx.User[$f]) { $missing += $f }
                }
                if ($missing.Count) { return ('Missing required fields: ' + ($missing -join ', ')) }
                return 'All required fields present.'
            }
        },
        @{
            Id = 'directory-dup'; Title = 'Check the directory for an existing account'; Type = 'auto'
            Description = 'Search AD by name so we never create a duplicate identity.'
            Verify = 'No existing match, or the operator chose which account to use.'
            Action = { param($ctx) Invoke-SystemAction -System 'ActiveDirectory' -Action 'Find existing user by name' -Target $ctx.User.Name -DryRun $ctx.DryRun }
        },
        @{
            Id = 'directory-create'; Title = 'Create the Active Directory account'; Type = 'auto'
            Description = 'Create the AD user with name, title, department, manager, and the correct OU.'
            Verify = 'User exists, enabled, in the right OU, manager set.'
            Action = { param($ctx) Invoke-SystemAction -System 'ActiveDirectory' -Action 'New-ADUser (set attributes, manager, OU)' -Target $ctx.User.Name -DryRun $ctx.DryRun }
        },
        @{
            Id = 'cloud-identity'; Title = 'Create or confirm the Entra ID account'; Type = 'auto'
            Description = 'Ensure the cloud identity exists and is linked to the on-prem account.'
            Verify = 'Entra user present, UPN matches, sync healthy.'
            Action = { param($ctx) Invoke-SystemAction -System 'EntraID' -Action 'Provision user via Microsoft Graph' -Target $ctx.User.Name -DryRun $ctx.DryRun }
        },
        @{
            Id = 'licenses'; Title = 'Assign licenses'; Type = 'auto'
            Description = 'Assign the license group(s) defined in config.'
            Verify = 'Licenses show as assigned on the account.'
            Action = { param($ctx) Invoke-SystemAction -System 'Microsoft365' -Action ('Assign license(s): ' + ($ctx.Config.Onboarding.Licenses -join ', ')) -Target $ctx.User.Name -DryRun $ctx.DryRun }
        },
        @{
            Id = 'groups'; Title = 'Add to groups and distribution lists'; Type = 'auto'
            Description = 'Add to baseline groups and any department groups.'
            Verify = 'Group membership matches config.'
            Action = { param($ctx) Invoke-SystemAction -System 'Directory' -Action ('Add to groups: ' + ($ctx.Config.Onboarding.Groups -join ', ')) -Target $ctx.User.Name -DryRun $ctx.DryRun }
        },
        @{
            Id = 'idp-import'; Title = 'Import the user into the identity provider'; Type = 'manual'
            Description = 'In the IdP admin console: Directory Integrations > Active Directory > Import > Import Now > Incremental, tick Auto-activate for the new user, then confirm.'
            Verify = 'User appears in the IdP with the expected applications.'
            Action = { param($ctx) 'Manual: perform the incremental import and auto-activate in your IdP.' }
        },
        @{
            Id = 'business-app'; Title = 'Provision the business application'; Type = 'auto'
            Description = 'Create the user in the line-of-business app via its API and copy access from a template user.'
            Verify = 'User can sign in with the expected permissions.'
            Action = { param($ctx) Invoke-SystemAction -System $ctx.Config.Systems.BusinessApp.Provider -Action 'Create user and copy access from template' -Target $ctx.User.Name -DryRun $ctx.DryRun }
        },
        @{
            Id = 'welcome'; Title = 'Send the welcome email'; Type = 'auto'
            Description = 'Send the templated welcome message and first-day details.'
            Verify = 'Email present in sent items.'
            Action = { param($ctx) Invoke-SystemAction -System 'ExchangeOnline' -Action 'Send welcome email' -Target $ctx.User.Name -DryRun $ctx.DryRun }
        },
        @{
            Id = 'report'; Title = 'Write the run log and follow-ups'; Type = 'auto'
            Description = 'Summarize what was set up and list any manual follow-ups for the operator.'
            Verify = 'Log saved and reviewed.'
            Action = { param($ctx) 'Run summary generated and written to the log.' }
        }
    )
}
