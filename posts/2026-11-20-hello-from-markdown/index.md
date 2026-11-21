---
title: Hello from Markdown
status: draft
tags: [Meta]
custom_excerpt: This post is a Markdown file in a repository. The folder it is in gives it its date and its address.
feature_image: images/cover.png
feature_image_alt: A blue banner
---

This post is written in Markdown. The lines at the top, between the dashes, say what Ghost needs to know about it:
its title, whether it is a draft, its tags and the picture above it.

## Pictures

A picture is a file in the folder `images`, next to this file. The post points to it by its path:

![A green banner](images/diagram.png)

It is uploaded when the post is, and only once: as long as the file does not change, the post keeps the picture it
has.

## Everything Markdown can do

- Lists, **bold**, *italic* and `code`
- [Links](https://docs.ghost.org)

```powershell
./preview.ps1    # look at this post on your own machine
```

> [!NOTE]
> The theme of the site shows notes like this one in a box of their own.

| Front matter     | What it sets                                |
| ---------------- | ------------------------------------------- |
| `title`          | The title of the post                       |
| `status`         | `draft` or `published`                      |
| `tags`           | The tags, between brackets                  |
| `custom_excerpt` | The text in lists and previews              |
| `feature_image`  | The picture above the post                  |
