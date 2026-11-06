# User Lifecycle Wizard

A guided, config-driven onboarding and offboarding wizard for IT/identity teams.
It walks an operator through every step of provisioning or deprovisioning a user,
says what each step does and what to verify, automates what it can, and clearly
flags the manual steps. Dry-run by default.

This is a clean-room, generalized project. It carries no employer-specific code,
domains, tenant IDs, or data. Point it at your own directory, identity provider,
and apps through `config/lifecycle.example.psd1`.

## Why a wizard, not just a script

Full automation is great until something needs a human (an approval, a manual
import, an access decision). A wizard keeps the human in the loop at exactly the
places that need one, and removes the guesswork everywhere else:

- Every step is named, described, and has a stated verification.
- Automated steps preview their action in dry-run before doing anything.
- Manual steps tell the operator exactly what to click, then wait.
- Everything is logged, and the run ends with a follow-up list.

## Structure

```
src/Invoke-LifecycleWizard.ps1   the runner (loop, approval gate, logging)
src/lib/Common.ps1               banner, prompts, logging helpers
src/lib/Connectors.ps1           system action layer (dry-run safe)
src/steps/Onboarding.Steps.ps1   ordered onboarding step definitions
config/lifecycle.example.psd1    your environment, generic placeholders
tests/Wizard.Tests.ps1           Pester tests
```

## Run it (dry-run, safe anywhere)

```powershell
pwsh ./src/Invoke-LifecycleWizard.ps1 -Mode Onboarding `
  -User @{ Name='Jane Doe'; Title='Analyst'; Department='Operations'; Manager='Pat Lead'; StartDate='2026-12-01' }
```

It prints the planned steps, asks for one approval, then walks through them with
`[DRY-RUN]` previews. Nothing is created.

Offboarding works the same way, with a hard safety guard:

```powershell
pwsh ./src/Invoke-LifecycleWizard.ps1 -Mode Offboarding `
  -User @{ UPN='jane.doe@example.com'; LastDay='2026-11-01'; ForwardTo='pat.lead@example.com'; AutoReply='true' }
```

If the person's last day has not actually passed, the run halts immediately with
`[STOP]` and touches nothing. That guard is the whole reason offboarding is scary;
the wizard refuses to guess.

To run for real on Windows with the real connectors wired in:

```powershell
pwsh ./src/Invoke-LifecycleWizard.ps1 -Mode Onboarding -User $user -DryRun $false
```

The connector bodies in `src/lib/Connectors.ps1` are where you plug in AD,
Microsoft Graph, Okta, or a REST app. Until you implement them, `-DryRun $false`
returns `[TODO]` markers instead of touching anything, so it stays safe.

## Adapting it to your org

1. Copy `config/lifecycle.example.psd1` and edit the systems, required fields,
   license groups, and baseline groups.
2. Implement the connectors you need in `src/lib/Connectors.ps1`.
3. Adjust the step order in `src/steps/Onboarding.Steps.ps1` to match your
   process.

## Safety

- Dry-run is the default.
- Secrets are never stored in the repo; connectors should read them from your
  secret store or credential manager.
- No destructive step runs without an explicit approval gate at the start.

## License

MIT. See LICENSE.
