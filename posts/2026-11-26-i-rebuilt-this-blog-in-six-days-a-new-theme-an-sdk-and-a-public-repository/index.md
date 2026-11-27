---
title: "I rebuilt this blog in six days: a new theme, an SDK and a public repository"
status: published
tags: ["PowerShell", "Meta"]
custom_excerpt: "How I built a PowerShell module for Ghost, moved my posts into Markdown files, and made the blog easier to preview and publish."
feature_image: images/cover.jpg
feature_image_alt: ''
visibility: members
featured: true
---

I recently took 6 days to rebuild this blog, to avoid any more frustration with Ghost themes. To change themes I would have to copy and paste my local site setup to each of the themes, and cross my fingers that I'd correctly configured each of the settings. I wanted to be able to test different themes on my site without as much hassle.

To start, I created a PowerShell SDK to use with the Ghost REST API, to move my posts to a public repository of my choosing. This post will outline what I did and provide code samples for what you can reuse with your Ghost site.

## Why I started with the theme

I used Ghost theme repository to create my first theme with the aid of an AI. I didn't use it to maintain my Ghost site theme and so they eventually drifted apart.

![Figure 1: Repository layout Ghost theme][04]

## Connect to Ghost from PowerShell

Since then, I've read the Ghost Admin API documentation. During my last attempt, I used it to create a PowerShell module to upload and activate a theme.

I used a couple of examples found on GitHub to write the module which I've named Ghost, available in the PowerShell Gallery. Once installed, use the API key found in your Ghost integration to connect to your site.

```powershell
Install-PSResource -Name Ghost
Connect-Ghost -Url 'https://example.ghost.io' -AdminApiKey (Read-Host -Prompt 'Admin API key' -AsSecureString)
```

The first version was released on November 20, 2020. Since then, I've updated it to version 0.8.0, and added commands to create and manage posts, pages, tags and images on a Ghost site. I've also added commands to manage members and tiers of members on a Ghost site, as well as themes. Here are three examples:

```powershell
# The five drafts that were changed most recently
Get-GhostPost -Filter 'status:draft' -Order 'updated_at desc' -Limit 5

# The ten tags with the most posts
Get-GhostTag -Include 'count.posts' -Order 'count.posts desc' -Limit 10

# Pack the folder of a theme, upload it and make it the active theme
New-GhostTheme -Path ./my-theme -Activate
```

### Admin API limits that affect the workflow

The integration uses an authentication key to generate a short duration token which is then used to connect to the integration.

It does not send the key. It does send the token.

- Post content: Posts on Ghost are stored as Lexical documents. I can include Markdown in Ghost documents using a Markdown card, and Ghost will render the markdown.
- An integration can use Ghost API to upload a theme and activate it on Ghost. Admin of Ghost is used to manage theme files.
- Modifying any of the settings in Settings > Design on Ghost would require a staff access token instead of the integration key.
- Currently, the Ghost API doesn't support removal of images.

## Sync the theme without uploading it every time

`Sync-GhostTheme` solves the problem I started with. Give it a packaged theme:

```powershell
Sync-GhostTheme -Path ./dist/my-theme.zip
```

```text
Action    Name     Version Fingerprint  Path
------    ----     ------- -----------  ----
Updated   my-theme 1.4.0   7927f0a8f243 /repo/dist/my-theme.zip
```

An integration can't find the active theme on Ghost, therefore, to check if the uploaded theme is different from the one currently active, the integration includes a fingerprint of the theme files with the asset file `assets/ghost-theme-fingerprint.txt`. Prior to this project, I used various methods to include Markdown in my posts including Markdown cards in the Ghost editor.

## Move posts from Ghost to Markdown

I want to be able to use Git to manage my posts. This way I could use Git to do diffs to see changes made. This is what I was doing at the time of the movement.

I used `Export-GhostPost` to write the posts and their images to disk:

