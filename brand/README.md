# The house style

The pictures of a post look like the site. The site is the theme, so the style is not written down here: it is
read from the theme, every time a picture is made. Change the theme, and the next cover follows.

## The routine

```powershell
# 1. The prompt: say what the picture shows. The style of the site is put around it, and it is on the clipboard.
./cover.ps1 -Prompt 'a laptop that receives two settings from a document'

# 2. Paste it in the image generator and save what comes back.

# 3. The cover: the title of the post, set as on the site, next to that picture.
./cover.ps1 posts/<folder> -Image ~/Downloads/picture.png -Open
```

The cover is written as `images/cover.jpg`, which is what `feature_image` in the front matter points to. The
picture is kept next to it as `images/cover-art.jpg`, so the cover can be made again.

A post without a picture has a cover too: the sign of the site stands where the picture would. The generator is
asked for a picture without any text, because it cannot spell: the title is set here, in the font of the site.

## What happens by itself

Only the picture needs me. The rest follows the post:

| When                           | What happens                                                                     |
| ------------------------------ | -------------------------------------------------------------------------------- |
| `./new-post.ps1 'A title'`     | The post gets a cover with its title, and the line `feature_image` that names it |
| `./preview.ps1`                | The covers that are behind are made again, before the posts are sent             |
| `./publish.ps1`                | The same. With `-WhatIf` it only says which                                      |

A cover is behind when its title, its picture or the style of the theme changed since it was made. It carries
a mark of those three, which is how this is known without a list. A cover that is still right is not
touched, so nothing is uploaded for it. The covers that take part are the ones whose post says
`feature_image: images/cover.jpg`: another picture there, or none, and the post is left alone.

```powershell
./cover.ps1 -Refresh          # what the scripts above do: make the covers that are behind
./cover.ps1 -Refresh -WhatIf  # only say which
./cover.ps1 -All              # every cover again, also the ones that are right
```

The workflow `Publish` sends the covers as they are in the repository, so commit the cover with the post. A
cover that is behind on its post is made again by the step `Make the covers that are behind`, before the step
`Deploy to Ghost`: a title that was changed on GitHub then still gets its cover. It is made on the runner and
not in the repository: `./preview.ps1` makes the file here again.

## What is taken from the theme

| On a cover                           | In the theme                                                                |
| ------------------------------------ | --------------------------------------------------------------------------- |
| The background                       | `--color-bg-primary`, and the clouds behind every page: `body::before`      |
| The title                            | Inter at weight 800, the letters 0.02em closer: `.hero-title`               |
| The colour of the title              | `--color-text-primary`                                                      |
| The name of the site                 | The words of `.hero-title-accent` in `home.hbs`, in `--gradient-neon`       |
| The picture                          | A card: the corners, the line and the glow of `.post-card`                  |
| The place of a picture that is not   | The ring and the small sun of `.post-card-image-placeholder`                |
| The colours a generator may use      | `--color-bg-primary`, `--color-primary`, `--gradient-accent`, `--gradient-neon` |

The colours, the clouds and the name are read from the theme itself: `assets/css/screen.css` and `home.hbs`. What
was read is kept in [theme.json](theme.json), so that a machine without the theme makes the same cover and git
shows when the style changed. The shapes, such as the sizes, the corners and the weight of the title, are copied
by hand in `tools/cover.py`: when the theme changes one of those, change it there.

The theme is found as `./preview.ps1` finds it: `ThemePath` in `site.local.psd1`, or `-ThemePath`.

## A cover

| Rule    | Value                                                                              |
| ------- | ---------------------------------------------------------------------------------- |
| Shape   | 16:9, which is what a card of the site shows                                       |
| Size    | 1600 by 900                                                                        |
| File    | `images/cover.jpg` in the folder of the post                                       |
| Weight  | 500 KB at most                                                                     |
| Says so | `feature_image_alt` in the front matter: one sentence about what the picture shows |

```powershell
./cover.ps1 -Check          # every cover against these rules
./cover.ps1 -Sheet -Open    # all covers next to each other, in brand/contact-sheet.jpg
```

The theme prints `feature_image_alt` under the cover, on the post and on the page of the blog, so it is read by
everybody.

## Pictures inside a post

- **A generated picture** starts with the same prompt, asked wide, and is then brought to the width of the site:

  ```powershell
  ./cover.ps1 -Prompt 'three servers that share one clock' -Wide
  ./cover.ps1 -Picture ~/Downloads/servers.png -Post posts/<folder> -Name servers.jpg
  ```

- **A screenshot of a terminal** shows the command and its answer and nothing around them. One terminal, one
  colour scheme, one font size and one width for every post, so that two screenshots under each other line up.
  Save it as PNG, and look for a name, a key or an address that should not be in it.
- The theme rounds the corners of every picture in a post, so a picture does not bring corners of its own.

## The font

The titles of the site are set in Inter, which the theme takes from Google Fonts. The two weights a cover needs
are in [fonts](fonts), with the licence they come with, the SIL Open Font License: [fonts/OFL.txt](fonts/OFL.txt).
