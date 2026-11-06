@{
    Organization = 'Example Co'
    Domain       = 'example.com'

    # Where the wizard reads source data (a form, a CSV, a ticket system).
    Intake = @{
        Provider = 'Generic'          # Formstack, Google Form, CSV, etc.
        Source   = 'intake/new-hire.csv'
    }

    # The systems the wizard can act on. Adapt providers to your stack.
    Systems = @{
        Directory   = @{ Provider = 'ActiveDirectory'; Server = 'dc1.example.com'; BaseOU = 'OU=Staff,DC=example,DC=com' }
        Identity    = @{ Provider = 'EntraID';         Tenant = 'example.onmicrosoft.com' }
        Idp         = @{ Provider = 'Okta';            OrgUrl = 'https://example.okta.com' }
        Mail        = @{ Provider = 'ExchangeOnline' }
        BusinessApp = @{ Provider = 'GenericRest';     BaseUrl = 'https://app.example.com/api' }
    }

    Onboarding = @{
        RequiredFields = @('Name','Title','Department','Manager','StartDate')
        Licenses       = @('E3')
        Groups         = @('All Staff')
        TemplateUser   = 'template.user@example.com'   # copy access from this user
    }

    Offboarding = @{
        ManagerNoticeDays = 14
        ScramblePassword  = $true
        SharedMailboxDays = 30
    }
}
