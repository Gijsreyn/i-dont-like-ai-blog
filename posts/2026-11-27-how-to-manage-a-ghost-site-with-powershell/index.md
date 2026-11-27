---
title: "How to manage a Ghost site with PowerShell"
status: published
tags: ["PowerShell"]
custom_excerpt: "Install the Ghost module, start a site on your own machine, and manage posts, themes and members from the command line."
feature_image: images/cover.jpg
feature_image_alt: ''
---

Ghost Admin is useful for single posts. It's not great for multiple posts, mass publishing, testing a site design locally, or deploying to a live site. My [PowerShell Ghost Module][01] integrates the [Ghost Admin API][02] and is used to perform those more repetitive actions. I am the sole maintainer of the project and am not associated with the Ghost Foundation.

In this article, you learn how to:

- Install the Ghost PowerShell Module.
- Create, change and publish posts with commands.
- Publish posts from Markdown files.
- Use the module to set up a Ghost site on your local computer.
- Use the site to design a theme.
- Use the module to manage users on a Ghost site, copy the content of the site to your local site and run commands on the live site from your PowerShell pipeline.

## Prerequisites

This article mostly references actions performed on a site hosted on your computer.

- [PowerShell 7][03]. The module also runs on Windows PowerShell 5.1.
- [Node.js][04] versions 22 or 24.
- A live Ghost 5.0+ site, with an Admin API key. To create the key go to Settings > Integrations in Ghost Admin and create a custom integration.

## Install the module

The module is named Ghost and comes from the PowerShell Gallery.

1. Install the module:

   ```powershell
   Install-PSResource -Name Ghost
   ```

2. List its commands:

   ```powershell
   Get-Command -Module Ghost
   ```

## Start a Ghost site on your own machine

There is some consistency in the names of the commands. For instance `Get-` is used to retrieve items, `New-` to create new items, `Set-` to modify existing items. Likewise `Sync-` and `Export-` are used to perform actions on files. To see examples of command usage use the PowerShell command `Get-Help` with the name of the command of interest, for instance `Get-Help New-GhostPost -Examples`.

1. Create a folder to work in, and go to it:

   ```powershell
   New-Item -Path ./ghost-lab -ItemType Directory
   Set-Location -Path ./ghost-lab
   ```

2. Start the site and connect to it:

   ```powershell
   Start-GhostLocalSite -Connect
   ```

Ghost Local Site: `Start-GhostLocalSite` creates a Ghost site in the directory of your choice.

The first run takes a few minutes. Ghost is downloaded to .local-ghost, started on http://localhost:2368, the owner of the site is created along with an admin API key which is linked to your current session. The command also provides the url of the site and the username to log in to the admin section of the site, available at http://localhost:2368/ghost.

![Figure 1: Starting Ghost locally with one command][06]

To start the site the next time, run the command again.

```powershell
Connect-Ghost -Url 'https://example.ghost.io' -AdminApiKey (Read-Host -Prompt 'Admin API key' -AsSecureString)
```

> [!NOTE]
> To change site settings on the local site, use `Connect-Ghost` with the URL of the local site and the admin API key of the integration you created on that site.

## Run your first commands

1. List the posts of the site. A new site has one:

   ```powershell
   Get-GhostPost
   ```

   ```text
   Title       Status    Visibility PublishedAt           Id
   -----       ------    ---------- -----------           --
   Coming soon published public     11/27/2026 6:37:41 AM 6b092535b341b939dc72eac9
   ```

1. Create a tag, and a draft that has the tag:

   ```powershell
   New-GhostTag -Name 'How-to' -Description 'Step-by-step articles.'
   New-GhostPost -Title 'Hello from PowerShell' -Markdown 'A first post, written in **Markdown**.' -Tags 'How-to'
   ```

   ```text
   Title                 Status Visibility PublishedAt Id
   -----                 ------ ---------- ----------- --
   Hello from PowerShell draft  public                 6b092551b341b939dc72eb8f
   ```

1. Change the draft. A post that comes through the pipeline is the post that is changed:

   ```powershell
   Get-GhostPost -Slug 'hello-from-powershell' |
       Set-GhostPost -CustomExcerpt 'Created without opening the editor.' -Featured
   ```

1. Publish the draft:

   ```powershell
   Get-GhostPost -Slug 'hello-from-powershell' | Publish-GhostPost
   ```

   To change site settings on a live site, use `Connect-Ghost` with the URL of the live site and the admin API key of the integration you created on that site.

