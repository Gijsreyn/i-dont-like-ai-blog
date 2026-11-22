# Instructions for coding agents, and a reminder for me

This repository holds the posts, the pages and the tags of <https://www.idontlikeai.dev> as Markdown files, and a few
scripts that take a post from an idea to the live site. It is public. The site runs on Ghost; the scripts use
the PowerShell module [Ghost](https://www.powershellgallery.com/packages/Ghost), which they install themselves.

## The routine

```powershell
./new-post.ps1 'Why I do not like AI' -Tags Opinion -Open   # 1. start the post
./preview.ps1 -Open                                         # 2. look at it on http://localhost:2370
./publish.ps1 -Local                                        # 3. optional: rehearse the publish on this machine
git switch -c post/why-i-do-not-like-ai                     # 4. branch, commit, push, pull request
```

1. **Start.** `./new-post.ps1 '<title>'` creates `posts/<date>-<slug>/index.md` and a folder `images` next to
   it. The post starts with `status: draft`.
2. **Write and look.** Write in `index.md`, put pictures in `images`, and run `./preview.ps1` again whenever you
   want to see the result: it takes seconds and only sends what changed. It prints the address of every post. A
   draft is not in the lists of the site, so open it by that address.
3. **Rehearse**, when you want to see a publish happen first: `./publish.ps1 -Local` does everything for real,
   but on the site on this machine.
4. **Pull request.** The workflow `Check` loads the posts into a Ghost site on the runner. It touches nothing
   else.
5. **Go live.** Set `status: published` in the front matter and merge to `main`. The workflow `Publish` runs for
   that merge as a dry run, and its summary shows what would change on the live site. Then start the workflow by
   hand with `dry_run` cleared, which publishes. Merged as a draft, the post is created on the live site as a
   draft, which is a good way to look at it there first: Ghost Admin has a preview link.
6. **Change it later.** Edit the file and merge again. Only a file that differs from its post is sent.

To publish from this machine instead of through the workflow:

```powershell
./publish.ps1 -WhatIf      # show what would change on the live site; this only reads
./publish.ps1              # publish to the live site, after one confirmation
./publish.ps1 -SkipTheme   # the posts only
```

## Rules for an agent

- **The live site is not yours to touch.** Ask before you run anything that connects to it, and that includes
  a run that only reads: `./publish.ps1` and `./pull.ps1` without `-Local`, with or without `-WhatIf`,
  `./preview.ps1 -FromLive`, and starting the workflow `Publish`. Everything else stays on this machine and needs
  no question: `./new-post.ps1`, `./preview.ps1`, `./publish.ps1 -Local`, `./pull.ps1 -Local`.
- **Do not set `status: published`** unless you are asked to. A post goes live because its author says so.
- **Do not commit, push or merge** unless you are asked to. A merge to `main` starts the workflow `Publish`.
- **Nothing private in a file that git tracks.** No key, no token, and not where the theme comes from: its
  repository, the Azure DevOps organization, the project and the feed. Those are in `site.local.psd1`, which git
  ignores, in a secret vault, or in the secrets of the repository. Do not print a key either.
  `./tools/Test-Secret.ps1` checks this, and `./preview.ps1` and the workflows run it: a finding stops them. Take
  the secret out of the file; do not skip the check or change a rule in `.semgrep/secrets.yml` to get past it.
- **The words are the author's.** Fix what you are asked to fix. Do not rewrite a post, change its tone or add
  to it on your own; point out what you notice instead.
- **Check your work with `./preview.ps1`.** It fails on front matter that Ghost does not take. Say so when you
  could not run it.
- **A script passes `-WhatIf` on by name**, `-WhatIf:$WhatIfPreference`, to every command of the module that
  changes something. The `-WhatIf` of a script does not reach the commands of a module by itself; without it a
  dry run changes the site.

## A post

A post is a folder in `posts`, named after its date and its slug:

```text
posts/
  2026-11-20-why-i-do-not-like-ai/
    index.md
    images/
      cover.png
      diagram.png
```

The date in the name is the publication date, and the rest is the slug, the last part of the address: this one
becomes `/why-i-do-not-like-ai/`. `index.md` starts with front matter between two lines of three dashes:

```markdown
---
title: Why I do not like AI
status: draft
tags: [Opinion, AI]
custom_excerpt: Shown in lists and previews, instead of the first words of the post.
feature_image: images/cover.png
feature_image_alt: A robot that shrugs
---

The post, in Markdown. A picture is a file next to the post:

![What happens when you ask twice](images/diagram.png)
```

| Front matter        | What it sets                                                                    |
| ------------------- | ------------------------------------------------------------------------------- |
| `title`             | The title of the post                                                           |
| `status`            | `draft`, or `published` to put the post on the site                             |
| `tags`              | The tags; the first one is the main tag. A tag that does not exist is created   |
| `custom_excerpt`    | The text in lists and previews                                                  |
| `feature_image`     | The picture above the post: a file next to it, or an address                    |
| `feature_image_alt` | What that picture shows, for whoever cannot see it                              |
| `featured`          | `true` to mark the post as featured                                             |
| `published_at`      | The date and time of publication, when the date of the folder is not enough     |
| `slug`              | The last part of the address, when it should differ from the name of the folder |

Every other field of a post in Ghost works too: `visibility`, `authors`, `canonical_url`, and the `meta_`, `og_`
and `twitter_` fields. A key that Ghost does not know is an error, so a typing mistake does not go unnoticed.

Good to know:

- **An email is never sent.** Publishing puts the post on the site and nothing more.
- **Pictures are uploaded once.** As long as the file of a picture does not change, the post keeps the picture it
  has. A picture that is no longer used stays on the site: Ghost cannot remove one.
- **This repository decides.** A change that is made to a post in Ghost Admin is overwritten the next time its
  file changes. Fields that the front matter does not mention are left as they are on the site.
- **Removing a folder can remove the post.** The workflow `Publish` lists the post as "Would remove" and removes
  it when it is told to, see [What a publish does](#what-a-publish-does). `./publish.ps1` never removes a post.
- **Renaming a folder makes a new post**, because the slug changes. The old post is then one whose file was
  removed. To rename a folder and keep its post, put the old slug in the front matter as `slug`.

## Tags

A post that names a tag creates it, with nothing but that name. Everything else a tag has, its description, its
color, its image and the fields for search engines, is in a file in `tags`: `tags/release-notes.md` is the tag
with the slug `release-notes`.

```markdown
---
name: Release notes
accent_color: "#ff5500"
---

What changed, version by version.
```

The text below the front matter is the description. The other keys are the fields of a tag in Ghost:
`feature_image` (an address), `visibility`, `canonical_url`, and the `meta_`, `og_` and `twitter_` fields.

`./preview.ps1` and `./publish.ps1` create or update the tags from these files, before the posts, and only what
differs. To change a tag, change its file. `description: ""` in the front matter clears the description.

Think twice before you remove the file of a tag. When the workflow `Publish` removes that tag from the live
site, every post loses it. That includes the posts that were written in Ghost Admin and are not in this
repository.

## Pages

A page is a folder in `pages` with an `index.md`: `pages/about/index.md` is the page with the slug `about`. It
has the same front matter as a post and the same handling of pictures. Its content is Markdown, which may
contain HTML.

Some pages are not reached by their own address but through the theme. Its `routes.yaml` shows the page
`the-microsoft-dsc-handbook` at `/books/the-microsoft-dsc-handbook/`, and the page of a course lists the posts
that have its tag. Such a route answers "not found" on a site that does not have the page, which is why the
pages are here: `./preview.ps1` and `./publish.ps1` create or update them, after the tags and before the posts.

A new book or course needs three things: its page here, its route in the `routes.yaml` of the theme, and for a
course the tag that its lessons carry.

## The settings of the theme

The theme has settings of its own, the ones under **Settings > Design** in Ghost Admin: the fonts, the layout,
the addresses of my profiles, the id for the visitor count. A new site starts with the defaults of the theme, so
the site on this machine only looks like the live one when it has the same values. They are in two files:

| File                        | What is in it                                                        |
| --------------------------- | -------------------------------------------------------------------- |
| `theme-settings.psd1`       | Every setting that anybody may know. It is in the repository         |
| `theme-settings.local.psd1` | What is a secret or differs per site. Git ignores it. Its values win |

`PrivateThemeSettings` in `site.psd1` lists the keys that belong in the second file: `content_api_key`, which
every site has its own of, `azure_blob_sas_uri`, which has a signature in it, and the ids and addresses of the
services behind the site: `google_analytics_id`, `github_client_id` and `github_device_proxy_url`.
`./pull.ps1` divides the settings over the two files by that list.

The workflow has no second file. It takes such a value from a secret of the repository, passed as an
environment variable: `GHOST_THEME_SETTING_` followed by the key in capitals. That wins from both files. The
secrets are listed under [Setup, once](#setup-once).

A setting without a secret is left as it is on the live site. For another private setting, add its key to
`PrivateThemeSettings`, a line for its secret under `env` in `.github/workflows/publish.yml`, and a row to that
list.

`./preview.ps1` and `./publish.ps1` send the settings that differ from the site and leave a setting that is in
neither file as it is there. A key that the theme does not have, or a choice that is not one of its options, is
an error from Ghost that names it.

Ghost lets only an owner or an administrator read and change these settings: it takes a **staff access token**,
not the key of the integration. The site on this machine has one of its own, so nothing is needed there. For the
live site it is `GHOST_LIVE_STAFF_ACCESS_TOKEN`, in the environment or in a vault. Without it `./publish.ps1`
and `./pull.ps1` say that they leave the settings alone and do the rest. That token may do everything its owner
may do, so giving it to the workflow as a secret is a decision, not a default.

## What was made on the live site

This repository decides what the sites show, so something that was made in Ghost Admin has to come here first,
or the site on this machine does not have it and the next publish does not know about it.

```powershell
./pull.ps1          # a file for every tag and every page of the live site that has none here yet,
                    # and the settings of the theme when there is a staff access token
./pull.ps1 -Force   # also overwrite the files that differ: the folders become what the live site has
./pull.ps1 -Local   # the same, from the site on this machine
```

`pull.ps1` only reads from the site. Look at what it wrote with `git status` and `git diff`, and commit it.

- **Pages keep their Markdown.** A page that was written in Markdown cards comes back as that Markdown. Any
  other page comes back as the HTML that Ghost renders for it; the column `Content` says which. Such a page
  looks the same in most cases, but after the next publish it is one Markdown card on the site and no longer
  the cards of the editor. Look at it with `./preview.ps1` first.
- **Drafts are written too**, and this repository is public. Leave out of a commit what is not to be read yet.
- **Pictures stay where they are**: a page from the live site points to its pictures on the live site.
- **Posts are not pulled.** A post that was written in Ghost Admin, such as the lessons of a course, is not in
  this repository. `./preview.ps1 -FromLive` copies everything of the live site to the site on this machine.

`pull.ps1` deletes nothing: a tag or a page without a file stays on the site, and a file without one stays
here.

## The site on this machine

```powershell
./preview.ps1              # start the site and bring its posts up to date
./preview.ps1 -Open        # the same, and open it in the browser
./preview.ps1 -FromLive    # first make it a copy of the live site: its posts, pages, tags and settings
./preview.ps1 -Stop        # stop it; its content is kept
./preview.ps1 -Remove      # stop it and delete it
```

The first run installs Ghost in `.local-ghost`, which git ignores, and takes a few minutes. The script prints the
account to sign in to Ghost Admin with. The site has an Admin API key of its own, which the scripts create and
read from `.local-ghost/local-ghost.json`: nothing has to be filled in for it.

The site has the theme of the live site when `site.local.psd1` says where the theme is. A folder of the theme on
this machine is linked into the site, so a change to the theme shows as soon as the page is reloaded, next to the
posts. Without a theme the site shows the one Ghost comes with.

`-FromLive` reads the content of the live site and changes nothing there.

## What a publish does

`./publish.ps1` on this machine, and the workflow `Publish` for every change to `main`, once a day, and by hand:

1. **The theme**, when the newest package of the theme is not the one the site shows. The theme has a repository
   and a pipeline of its own, which publishes it as a package to a feed in Azure Artifacts. The daily run is
   there so that a new theme is noticed without a new post.
2. **The settings of the theme** that differ, when there is a staff access token. See above.
3. **The tags** whose file differs from the tag on the site.
4. **The pages** whose file differs from the page on the site.
5. **The posts** whose file differs from the post on the site.

The workflow does not run `publish.ps1` for all of that. It downloads the package of the theme with
`tools/Get-ThemePackage.ps1` and hands it to the action
[ghost-deploy-action](https://github.com/Gijsreyn/ghost-deploy-action). The action does the theme, the tags, the
pages and the posts, with the same commands of the module Ghost. `./publish.ps1 -SettingsOnly` then sends the
settings of the theme, which go last there. The summary of a run lists what was created, updated and removed.

Two things are different in the workflow:

- **It is a dry run unless you say otherwise.** A push to `main` and the daily run change nothing. Their summary
  shows what would change. To publish, start the workflow by hand and clear `dry_run`. `DRY_RUN` at the top of
  `.github/workflows/publish.yml` decides this.
- **It can remove.** The action compares a push with the commit before it, and lists a post, a page or a tag
  whose file that push removed as "Would remove". A run by hand has no push to compare with. It removes only
  when you give it that commit as `base_ref`, and the log of the dry run names the commit. A run removes ten at
  most and fails when more files were removed. `publish.ps1` and `preview.ps1` never remove anything.

## Setup, once

On this machine:

- [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) 7.4 or later.
- [Node.js](https://nodejs.org/) 22 or 24, for the Ghost site on this machine.
- git, and for publishing the theme from this machine the [Azure CLI](https://aka.ms/azure-cli), signed in.

Copy `site.local.example.psd1` to `site.local.psd1` and fill in where the theme is.

The keys of the live site are in no file. A script looks for a key at the moment it needs it: in the environment
variable, then in a vault of
[SecretManagement](https://learn.microsoft.com/powershell/utility-modules/secretmanagement/overview), and when it
is in neither, it asks for it and does not show what is pasted.

The environment variable is the quickest, and lasts as long as the session:

```powershell
$env:GHOST_LIVE_ADMIN_API_KEY = Read-Host -Prompt 'Admin API key' -MaskInput        # publish.ps1 and pull.ps1
$env:GHOST_LIVE_STAFF_ACCESS_TOKEN = Read-Host -Prompt 'Staff access token' -MaskInput   # preview.ps1 -FromLive
```

To not be asked in every new session, store them once in a vault instead:

```powershell
Install-PSResource -Name Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore
Register-SecretVault -Name 'Local' -ModuleName 'Microsoft.PowerShell.SecretStore' -DefaultVault

Set-Secret -Name 'GHOST_LIVE_ADMIN_API_KEY'        # the Admin API key of a custom integration
Set-Secret -Name 'GHOST_LIVE_STAFF_ACCESS_TOKEN'   # preview.ps1 -FromLive: your own staff access token
```

`Set-Secret` asks for the value. With more than one vault, name the one to use as `SecretVault` in
`site.local.psd1`.

The theme package comes from Azure Artifacts with your own sign-in, `az login`. To not depend on that, put a
personal access token with the scope Packaging (Read) in `site.local.psd1` as `ThemeFeedToken`, next to the three
`ThemeFeed` settings. Git ignores that file, but the token is in plain text there; `AZURE_DEVOPS_EXT_PAT` in the
environment wins over it.

For the workflow `Publish`, the repository needs these secrets under **Settings > Secrets and variables >
Actions**:

| Secret                      | What it is                                                                       |
| --------------------------- | -------------------------------------------------------------------------------- |
| `GHOST_LIVE_ADMIN_API_KEY`  | The Admin API key of a custom integration: Ghost Admin > Settings > Integrations |
| `AZURE_DEVOPS_EXT_PAT`      | A personal access token of Azure DevOps with the scope Packaging (Read)          |
| `AZURE_DEVOPS_ORGANIZATION` | The address of the organization, such as `https://dev.azure.com/my-org`          |
| `AZURE_DEVOPS_PROJECT`      | The project of the feed                                                          |
| `AZURE_ARTIFACTS_FEED`      | The feed that the pipeline of the theme publishes to                             |

Without the last four the workflow publishes the posts and leaves the theme alone. An organization-scoped feed
needs no `AZURE_DEVOPS_PROJECT`. A personal access token ends after a year at most: the workflow then fails on
the theme.

`GHOST_LIVE_STAFF_ACCESS_TOKEN` is optional: with it the workflow also sends the settings of the theme. The
settings that are not in `theme-settings.psd1` then each take a secret of their own:

| Secret                                        | The setting it fills      |
| --------------------------------------------- | ------------------------- |
| `GHOST_THEME_SETTING_CONTENT_API_KEY`         | `content_api_key`         |
| `GHOST_THEME_SETTING_GOOGLE_ANALYTICS_ID`     | `google_analytics_id`     |
| `GHOST_THEME_SETTING_AZURE_BLOB_SAS_URI`      | `azure_blob_sas_uri`      |
| `GHOST_THEME_SETTING_GITHUB_CLIENT_ID`        | `github_client_id`        |
| `GHOST_THEME_SETTING_GITHUB_DEVICE_PROXY_URL` | `github_device_proxy_url` |

A setting without its secret is left as it is on the live site. Ghost Admin shows the values the live site has
now under **Settings > Design**, and your staff access token on your profile.

When these values are available on this machine, you do not have to type them in on GitHub: use
`./set-secrets.ps1` to get them synced. It takes each value from where the scripts take it, the environment,
`site.local.psd1`, `theme-settings.local.psd1` or a vault, and creates or overwrites the secret with the
[GitHub CLI](https://cli.github.com), signed in with `gh auth login`. Run it again whenever a value here changes.
It shows the names and not the values, and leaves a secret alone that has no value here. Only
`-WhatIf -ShowValue` shows the values, in plain text, to check what would be sent: that is for your own eyes, and
an agent does not run it.

```powershell
./set-secrets.ps1 -WhatIf              # which secrets would be set, and where each value comes from
./set-secrets.ps1 -WhatIf -ShowValue   # the same, with the values in plain text
./set-secrets.ps1                      # the Admin API key and the four of the theme package
./set-secrets.ps1 -ThemeSettings       # also the staff access token and the settings of the theme
```

For `-ThemeSettings`, `theme-settings.local.psd1` has to hold the values of the live site, as `./pull.ps1` writes
them: `content_api_key` is another one on the site on this machine.

## Where everything comes from

| What                    | From                                                                 | Public |
| ----------------------- | -------------------------------------------------------------------- | ------ |
| The posts               | This repository                                                      | Yes    |
| The commands            | The module [Ghost](https://www.powershellgallery.com/packages/Ghost) | Yes    |
| The publish in CI       | The action `Gijsreyn/ghost-deploy-action`, in the workflow `Publish` | Yes    |
| Ghost itself            | npm, through Ghost-CLI                                               | Yes    |
| The theme, to work on   | Its git repository, cloned with git as it is set up on this machine  | No     |
| The theme, to publish   | The package its pipeline publishes to a feed in Azure Artifacts      | No     |
| The keys and the tokens | A secret vault or a prompt, the secrets of the repository in CI      | No     |

| File                          | What it is                                                                 |
| ----------------------------- | -------------------------------------------------------------------------- |
| `site.psd1`                   | What everybody may know: the address of the site, the theme name, the port |
| `site.local.psd1`             | Where the theme comes from, on this machine. Git ignores it                |
| `set-secrets.ps1`             | Syncs the secrets of the workflow on GitHub with the values that are here  |
| `tools/Initialize-Site.ps1`   | Reads the settings and installs the module Ghost when it is missing        |
| `tools/Get-SiteSecret.ps1`    | Finds a key of the live site: environment, vault, prompt                   |
| `tools/Get-ThemePackage.ps1`  | Downloads the newest package of the theme from the feed                    |
| `tools/Set-ThemeSetting.ps1`  | Sends the settings of the theme in the two files to a site                 |
| `tools/Save-ThemeSetting.ps1` | Writes the settings of the theme of a site to the two files                |
| `tools/Test-Secret.ps1`       | Looks for secrets in the files git does not ignore, with Semgrep           |
| `.semgrep/secrets.yml`        | The rules for the secrets of this repository: Ghost, Azure SAS, Azure PAT  |

## When something does not work

- **The module Ghost cannot be installed.** `site.psd1` asks for a version that is not on the PowerShell Gallery
  yet. Point the environment variable `GHOST_MODULE_PATH` at the folder of the module to use a local one.
- **`preview.ps1` refuses the folder of the theme.** There is a Ghost site inside it. Remove that one with
  `Remove-GhostLocalSite -Path <folder>`.
- **A post shows the wrong theme or none.** `site.local.psd1` does not say where the theme is, or the folder is
  not there. The script warns about it at the start.
- **`publish.ps1` stops and names an environment variable.** It could not find the key and could not ask, as in
  a session that is not interactive. Store the key in a vault, see above.
- **`preview.ps1` stops with "A secret is in a file".** It names the file, the line and the rule, not the text.
  Move the value to `site.local.psd1`, `theme-settings.local.psd1` or a vault. A key that was ever committed has
  to be replaced on the site: git keeps it.
- **`preview.ps1` stops because Semgrep could not check.** The check downloads its rules and needs the internet.
  `./preview.ps1 -SkipSecretScan` leaves it out for once.
- **Port 2370 is taken.** Change `LocalPort` in `site.psd1`, or stop what uses it.