```powershell
Export-GhostPost -Path ./posts -IncludeImage
```

At the time of this movement, I had 103 folders containing posts. Each folder contains the following:

```text
posts/
  2026-11-26-my-post/
    index.md
    images/
      cover.jpg
```

- `index.md` containing the Ghost metadata of the post, in YAML, using front matter.
- `body.md` containing the post.
- `image1.png` being an image associated with the post.
- `image2.png` another image associated with the post.

```markdown
---
title: My post
status: draft
tags: [News, Releases]
feature_image: images/cover.jpg
---

Some **bold** text, and a picture:

![A diagram](images/diagram.png)
```

To sync these changes back to Ghost use `Sync-GhostPost`. To run Ghost on your computer and view the changes you've made, run the following script:

```powershell
Sync-GhostPost -Path ./posts -Recurse
```

```text
Action       Status     Slug          Path
------       ------     ----          ----
Created      draft      my-post       /repo/posts/2026-11-20-my-post/index.md
Unchanged    published  older-post    /repo/posts/older-post.md
```

## Preview and publish

Once running, you can preview what changes you've made to the repository posts, in a browser window, without affecting the live site.

```powershell
./preview.ps1 -Open
```

In this project I'm using `cover.ps1` to generate images to use as post covers.

I've also used this script to generate some images to use as post thumbnails. I ask the script to create a post cover, and it adds the title of the post to the image using the site's font. This image has dimensions 1600 x 900. I've used `./cover.ps1 -Adopt` to update the previous images to follow this style. I've also included some code in this script to pull the theme's colors and fonts to use in the prompts, to generate more images. I've implemented a dry run feature in the publish script to check the difference between the files on the server and on your local machine prior to uploading.

```powershell
./publish.ps1 -WhatIf
```

GitHub runs three workflows:

| Workflow  | Runs                                     | What it does                                                                            |
|-----------|------------------------------------------|-----------------------------------------------------------------------------------------|
| `Check`   | For a pull request                       | Installs a Ghost site on the runner and creates the posts on it                         |
| `Lint`    | For a pull request                       | Looks for links that lead nowhere                                                       |
| `Publish` | For a change to `main`, daily or by hand | Reports what would change, or applies changes on a manual run with the dry run disabled |

I look at `Publish` summary to review what is about to be uploaded. Neither a change to `main` or a scheduled run results in any changes being published.

## Create covers that match the theme

I generate the illustrations for my posts. To achieve cover designs in keeping with the site's appearance I used `cover.ps1` to read the theme's colors and font and use them as prompts to generate more covers for my posts. I prefer to not have the generator attempt to write the title of my posts.

```powershell
# The prompt for the image generator, with the style of the site around it
./cover.ps1 -Prompt 'a laptop that receives two settings from a document'

# The cover is the title of the post, set as on the site, next to that picture
./cover.ps1 posts/<folder> -Image ~/Downloads/picture.png -Open
```

Once the generator produces the illustration, my cover script adds the title using the site's font.

The covers can easily be edited to reflect changes to the post's title. I used `./cover.ps1 -Adopt` to bring earlier post covers into the same style as more recent covers.

## Contribute to the blog

I've implemented GitHub Actions to automatically build and publish any changes made to the `main` branch. If you find errors in any of the posts, please edit the file and create a pull request. The `Check` workflow is automatically run on pull requests to verify the changes don't contain secrets.

Posts are publicly available. Personal member information and tier level are not. I'll need to implement additional measures to protect member data to expand the membership service.

## Next steps

In the meantime, the [PowerShell module][02] may be used to sync a post to Ghost from Git as well.

I'll also explain how to use GitHub Actions in a separate post.

[01]: https://docs.ghost.org/admin-api
[02]: https://www.powershellgallery.com/packages/Ghost
[03]: https://github.com/Gijsreyn/i-dont-like-ai-blog
[04]: images/theme-repository-layout.png