1. Find posts with a filter of Ghost, and ask only for the fields you need:

   ```powershell
   Get-GhostPost -Filter 'status:draft' -Order 'updated_at desc' -Limit 5
   Get-GhostPost -Filter 'tag:how-to' -Fields title, slug, status
   ```

1. See what a command would do before it does it:

   ```powershell
   Get-GhostPost -Filter 'tag:how-to' | Remove-GhostPost -WhatIf
   ```

   ```text
   What if: Performing the operation "Delete a post" on target "6b092551b341b939dc72eb8f".
   ```

> [!TIP]
> The admin API key of the integration is never sent to the site. The API uses this key to create a token which is valid for 5 minutes. The module takes care of creating new tokens as and when required.

## Publish posts from Markdown files

The command will ask for confirmation prior to executing because on a live site it has the potential to send emails to users. In a script you can include `-Confirm:$false` to suppress the confirmation prompt. The post will be created at `http://localhost:2368/hello-from-powershell/` .

1. Start a post:

   ```powershell
   New-GhostPostFile -Title 'My first post from a file' -Path ./posts -Tags 'How-to'
   ```

   The first time you create a pipeline of commands to interact with a live site it's recommended to use `-WhatIf` to gain confidence in what the command will do.

   ```text
   posts/
     2026-11-27-my-first-post-from-a-file/
       index.md
   ```

Post as a Markdown file can be synced with the site using `Sync-GhostPost`. This is especially useful if you wish to publish content from a git repository.

1. Ask what the files would change on the site:

   ```powershell
   Sync-GhostPost -Path ./posts -Recurse -WhatIf
   ```

   ```text
   Action       Status     Slug                         Path
   ------       ------     ----                         ----
   WouldCreate  draft      my-first-post-from-a-file    C:\source\ghost-lab\posts\2026-11-27-my-first-post-from-a-file\index.md
   ```

This command will create a new folder for each post. The post's date is used to name the folder, the rest of the folder name is used to define the post's slug.

1. Publish through the file. In the front matter, change `status: draft` to `status: published`, add the line `visibility: members`, and sync again:

   ```text
   Action       Status     Slug                         Path
   ------       ------     ----                         ----
   Updated      published  my-first-post-from-a-file    C:\source\ghost-lab\posts\2026-11-27-my-first-post-from-a-file\index.md
   ```

Good to know when you work this way:

1. Open the file named `index.md`. Front matter is used to define each post's properties and is found between the three hyphens. Change the example text to create your post.

The action field will now be `Created`. Run the command once more and the action field will be `Unchanged`.
Only modified files are sent with the command. This means the command can be used on each file in each push.

## Develop a theme on the local site

Posts are accompanied by pictures. Put the pictures in a folder located next to index.md and the pictures will be included in the post. Pictures are uploaded once and repeated if they are modified.

1. Use the folder of your own theme. If you have none, copy the theme that Ghost comes with:

   ```powershell
   Copy-Item -Path ./.local-ghost/content/themes/source -Destination ./my-theme -Recurse
   ```

   - `status: published` means the post is uploaded to the site and available for users to read. No other changes are made to the site.

2. Link the folder into the site and make it the active theme:

   ```powershell
   Start-GhostLocalSite -ThemePath ./my-theme -Connect -AsOwner
   ```

   - The last change made to the post in Ghost admin is not saved and will be lost if the post's file is modified and uploaded to the site.

3. Read the settings of the theme, the ones that Ghost Admin shows under **Settings > Design**:

   ```powershell
   Get-GhostThemeSetting
   ```

   ```text
   Key                           Value              Type    Default
   ---                           -----              ----    -------
   navigation_layout             Logo in the middle select  Logo in the middle
   site_background_color         #ffffff            color   #ffffff
   header_and_footer_color       Background color   select  Background color
   title_font                    Modern sans-serif  select  Modern sans-serif
   body_font                     Modern sans-serif  select  Modern sans-serif
   ...
   ```

4. Change a setting:

   ```powershell
   Set-GhostThemeSetting -Setting @{ title_font = 'Elegant serif' }
   ```

   ```text
   Key        Value         Type   Default
   ---        -----         ----   -------
   title_font Elegant serif select Modern sans-serif
   ```

   You should use the local site to test out any modifications you make to the theme. Changes made to the theme can be viewed instantly on the local site together with other posts.

5. Keep the settings in a file, so that every site you start looks the same. Save this as `settings.psd1`:

   ```powershell
   @{
       title_font      = 'Elegant serif'
       post_feed_style = 'Grid'
   }
   ```

   Then send the ones that differ:

   ```powershell
   Set-GhostThemeSetting -Setting (Import-PowerShellDataFile -Path ./settings.psd1)
   ```

