@{
    # Copy this file to site.local.psd1, which git ignores, and fill in what you use. Everything is optional:
    # leave a line out, or leave it as a comment, when you do not need it.

    # --- The theme ---------------------------------------------------------------------------------------------

    # A clone of the theme on this machine. preview.ps1 links it into the local site, so that a change to the
    # theme shows right away. Used when the folder exists.
    # ThemePath             = '../my-theme'

    # The git repository of the theme. preview.ps1 clones it when there is no folder above. git signs in the
    # way it does for any other clone, so a private repository works when a plain git clone of it does.
    # ThemeRepository       = 'https://dev.azure.com/<organization>/<project>/_git/<repository>'

    # The feed in Azure Artifacts that the pipeline of the theme publishes to. publish.ps1 takes the newest
    # package from it, with the Azure CLI (az login).
    # ThemeFeedOrganization = 'https://dev.azure.com/<organization>'
    # ThemeFeedProject      = '<project>'
    # ThemeFeed             = '<feed>'

    # A personal access token of Azure DevOps with the scope Packaging (Read), for when you do not sign in with
    # az login. It is a secret in plain text: this file is the only one it may be in. AZURE_DEVOPS_EXT_PAT in the
    # environment wins over it.
    # ThemeFeedToken        = '<token>'

    # --- The live site -----------------------------------------------------------------------------------------

    # The keys of the live site are not written here, or in any other file. The scripts take them from the
    # environment, set in your session, see AGENTS.md:
    #
    #   $env:GHOST_LIVE_ADMIN_API_KEY        the Admin API key of a custom integration
    #   $env:GHOST_LIVE_STAFF_ACCESS_TOKEN   your own staff access token, for preview.ps1 -FromLive
    #
    # or from a secret with that name in a vault of the module Microsoft.PowerShell.SecretManagement, and
    # otherwise they ask you.

    # The vault that has them. Without this line every vault you registered is searched.
    # SecretVault           = '<vault>'
}
