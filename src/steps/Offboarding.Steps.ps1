Set-StrictMode -Version Latest

# Ordered offboarding steps, mirroring a real teardown. Same shape as onboarding.
# Safety is the point here: the last-day guard halts the run before anything is
# touched if the person's last day has not actually passed.
function Get-OffboardingSteps {
    return @(
        @{
            Id = 'elevation'; Title = 'Confirm administrator elevation'; Type = 'auto'
            Description = 'Directory writes and remoting need an elevated session.'
            Verify = 'The terminal is running as administrator.'
            Action = {
                param($ctx)
                if (-not $ctx.IsWindows) { return 'Non-Windows host: elevation check skipped (dry-run preview).' }
                $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                if (-not $admin) { return '[STOP] Not elevated. Restart the terminal as administrator and rerun.' }
                return 'Elevated session confirmed.'
            }
        },
        @{
            Id = 'last-day-guard'; Title = 'Safety guard: confirm the last day has passed'; Type = 'auto'
            Description = 'Never deprovision a person whose last day is in the future. This halts the run if it is.'
            Verify = 'Last day is today or earlier.'
            Action = {
                param($ctx)
                if (-not $ctx.User.ContainsKey('LastDay') -or -not $ctx.User.LastDay) {
                    return '[STOP] No LastDay provided. Offboarding requires the final employment date.'
                }
                $last = [datetime]::Parse($ctx.User.LastDay, [System.Globalization.CultureInfo]::InvariantCulture).Date
                $today = (Get-Date).Date
                if ($last -gt $today) {
                    return ('[STOP] Last day ({0:yyyy-MM-dd}) has not passed. Offboarding blocked.' -f $last)
                }
                return ('Last day ({0:yyyy-MM-dd}) has passed. Safe to proceed.' -f $last)
            }
        },
        @{
            Id = 'intake'; Title = 'Validate the offboarding record'; Type = 'auto'
            Description = 'Confirm the record has the UPN, last day, and a forward-to account.'
            Verify = 'No required field is missing.'
            Action = {
                param($ctx)
                $missing = @()
                foreach ($f in @('UPN', 'LastDay', 'ForwardTo')) {
                    if (-not $ctx.User.ContainsKey($f) -or -not $ctx.User[$f]) { $missing += $f }
                }
                if ($missing.Count) { return ('[STOP] Missing required fields: ' + ($missing -join ', ')) }
                return 'All required offboarding fields present.'
            }
        },
        @{
            Id = 'directory-match'; Title = 'Match the account in the directory'; Type = 'auto'
            Description = 'Find the AD account and note if it is already disabled.'
            Verify = 'Exactly one account matched, and it is still enabled.'
            Action = { param($ctx) Invoke-SystemAction -System 'ActiveDirectory' -Action 'Get-ADUser by UPN, check Enabled' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'forward-to'; Title = 'Resolve the forward-to account'; Type = 'auto'
            Description = 'Confirm the forward-to person is one enabled account so mail does not bounce.'
            Verify = 'Exactly one enabled account found for the forward-to.'
            Action = { param($ctx) Invoke-SystemAction -System 'ActiveDirectory' -Action ('Resolve forward-to to one enabled account: ' + $ctx.User.ForwardTo) -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'password-scramble'; Title = 'Scramble the password'; Type = 'auto'
            Description = 'Rotate the password to a random value so the old one can never be used again.'
            Verify = 'Password reset recorded.'
            Action = { param($ctx) Invoke-SystemAction -System 'ActiveDirectory' -Action 'Set random password' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'shared-mailbox'; Title = 'Convert mailbox to shared and set licenses'; Type = 'auto'
            Description = 'Convert to a shared mailbox and drop paid licenses, keeping a full license only if the mailbox must stay active.'
            Verify = 'Mailbox is shared; license state matches the rule.'
            Action = { param($ctx) Invoke-SystemAction -System 'Microsoft365' -Action 'Convert to shared mailbox; remove licenses unless shared-mailbox exception applies' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'forwarding-autoreply'; Title = 'Set forwarding and auto-reply'; Type = 'auto'
            Description = 'Forward mail to the resolved account and set a departure auto-reply.'
            Verify = 'Forwarding and auto-reply both active.'
            Action = { param($ctx) Invoke-SystemAction -System 'ExchangeOnline' -Action ('Set forwarding to ' + $ctx.User.ForwardTo + ' and an auto-reply') -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'gal-hide'; Title = 'Hide from the global address list'; Type = 'auto'
            Description = 'Hide the account from the GAL so it stops appearing to staff.'
            Verify = 'HiddenFromAddressListsEnabled is true.'
            Action = { param($ctx) Invoke-SystemAction -System 'ExchangeOnline' -Action 'Hide from GAL' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'ad-disable'; Title = 'Disable the directory account'; Type = 'auto'
            Description = 'Disable the AD account and move it to a departed-users OU.'
            Verify = 'Account disabled.'
            Action = { param($ctx) Invoke-SystemAction -System 'ActiveDirectory' -Action 'Disable-ADAccount and move to departed OU' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'session-revoke'; Title = 'Revoke active sessions and tokens'; Type = 'auto'
            Description = 'Kill live sessions so no open session survives the disable.'
            Verify = 'No active sessions remain.'
            Action = { param($ctx) Invoke-SystemAction -System 'EntraID' -Action 'Revoke sign-in sessions' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'idp-deactivate'; Title = 'Deactivate in the identity provider'; Type = 'auto'
            Description = 'Deactivate the user in the IdP and clear their application assignments.'
            Verify = 'User inactive in the IdP.'
            Action = { param($ctx) Invoke-SystemAction -System $ctx.Config.Systems.Idp.Provider -Action 'Deactivate user and clear app assignments' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'apps-deprovision'; Title = 'Remove access across business apps'; Type = 'auto'
            Description = 'Remove from the line-of-business apps, groups, distribution lists, and memberships.'
            Verify = 'No residual access in any connected app.'
            Action = { param($ctx) Invoke-SystemAction -System $ctx.Config.Systems.BusinessApp.Provider -Action 'Remove user from apps, groups, DLs, memberships' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'onedrive-grant'; Title = 'Grant OneDrive access and notify the manager'; Type = 'auto'
            Description = 'Grant the manager time-limited access to the OneDrive and send the notice.'
            Verify = 'Manager has access; notice sent.'
            Action = { param($ctx) Invoke-SystemAction -System 'Microsoft365' -Action ('Grant OneDrive access and notify manager (' + $ctx.Config.Offboarding.ManagerNoticeDays + ' days)') -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'saas-seats'; Title = 'Reclaim shared SaaS seats'; Type = 'auto'
            Description = 'Release any seats the person held (for example an AI assistant seat) so they can be reassigned.'
            Verify = 'Seat returned to the pool.'
            Action = { param($ctx) Invoke-SystemAction -System 'SaaS' -Action 'Reclaim shared seats' -Target $ctx.User.UPN -DryRun $ctx.DryRun }
        },
        @{
            Id = 'manual-facility'; Title = 'Facility badge and equipment (manual)'; Type = 'manual'
            Description = 'Deactivate the physical badge and collect equipment (laptop, phone, accessories).'
            Verify = 'Badge deactivated and equipment logged as returned.'
            Action = { param($ctx) 'Manual: deactivate the badge and collect equipment; log it in the asset record.' }
        },
        @{
            Id = 'report'; Title = 'Write the run log and follow-ups'; Type = 'auto'
            Description = 'Summarize the teardown and list any remaining manual follow-ups.'
            Verify = 'Log saved and reviewed.'
            Action = { param($ctx) 'Offboarding summary generated and written to the log.' }
        }
    )
}
