@{
    # Everything here is public. A key or a token never goes in this file: see site.local.example.psd1.

    # The address of the live site.
    LiveUrl              = 'https://i-dont-like-ai.ghost.io'

    # The folder with the posts, one folder per post.
    PostsPath            = 'posts'

    # The folder with the pages, one folder per page.
    PagesPath            = 'pages'

    # The settings of the theme, as under Settings > Design in Ghost Admin. The ones listed as private are a
    # secret or differ per site: they are kept in theme-settings.local.psd1, which git ignores.
    ThemeSettingsPath    = 'theme-settings.psd1'
    PrivateThemeSettings = @(
        'content_api_key'
        'google_analytics_id'
        'azure_blob_sas_uri'
        'github_client_id'
        'github_device_proxy_url'
    )

    # The folder with the tags, one file per tag.
    TagsPath             = 'tags'

    # The Ghost module of the PowerShell Gallery that the scripts need at least.
    GhostVersion         = '0.6.1'

    # The site on your own machine: the folder it is installed in, which git ignores, and its port.
    LocalPath            = '.local-ghost'
    LocalPort            = 2370

    # The name of the theme, as it is in the package.json of the theme. Where the theme comes from is not public
    # and is set in site.local.psd1 or in the environment.
    ThemeName            = 'i-dont-like-ai'
}
