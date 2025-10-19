# ============================================================================
# WSL Install Module Manifest
# ============================================================================

@{
    # Script module or binary module file associated with this manifest.
    RootModule = ''

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID = '12345678-1234-1234-1234-123456789012'

    # Author of this module
    Author = 'WSL Install Script'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2024 WSL Install Script. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Modularized WSL installation script for ArchLinux distributions'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'WSL-Logging.psm1',
        'WSL-Helpers.psm1',
        'WSL-SystemSetup.psm1',
        'WSL-Validation.psm1',
        'WSL-Command.psm1',
        'WSL-Management.psm1',
        'WSL-PackageManager.psm1',
        'WSL-UserManagement.psm1',
        'WSL-Input.psm1',
        'WSL-Chezmoi.psm1',
        'WSL-SSH.psm1',
        'WSL-Workflow.psm1'
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Write-LogMessage',
        'Write-Section',
        'Write-ProgressLog',
        'Get-OutputRedirection',
        'Test-WSLExitCode',
        'Format-WSLOutput',
        'Install-WSLFeatures',
        'Test-ValidLinuxUsername',
        'Test-GitAvailable',
        'Test-DistributionExists',
        'Test-DistributionReady',
        'Test-UserExists',
        'Test-UserSudoAccess',
        'Test-PacmanKeyringInitialized',
        'Test-PackageInstalled',
        'Test-ChezmoiConfigured',
        'Invoke-WSLCommand',
        'Invoke-WSLCommandInteractive',
        'Remove-WSLDistribution',
        'Install-WSLDistribution',
        'Wait-ForDistributionReady',
        'Stop-WSLDistribution',
        'Initialize-PacmanKeyring',
        'Install-PacmanPackage',
        'Get-MissingPackages',
        'Install-MissingPackages',
        'Initialize-PackageManager',
        'Test-PackageManagerInitialized',
        'New-WSLUser',
        'Add-UserToSudoers',
        'Test-Configuration',
        'Get-UserInput',
        'Get-ValidatedUsername',
        'Get-ConfigurationInput',
        'Show-ConfigurationSummary',
        'Get-GitConfig',
        'Test-ChezmoiInstallation',
        'Invoke-ChezmoiSetup',
        'Test-SSHDRunning',
        'Get-SSHDPort',
        'Get-WSLIPAddress',
        'New-SSHPortForward',
        'New-SSHFirewallRule',
        'Invoke-SSHConfiguration',
        'Invoke-ContinueChecks',
        'Invoke-ContinueModeWorkflow',
        'Invoke-NormalModeWorkflow',
        'Invoke-ChezmoiWorkflow',
        'Show-CompletionSummary'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('WSL', 'Linux', 'ArchLinux', 'Installation', 'PowerShell')

            # A URL to the license for this module.
            LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = ''

            # A URL to an icon representing this module.
            IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial modularized release of WSL installation script'

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        } # End of PSData hashtable
    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}