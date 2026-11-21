# I don't like AI: the posts

Hi! This repository contains every blog post of my site, [idontlikeai.dev](https://www.idontlikeai.dev). I write
them here as plain Markdown files, look at them on a copy of the site on my own machine, and when I merge one to
`main` it goes to the real site by itself.

I keep it public because I like to be able to show how a post came to be, and because it is the easiest way for
you to tell me that I got something wrong.

## Reading

The site is the place to read: <https://www.idontlikeai.dev>. If you would rather read the source, every post is
a folder in [posts](posts), named after its date and its address, with the text in `index.md` and the pictures
next to it:

```text
posts/
  2026-11-20-hello-from-markdown/
    index.md
    images/
```

A post with `status: draft` at the top is one I am still working on. It is here, but not on the site yet. The
pages of the site, such as the ones about my books, are in [pages](pages), and its tags in [tags](tags).

## Found a mistake?

A typo, a broken link, a command that does not do what I say it does: open an issue, or change the Markdown file
and send a pull request. A pull request is checked automatically: the posts are loaded into a throwaway Ghost
site, which shows that nothing is broken.

## How it works

The site runs on [Ghost](https://ghost.org). A few small scripts are all there is to it:

```powershell
./new-post.ps1 'A title'    # a folder for a new post, with the lines at the top filled in
./preview.ps1 -Open         # a Ghost site on my own machine, with these posts and the theme of the site
./publish.ps1 -WhatIf       # what would change on the real site
./pull.ps1                  # what I made on the real site and is not here yet, such as a tag
```

The scripts are thin. The work is done by [Ghost](https://www.powershellgallery.com/packages/Ghost), a PowerShell
module I wrote for the Admin API of Ghost, which the scripts install from the PowerShell Gallery. The theme of the
site lives in a repository of its own, which is private, and no key of the site is in any file here.

[AGENTS.md](AGENTS.md) has the whole routine, step by step: starting a post, looking at it, publishing it, and
the setup that is needed once. I wrote it for the coding agent I work with and for myself, for when I have
forgotten how it went. If you want to run your own Ghost site from a folder of Markdown files, it is also the
place to start: take the scripts, change `site.psd1`, and you are most of the way there.
