@{
    # This is an interactive console wizard on purpose. Excluding rules that
    # fight that design so CI enforces genuine issues, not style noise.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        'PSReviewUnusedParameter'
        'PSUseSingularNouns'
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