> [!IMPORTANT]
> In `package.json` change the `name` field from `source` to `my-theme` to avoid overwriting the original file.

## Deploy the theme to a live site

To test the changes you've made to the theme, make sure to use the site on which the theme is installed. Changes made to the template will be visible on the site. A file with the extension yaml in the theme will also be used on the site.

```powershell
Sync-GhostTheme -Path ./my-theme -WhatIf
Sync-GhostTheme -Path ./my-theme
```

```text
Action    Name      Version  Fingerprint   Path
------    ----      -------  -----------   ----
Updated   my-theme  1.7.6    84ace200cf68  C:\source\ghost-lab\my-theme
```

Only the files in the directory which have been modified since the last sync will be updated on the site. If the value of a theme setting is not valid, the Ghost API will return an error with the list of valid values.

The key of an integration gives Ghost permission to perform various actions on the site. The site owner is able to create a theme and test it on the live site using `Connect-Ghost` and the integration key. Once the theme is created, the site owner can test a site deploy with `Sync-GhostTheme`. This command compiles the files of the theme and uploads it to the site.

## Copy the content of a live site

`Unchanged` is used to describe the command as the site already contains the files of the theme. Ghost uses a hash of each file in the theme to determine if the theme on the site is the same as the theme the owner is trying to upload.

```powershell
Connect-Ghost -Url 'https://example.ghost.io' -AdminApiKey (Read-Host -Prompt 'Staff access token' -AsSecureString)
Export-GhostContent -Path ./live.json -AbsoluteUrl

Start-GhostLocalSite -Connect -AsOwner
Import-GhostContent -Path ./live.json -Replace
```

- **The export only reads.** Nothing changes on the live site.
Only an integration can upload and activate a theme. To remove a theme or add a `routes.yaml` file, you must use Ghost Admin.
Copying posts, pages and tags from the live site to the local site will allow you to see your posts on the local site while you create the theme. Use both the live site and the local site to export and import content. This should be done using the integration owner's API key to obtain a staff access token.
- `-AbsoluteUrl` allows images on the live site to be displayed on the local site.
- `-Replace` removes all content on the local site first.

## Manage members and tiers

Members and the tiers they subscribe to have commands of their own:

```powershell
New-GhostMember -Email 'jamie@example.com' -Name 'Jamie' -Labels 'Early reader'
Get-GhostMember -Filter 'label:early-reader'
Get-GhostTier
```

```text
Email             Name  Status Subscribed Created               Id
-----             ----  ------ ---------- -------               --
jamie@example.com Jamie free   True       11/27/2026 6:40:29 AM 6b0925dd907af647b19e0f36
```

- Unless you use the `-Force` switch, `Import-GhostContent` will not import content from a local site.

## Run the commands in a pipeline

- Any content, including drafts, created using the site should be treated as part of the site and kept out of the repository.

```yaml
- name: Publish the theme and the posts
  shell: pwsh
  env:
    GHOST_ADMIN_API_URL: ${{ secrets.GHOST_ADMIN_API_URL }}
    GHOST_ADMIN_API_KEY: ${{ secrets.GHOST_ADMIN_API_KEY }}
  run: |
    Install-PSResource -Name Ghost -TrustRepository
    Connect-Ghost
    Sync-GhostTheme -Path ./my-theme
    Sync-GhostPost -Path ./posts -Recurse
```

Keep these results out of pipeline logs. Pipeline runs should not require user interaction to provide the integration key. When environment variables GHOST_ADMIN_API_URL and GHOST_ADMIN_API_KEY are set, `Connect-Ghost` can be used to set up integration between the theme and post content.

## Clean up resources

When you are done, stop the local site or remove it:

```powershell
Stop-GhostLocalSite      # stops the site and keeps its content
Remove-GhostLocalSite    # stops the site and deletes it, content included
```

`Remove-GhostLocalSite` asks for confirmation. After that, delete the folder `ghost-lab`.

In this pipeline, first the theme is updated and then the posts are updated.

## Next steps

More information about front matter, images and removal of posts can be found in the help file of `Sync-GhostPost`.

- Check out the Ghost Admin API to understand the commands.
- Read how this blog is published with those commands.

[01]: https://www.powershellgallery.com/packages/Ghost
[02]: https://docs.ghost.org/admin-api
[03]: https://learn.microsoft.com/powershell/scripting/install/installing-powershell
[04]: https://nodejs.org/
[06]: images/start-ghost-local-site.png