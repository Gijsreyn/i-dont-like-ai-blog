# Tags

A file per tag of the site: `release-notes.md` is the tag with the slug `release-notes`. The lines between the
dashes are its fields, and the text below them is its description.

```markdown
---
name: Release notes
accent_color: "#ff5500"
---

What changed, version by version.
```

`./preview.ps1` and `./publish.ps1` create or update the tags from these files. `./pull.ps1` writes a file for
every tag that was made on the live site and is not here yet. [AGENTS.md](../AGENTS.md) has the details.
