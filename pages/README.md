# Pages

A folder per page of the site: `about/index.md` is the page with the slug `about`. The lines between the dashes
are its fields, and what follows is its content, in Markdown, which may contain HTML.

```markdown
---
title: "About"
status: published
custom_excerpt: "Who writes this, and why."
---

The page, in Markdown.
```

Some pages are not reached by their own address but through the theme: its `routes.yaml` shows the page
`the-microsoft-dsc-handbook` at `/books/the-microsoft-dsc-handbook/`, and a course lists the posts that have its
tag. Such a route only works on a site that has the page, which is why the pages are here.

`./preview.ps1` and `./publish.ps1` create or update the pages from these files. `./pull.ps1` writes a folder for
every page that was made on the live site and is not here yet. [AGENTS.md](../AGENTS.md) has the details.
