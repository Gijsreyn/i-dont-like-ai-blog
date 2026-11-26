---
title: "I rebuilt this blog in six days: a new theme, an SDK and a public repository"
status: published
tags: ["PowerShell", "Meta"]
custom_excerpt: "I rewrote my blog site with a new theme, using an SDK I created for Ghost's REST API."
feature_image: images/cover.jpg
feature_image_alt: ''
visibility: members
featured: true
---

I have rewritten my blog site with a new theme, using an SDK. The reason is that the development of my theme was getting more and more out of sync, because I never automated it. That led me to create an SDK, explore Ghost's REST API, and open up my repository so people can see the Markdown files.

This post is how that went: what the SDK can do, how my posts became Markdown files, how I preview and publish them now, and how the images got a house style. If you run a Ghost site yourself, you can take all of it.

## A theme that got out of sync

I decided to develop my own theme. I didn't want to purchase one from Ghost's website, and with AI these days, I wanted to give it a try.

The theme was sitting in a repository that wasn't maintained or tested, so the versions of the theme got out of sync. Every time I had to make a modification, I had the burden of checking it locally, setting up a bunch of stuff manually, and hoping all the settings were correct. The result speaks for itself now:

![Figure 1: Repository layout Ghost theme][04]

## Creating the SDK

Back in the day, I looked at the documentation of the [Ghost API][01], but it didn't make sense to me. With the new content, it was easier to create one. With a reference module and some AI usage, I was able to create such an SDK instantly.

The SDK is a PowerShell module called [Ghost][02], and it's on the PowerShell Gallery:

```powershell
Install-PSResource -Name Ghost
Connect-Ghost -Url 'https://example.ghost.io' -AdminApiKey (Read-Host -Prompt 'Admin API key' -AsSecureString)
```

Version 0.1.0 went out on November 20. It's at 0.8.0 now and has 42 commands, for posts, pages, tags, images, themes, members and tiers. A few of them:

```powershell
# The five drafts that were changed most recently
Get-GhostPost -Filter 'status:draft' -Order 'updated_at desc' -Limit 5

# The ten tags with the most posts
Get-GhostTag -Include 'count.posts' -Order 'count.posts desc' -Limit 10

# Pack the folder of a theme, upload it and make it the active theme
New-GhostTheme -Path ./my-theme -Activate
```

### What the API allows, and what it doesn't

There are a couple of things that the Admin API lets you work on when using the module. These are just a few of those limits before you use it, because they explain why some commands work the way they do:

- You never send the Admin API key itself. It has the form `<id>:<secret>`, and the module turns it into a token that Ghost accepts for five minutes. After that it makes a new one.
- Ghost stores a post as a Lexical document, the format of its own editor. Luckily there is a Markdown card. Put one in the document and Ghost keeps your Markdown as you wrote it, and renders it itself.
- With themes, an integration can upload one and activate it, and that's where it ends. Listing, downloading or deleting a theme is something you still do in Ghost Admin.
- For the settings of a theme, the ones under **Settings > Design**, the key of an integration isn't enough. You need a staff access token.
- Once an image is uploaded, it stays. The API has no way to delete one.

### The theme, in sync again

This is the command for the problem I started with:

```powershell
Sync-GhostTheme -Path ./dist/my-theme.zip
```

```text
Action    Name     Version Fingerprint  Path
------    ----     ------- -----------  ----
Updated   my-theme 1.4.0   7927f0a8f243 /repo/dist/my-theme.zip
```

It only uploads when the site doesn't show that theme yet. An integration can't ask Ghost which theme is live, so the command adds a file to the package, `assets/ghost-theme-fingerprint.txt`, with a hash of every file of the theme. The next run reads that file from the site.

## From the editor to Markdown files

My posts were a combination of both: `/markdown` cards, and posts fully written in Markdown. I wanted to open-source this, so I always have a backup, but can also apply CI/CD tooling to it if I want to.

`Export-GhostPost` wrote the posts of the site to files, with their images:

```powershell
Export-GhostPost -Path ./posts -IncludeImage
```

Every post is a folder now, and there are 103 of them:

```text
posts/
  2026-11-26-my-post/
    index.md
    images/
      cover.jpg
```

An `index.md` starts with front matter, and the Markdown follows:

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

`Sync-GhostPost` goes the other way and makes the site match the files. A post that didn't change is left alone:

```powershell
Sync-GhostPost -Path ./posts -Recurse
```

```text
Action       Status     Slug          Path
------       ------     ----          ----
Created      draft      my-post       /repo/posts/2026-11-20-my-post/index.md
Unchanged    published  older-post    /repo/posts/older-post.md
```

## Preview and publish

Now that everything is extracted, a bunch of scripts help me to instantly see a preview locally:

```powershell
./preview.ps1 -Open
```

It starts a Ghost site on my own machine, with the theme and the posts of the repository.

The publish runs as a dry run, to see what has changed. That was the safe way while I was migrating all the posts, lessons, etcetera.

```powershell
./publish.ps1 -WhatIf
```

On GitHub, three workflows do the same:

| Workflow  | Runs                                     | What it does                                                        |
| --------- | ---------------------------------------- | ------------------------------------------------------------------- |
| `Check`   | For a pull request                       | Installs a Ghost site on the runner and creates the posts on it     |
| `Lint`    | For a pull request                       | Looks for links that lead nowhere                                   |
| `Publish` | For a change to `main`, daily or by hand | Brings the theme, tags, pages and posts of the live site up to date |

`Publish` is a dry run too, until I start it by hand and say otherwise.

## A house style for the images

I normally use image generators for the pictures of my posts, and I wanted them to be consistent. Every picture should follow the style of the site, with the title of the post on the cover in that same style.

The style isn't written down anywhere. `cover.ps1` reads the colours and the font from the theme, every time a picture is made:

```powershell
# The prompt for the image generator, with the style of the site around it
./cover.ps1 -Prompt 'a laptop that receives two settings from a document'

# The cover is the title of the post, set as on the site, next to that picture
./cover.ps1 posts/<folder> -Image ~/Downloads/picture.png -Open
```

The generator is asked for a picture without any text, because it can't spell. The title is set afterwards, in the font of the site. A cover is 1600 by 900, and it's made again when the title of the post or the theme changes.

The covers of the older posts got the house style too, with `./cover.ps1 -Adopt`.

## An open repository

The [public repo][03] is for people to contribute if they want to. Open an issue, or change the Markdown file and send a pull request. `Check` needs no secrets, so it also runs for a pull request from a fork.

The challenge there is expanding on membership tiers. You don't want your members to be open-source or let people know who has subscribed to what.

## What is left

The challenges that are left are expanding the SDK and, for a future post (spoiler), working through the GitHub Actions.

And that's about it. If you run Ghost yourself, give the module a try, and if you spot something in a post that isn't right, you now know where the Markdown file is.

[01]: https://docs.ghost.org/admin-api
[02]: https://www.powershellgallery.com/packages/Ghost
[03]: https://github.com/Gijsreyn/i-dont-like-ai-blog
[04]: images/theme-repository-layout.png
