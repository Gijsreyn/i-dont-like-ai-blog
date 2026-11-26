# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10.1", "fonttools>=4.40"]
# ///
"""The pictures of a post in the style of the site. The style is read from the theme, not written down here.

cover.ps1 runs this file with uv, which brings Python, Pillow and fontTools by itself. It only reads and writes
files on this machine.

    cover POST [--image FILE] [--focus X,Y]   the cover of a post: its title next to its picture
    refresh FOLDER... [--all] [--dry-run]     the covers that are missing or no longer what their post says
    adopt FOLDER --plan FILE [--dry-run]      the posts that have a cover of their own: give them the house style
    prompt SUBJECT [--wide]                   the text for an image generator, with the style in it
    picture SOURCE OUTPUT                     a picture for inside a post, sized and made light
    check FOLDER...                           every cover of these posts and pages against the rules
    sheet OUTPUT --posts FOLDER               the covers next to each other, as a card cuts them

The style comes from two files of the theme: the variables under :root and the clouds behind the page in
assets/css/screen.css, and the name of the site in home.hbs. What was read is kept in brand/theme.json, so that
a machine without the theme makes the same covers, and so that git shows when the style changed.

A cover carries a mark of what it was made from: the title, the picture and the style. That is how
refresh knows which covers to make again, and why a cover that is still right is left alone, byte for byte.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "brand" / "fonts"
SNAPSHOT = ROOT / "brand" / "theme.json"

WIDTH, HEIGHT = 1600, 900
SCALE = 2
BUDGET_KB = 500
JPEG_QUALITY = 90
COVER_NAME = "cover.jpg"      # what the cards of the site and a shared link show
ART_NAME = "cover-art.jpg"    # the picture inside it, kept so that the cover can be made again
ART_SIZE = 1200
LAYOUT = 3                    # one higher after a change to how a cover is drawn: every cover is then made again
MARK = b"cover:"              # in front of the mark of a cover, in the comment of its file

MARGIN = 112                  # the list view of a tag and a shared link cut a little off every side
CARD = 600                    # the picture, a square, as a card of the site: round corners, a line, a glow
GAP = 64                      # between the title and the picture
LEFT_SIZES = range(100, 72, -4)   # the title next to the picture: down to 76, and in five lines at most
LEFT_LINES = 5
TOP_SIZES = range(104, 40, -4)    # a title that needs to be smaller than that goes across the top instead,
TOP_LINES = 3                     # in three lines at most
TOP_Y = 120                       # where it starts there
TOP_ROOM = 250                    # and how high it may get
TOP_PICTURE = 860                 # the picture below it, on the right: this wide,
TOP_PICTURE_Y = 400               # from here at the highest,
TOP_FOOT = 790                    # down to here

# What the theme gives when a value cannot be read. The same values as in assets/css/screen.css at the time of
# writing; brand/theme.json wins over them.
FALLBACK = {
    "name": "I don't like AI",
    "background": "#02030a",
    "surface": "#0c1020",
    "primary": "#00d4ff",
    "accent": ["#00d4ff", "#5b86e5"],
    "neon": ["#ff00ff", "#00ffff"],
    "text": "#ffffff",
    "text_secondary": "#b8bcc8",
    "text_muted": "#8892b0",
    "border": [0, 212, 255, 0.2],
    "glow": [0, 212, 255, 0.3],
    "radius": 12,
    "clouds": [[12, 8, [110, 90, 255], 0.11, 42], [88, 42, [0, 212, 255], 0.06, 38],
               [62, 96, [255, 0, 255], 0.055, 42]],
}

PICTURES = {".png", ".jpg", ".jpeg", ".webp"}


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(2)


def rgb(colour: str) -> tuple[int, int, int]:
    colour = colour.strip().lstrip("#")
    if len(colour) == 3:
        colour = "".join(part * 2 for part in colour)
    return tuple(int(colour[index:index + 2], 16) for index in (0, 2, 4))


def rgba(text: str) -> list[float] | None:
    match = re.search(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)", text)
    if not match:
        return None
    return [int(match.group(1)), int(match.group(2)), int(match.group(3)), float(match.group(4) or 1)]


def read_theme(theme: Path) -> dict:
    """The style as the theme has it now. A value that is not found keeps what the snapshot or FALLBACK says."""
    style: dict = {}
    css = (theme / "assets" / "css" / "screen.css").read_text(encoding="utf-8")
    root = re.search(r":root\s*\{(.*?)\n\}", css, re.S)
    variables = dict(re.findall(r"--([a-z0-9-]+)\s*:\s*([^;]+);", root.group(1))) if root else {}

    def value(name: str) -> str:
        text = variables.get(name, "")
        inner = re.fullmatch(r"\s*var\(--([a-z0-9-]+)\)\s*", text)
        return variables.get(inner.group(1), "") if inner else text

    def hexes(name: str) -> list[str]:
        return [found.lower() for found in re.findall(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b", value(name))]

    for key, name in (("background", "color-bg-primary"), ("surface", "color-bg-secondary"),
                      ("primary", "color-primary"), ("text", "color-text-primary"),
                      ("text_secondary", "color-text-secondary"), ("text_muted", "color-text-muted")):
        if hexes(name):
            style[key] = hexes(name)[0]
    for key, name in (("accent", "gradient-accent"), ("neon", "gradient-neon")):
        if len(hexes(name)) >= 2:
            style[key] = hexes(name)[:2]
    for key, name in (("border", "color-border-light"), ("glow", "shadow-neon")):
        if rgba(value(name)):
            style[key] = rgba(value(name))
    radius = re.fullmatch(r"\s*([\d.]+)rem\s*", value("radius-xl"))
    if radius:
        style["radius"] = round(float(radius.group(1)) * 16)

    # The clouds behind every page: body::before.
    behind = re.search(r"body::before\s*\{(.*?)\}", css, re.S)
    clouds = []
    for x, y, colour, reach in re.findall(
            r"radial-gradient\(\s*ellipse at ([\d.]+)% ([\d.]+)%\s*,\s*(rgba?\([^)]*\))\s*0%\s*,\s*transparent ([\d.]+)%",
            behind.group(1) if behind else ""):
        red, green, blue, alpha = rgba(colour)
        clouds.append([float(x), float(y), [red, green, blue], alpha, float(reach)])
    if clouds:
        style["clouds"] = clouds

    # The name of the site, as the home page says it.
    home = theme / "home.hbs"
    if home.is_file():
        name = re.search(r'class="hero-title-accent"\s*>([^<]+)<', home.read_text(encoding="utf-8"))
        if name:
            style["name"] = name.group(1).strip()
    return style


def load_style(theme: str | None, keep: bool = True) -> dict:
    """The style to work with. With the theme at hand it is read again, and the snapshot follows when it differs.

    keep=False leaves the snapshot as it is, for a run that only looks.
    """
    style = dict(FALLBACK)
    kept = json.loads(SNAPSHOT.read_text(encoding="utf-8")) if SNAPSHOT.is_file() else {}
    style.update(kept)
    if theme and (Path(theme) / "assets" / "css" / "screen.css").is_file():
        style.update(read_theme(Path(theme)))
        if style != kept and keep:
            text = json.dumps(style, indent=2, ensure_ascii=False) + "\n"
            SNAPSHOT.write_text(text, encoding="utf-8", newline="\n")
            print(f"The style of the theme changed, or is read for the first time: {SNAPSHOT.name} follows it.")
            if kept:
                print("  The covers that are there still have the old style: ./cover.ps1 -All makes them again.")
    elif not kept:
        print("The theme is not at hand and there is no brand/theme.json: the style built into this file is used.")
    return style

def font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    file = FONTS / f"Inter-{weight}.ttf"
    if not file.is_file():
        fail(f"{file} is not there. It is the font of the titles of the site and belongs in the repository.")
    # The basic layout is the one Pillow has on every machine: on Windows it has no other. The same cover
    # everywhere matters more here than what the other layout adds, and the kerning is done below.
    return ImageFont.truetype(str(file), size, layout_engine=ImageFont.Layout.BASIC)


_kerning: dict[str, tuple] = {}


def kerning(face: ImageFont.FreeTypeFont, left: str, right: str) -> float:
    """How much closer or further two letters stand than their widths say, in pixels: the kerning of the font.

    The basic layout does not read it, because Inter keeps it in its GPOS table. fontTools does.
    """
    if face.path not in _kerning:
        from fontTools.ttLib import TTFont

        file = TTFont(face.path)
        table = file["GPOS"].table
        indexes: list[int] = []
        for record in table.FeatureList.FeatureRecord:
            if record.FeatureTag == "kern":
                indexes += [index for index in record.Feature.LookupListIndex if index not in indexes]
        lookups = []
        for index in sorted(indexes):
            pairs = [getattr(sub, "ExtSubTable", sub) for sub in table.LookupList.Lookup[index].SubTable]
            lookups.append([(sub, set(sub.Coverage.glyphs)) for sub in pairs if sub.LookupType == 2])
        _kerning[face.path] = (file.getBestCmap(), lookups, file["head"].unitsPerEm, {})
    names, lookups, units, known = _kerning[face.path]
    first, second = names.get(ord(left)), names.get(ord(right))
    if (first, second) not in known:
        total = 0
        for lookup in lookups:
            # Of a lookup, the first table that knows the pair decides.
            for sub, covered in lookup:
                if first not in covered:
                    continue
                if sub.Format == 1:
                    found = [record for record in sub.PairSet[sub.Coverage.glyphs.index(first)].PairValueRecord
                             if record.SecondGlyph == second]
                    if not found:
                        continue
                    value = found[0].Value1
                else:
                    row = sub.Class1Record[sub.ClassDef1.classDefs.get(first, 0)]
                    value = row.Class2Record[sub.ClassDef2.classDefs.get(second, 0)].Value1
                total += getattr(value, "XAdvance", 0) or 0
                break
        known[(first, second)] = total
    return known[(first, second)] * face.size / units


def places(text: str, face: ImageFont.FreeTypeFont, tracking: float) -> list[float]:
    """Where each letter of a line starts, and after the last one where the line ends."""
    x, result = 0.0, []
    for index, letter in enumerate(text):
        if index:
            x += kerning(face, text[index - 1], letter) + tracking
        result.append(x)
        x += face.getlength(letter)
    return result + [x]


def kilobytes(path: Path) -> int:
    return -(-path.stat().st_size // 1024)


def save(image: Image.Image, output: Path, mark: str = "") -> None:
    """Writes a picture in the format of its extension, as small as it gets without showing it."""
    output.parent.mkdir(parents=True, exist_ok=True)
    extension = output.suffix.lower()
    if extension in (".jpg", ".jpeg"):
        # subsampling=0 keeps the colour as sharp as the light: thin coloured lines and letters stay clean.
        image = image.convert("RGB")
        extra = {"comment": MARK + mark.encode()} if mark else {}
        image.save(output, "JPEG", quality=JPEG_QUALITY, subsampling=0, optimize=True, progressive=True, **extra)
    elif extension == ".png":
        image.save(output, "PNG", optimize=True)
    elif extension == ".webp":
        image.save(output, "WEBP", quality=JPEG_QUALITY, method=6)
    else:
        fail(f"{output.name}: write a picture as .jpg, .png or .webp.")
    weight = kilobytes(output)
    print(f"{output}: {image.width}x{image.height}, {weight} KB")
    if weight > BUDGET_KB:
        print(f"  That is more than {BUDGET_KB} KB. A .jpg is the smallest for a picture with gradients.")


def glow_mask(size: tuple[int, int], centre: tuple[float, float], radii: tuple[float, float]) -> Image.Image:
    """A grey picture that is white at centre and black from the radii on, even in between."""
    small = (size[0] // 8, size[1] // 8)
    values = []
    for y in range(small[1]):
        for x in range(small[0]):
            dx = ((x + 0.5) * 8 - centre[0]) / radii[0]
            dy = ((y + 0.5) * 8 - centre[1]) / radii[1]
            values.append(max(0.0, 255 * (1 - (dx * dx + dy * dy) ** 0.5)))
    grey = Image.new("F", small)
    grey.putdata(values)
    return grey.resize(size, Image.Resampling.BICUBIC).convert("L")


def gradient(size: tuple[int, int], colours: list[str]) -> Image.Image:
    """Two colours from the top left to the bottom right: linear-gradient(135deg, ...) of the theme."""
    small = (32, 32)
    grey = Image.new("F", small)
    grey.putdata([255 * (x + y) / 62 for y in range(32) for x in range(32)])
    grey = grey.resize(size, Image.Resampling.BILINEAR).convert("L")
    return ImageOps.colorize(grey, black=colours[0], white=colours[1])


def background(style: dict) -> Image.Image:
    """What is behind every page of the site: near-black, three faint clouds, and the stars."""
    size = (WIDTH, HEIGHT)
    image = Image.new("RGB", size, style["background"])
    for x, y, colour, alpha, reach in style["clouds"]:
        centre = (x / 100 * WIDTH, y / 100 * HEIGHT)
        # A CSS ellipse reaches to the farthest corner; the cloud is gone at "reach" percent of that.
        radii = tuple(max(c, s - c) * 2 ** 0.5 * reach / 100 for c, s in zip(centre, size))
        mask = glow_mask(size, centre, radii).point(lambda v: round(v * alpha))
        image.paste(Image.new("RGB", size, tuple(colour)), (0, 0), mask)
    # The stars are at the same places on every cover.
    stars = random.Random(7)
    draw = ImageDraw.Draw(image, "RGBA")
    for _ in range(46):
        x, y = stars.uniform(0, WIDTH), stars.uniform(0, HEIGHT)
        radius, alpha = stars.choice((1.0, 1.4)), stars.uniform(0.22, 0.40)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(255, 255, 255, round(255 * alpha)))
    return image


def rounded(size: tuple[int, int], radius: int) -> Image.Image:
    """A mask with round corners, drawn four times as large and brought back, which makes it smooth."""
    large = Image.new("L", (size[0] * 4, size[1] * 4), 0)
    ImageDraw.Draw(large).rounded_rectangle((0, 0, large.width - 1, large.height - 1), radius * 4, fill=255)
    return large.resize(size, Image.Resampling.LANCZOS)


def sign(cover: Image.Image, style: dict, centre: tuple[int, int], ring: int) -> None:
    """The sign of the site, for a cover without a picture: a ring around a small sun, as the theme draws it in
    .post-card-image-placeholder. It stands on the background, without a card around it."""
    x, y = centre
    halo = glow_mask(cover.size, centre, (ring * 2.4, ring * 2.4)).point(lambda v: round(v * 0.14))
    cover.paste(Image.new("RGB", cover.size, style["primary"]), (0, 0), halo)
    red, green, blue, alpha = style["border"]
    large = Image.new("RGBA", (cover.width * 2, cover.height * 2), (0, 0, 0, 0))
    ImageDraw.Draw(large).ellipse((2 * (x - ring), 2 * (y - ring), 2 * (x + ring), 2 * (y + ring)),
                                  outline=(red, green, blue, round(255 * alpha * 1.5)), width=SCALE * 2)
    cover.alpha_composite(large.resize(cover.size, Image.Resampling.LANCZOS))
    sun = round(ring * 0.28)
    shine = glow_mask(cover.size, centre, (sun * 1.6, sun * 1.6)).point(lambda v: round(v * 0.5))
    cover.paste(Image.new("RGB", cover.size, style["primary"]), (0, 0), shine)
    corner = (round(x - sun / 2), round(y - sun / 2))
    cover.paste(gradient((sun, sun), style["neon"]), corner, rounded((sun, sun), sun // 2))


def card(cover: Image.Image, style: dict, art: Image.Image, box: tuple[int, int, int, int]) -> None:
    """A picture as .post-card of the theme, at a place: first its glow (--shadow-neon), then the picture, cut to
    fill the place from its middle, then its line."""
    left, top, right, bottom = box
    size = (right - left, bottom - top)
    radius = style["radius"] * SCALE
    red, green, blue, alpha = style["glow"]
    halo = Image.new("RGBA", cover.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).rounded_rectangle(box, radius, fill=(red, green, blue, round(255 * alpha)))
    cover.alpha_composite(halo.filter(ImageFilter.GaussianBlur(10 * SCALE)))
    cover.paste(ImageOps.fit(art.convert("RGB"), size, Image.Resampling.LANCZOS), (left, top), rounded(size, radius))
    red, green, blue, alpha = style["border"]
    line = Image.new("RGBA", cover.size, (0, 0, 0, 0))
    ImageDraw.Draw(line).rounded_rectangle((left, top, right - 1, bottom - 1), radius,
                                           outline=(red, green, blue, round(255 * alpha)), width=SCALE)
    cover.alpha_composite(line)


def wrap(text: str, face: ImageFont.FreeTypeFont, width: int, tracking: float) -> list[str]:
    lines: list[str] = []
    for word in text.split():
        candidate = f"{lines[-1]} {word}" if lines else word
        if lines and places(candidate, face, tracking)[-1] <= width:
            lines[-1] = candidate
        else:
            lines.append(word)
    return lines


def write(target: ImageDraw.ImageDraw, position: tuple[float, float], text: str, face: ImageFont.FreeTypeFont,
          fill, tracking: float = 0.0) -> None:
    """A line of text from the left of its baseline, each letter at its own place."""
    for letter, x in zip(text, places(text, face, tracking)):
        target.text((position[0] + x, position[1]), letter, font=face, fill=fill, anchor="ls")


def fit_title(title: str, sizes: range, column: int, room: int, most: int) -> tuple | None:
    """The largest of these sizes at which a title fits a column: its font, lines, step and tracking, or nothing."""
    for size in sizes:
        face = font("ExtraBold", size)
        tracking = -0.02 * size
        lines = wrap(title, face, column, tracking)
        step = round(size * 1.12)
        widest = max(places(line, face, tracking)[-1] for line in lines)
        if len(lines) <= most and step * len(lines) <= room and widest <= column:
            return face, lines, step, tracking
    return None


def set_title(title: str) -> tuple[str, ImageFont.FreeTypeFont, list[str], int, float, bool]:
    """Where the title of a cover goes and how it is set: the layout, the font, the lines, the step between them,
    the tracking, and whether it fits that way.

    "left": next to the picture, when it fits there in five lines without getting small. "top": a long title goes
    across the whole width instead, in three lines at most, with the picture below it.
    """
    column = WIDTH - MARGIN - CARD - GAP - MARGIN
    room = CARD - 34 * SCALE - 20 * SCALE
    found = fit_title(title, LEFT_SIZES, column, room, LEFT_LINES)
    if found:
        return "left", *found, True
    found = fit_title(title, TOP_SIZES, WIDTH - 2 * MARGIN, TOP_ROOM, TOP_LINES)
    if found:
        return "top", *found, True
    # Not even there, such as one word that is wider than the cover: at the smallest size, as it comes.
    size = TOP_SIZES[-1]
    face = font("ExtraBold", size)
    return "top", face, wrap(title, face, WIDTH - 2 * MARGIN, -0.02 * size), round(size * 1.12), -0.02 * size, False


def render(style: dict, title: str, art: Image.Image | None) -> Image.Image:
    """The cover: the title, the picture as a card, and the name of the site in the bottom left corner.

    A title that is not long stands on the left with the picture on its right. A long one goes across the top,
    with the picture as a wide card below it on the right. Without a picture the sign of the site is in its place.
    """
    cover = background(style).convert("RGBA")
    layout, face, lines, step, tracking, fits = set_title(title)
    foot = (HEIGHT - CARD) // 2 + CARD
    if layout == "left":
        y = (HEIGHT - CARD) // 2
        box = (WIDTH - MARGIN - CARD, y, WIDTH - MARGIN, y + CARD)
        ring = 170
    else:
        y = TOP_Y
        box = (WIDTH - MARGIN - TOP_PICTURE, max(TOP_PICTURE_Y, y + step * len(lines) + 56), WIDTH - MARGIN, TOP_FOOT)
        ring = 150
    if art:
        card(cover, style, art, box)
    else:
        # In the middle of where a picture would be on the left, and where a picture would end at the top.
        centre = ((box[0] + box[2]) // 2 if layout == "left" else box[2] - 250, (box[1] + box[3]) // 2)
        sign(cover, style, centre, ring)

    # The name of the site in the bottom left corner, as .hero-title-accent of the home page: the neon gradient,
    # with its glow. It is at the same place on every cover.
    name = font("ExtraBold", 17 * SCALE)
    mask = Image.new("L", cover.size, 0)
    write(ImageDraw.Draw(mask), (MARGIN, foot), style["name"], name, 255)
    area = mask.getbbox()
    if area:
        shine = Image.new("RGBA", cover.size, (*rgb(style["primary"]), 0))
        shine.putalpha(mask.filter(ImageFilter.GaussianBlur(7 * SCALE)).point(lambda v: round(v * 0.5)))
        cover.alpha_composite(shine)
        colours = gradient((area[2] - area[0], area[3] - area[1]), style["neon"])
        cover.paste(colours, area[:2], mask.crop(area))

    # The title: .hero-title of the theme, weight 800, the letters a little closer, always straight.
    if not fits:
        print("  The title is too long for a cover: it is set at the smallest size and runs off it.")
    draw = ImageDraw.Draw(cover)
    for index, line in enumerate(lines):
        write(draw, (MARGIN, y + index * step + face.size * 0.82), line, face, style["text"], tracking)
    return cover.convert("RGB")


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        quote = value[0]
        value = value[1:-1]
        value = value.replace('\\"', '"') if quote == '"' else value.replace("''", "'")
    return value


def front_matter(file: Path) -> dict[str, str]:
    """The keys of the front matter that a cover needs. Not a YAML parser: one key per line."""
    lines = file.read_text(encoding="utf-8-sig").splitlines()
    found: dict[str, str] = {}
    if not lines or lines[0].strip() != "---":
        return found
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^(title|feature_image|feature_image_alt|status|custom_template)\s*:\s*(.*?)\s*$", line)
        if match:
            found[match.group(1)] = unquote(match.group(2))
    return found


def posts(folders: list[str]) -> list[tuple[Path, dict[str, str]]]:
    """Every index.md of the posts and pages in these folders, the newest folder first."""
    files: list[Path] = []
    for folder in folders:
        files += Path(folder).glob("*/index.md")
    return [(file, front_matter(file)) for file in sorted(files, key=lambda file: file.parent.name, reverse=True)]

def square(source: Path, focus: str) -> Image.Image:
    """The largest square of a picture, as close around the focus as its edges allow."""
    try:
        focus_x, focus_y = (float(part) for part in focus.split(","))
    except ValueError:
        fail("Give -Focus as two numbers from 0 to 1 with a comma between them, such as 0.5,0.4.")
    image = ImageOps.exif_transpose(Image.open(source))
    if image.mode in ("RGBA", "LA", "P"):
        image = image.convert("RGBA")
        image = Image.alpha_composite(Image.new("RGBA", image.size, "#000000"), image)
    image = image.convert("RGB")
    side = min(image.size)
    left = min(max(0, round(focus_x * image.width - side / 2)), image.width - side)
    top = min(max(0, round(focus_y * image.height - side / 2)), image.height - side)
    if side < CARD:
        print(f"  {source.name} is {side} wide after the cut, and the cover shows it at {CARD}: it may look soft.")
    return image.crop((left, top, left + side, top + side)).resize((ART_SIZE, ART_SIZE), Image.Resampling.LANCZOS)


def mark_of(style: dict, title: str, art: Path) -> str:
    """What a cover is made from, as one short text. Another title, picture or style gives another one."""
    picture = hashlib.sha256(art.read_bytes()).hexdigest() if art.is_file() else ""
    parts = json.dumps([LAYOUT, title, picture, style], sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(parts.encode("utf-8")).hexdigest()[:32]


def mark_in(cover: Path) -> str:
    """The mark a cover carries, or nothing for a file that is not there or was not made here."""
    if not cover.is_file():
        return ""
    try:
        with Image.open(cover) as image:
            comment = image.info.get("comment", b"")
    except OSError:
        return ""
    comment = comment.encode() if isinstance(comment, str) else comment
    return comment[len(MARK):].decode("ascii", "replace") if comment.startswith(MARK) else ""


def make_cover(style: dict, folder: Path, image: str | None = None, focus: str = "0.5,0.5") -> None:
    index = folder / "index.md"
    if not index.is_file():
        fail(f"{folder} has no index.md: give the folder of a post or a page.")
    fields = front_matter(index)
    title = fields.get("title", "")
    if not title:
        fail(f"{index} has no title to put on a cover.")
    kept = folder / "images" / ART_NAME
    if image:
        if not Path(image).is_file():
            fail(f"{image} is not there.")
        save(square(Path(image), focus), kept)
    art = Image.open(kept) if kept.is_file() else None
    if art is None:
        print("  No picture was given and none is kept: the cover gets the sign of the site in its place.")
    save(render(style, title, art), folder / "images" / COVER_NAME, mark_of(style, title, kept))


def command_cover(arguments: argparse.Namespace) -> None:
    make_cover(load_style(arguments.theme), Path(arguments.post), arguments.image, arguments.focus)


def made_here(fields: dict[str, str]) -> bool:
    """Whether the cover of a post is one of this tool: its front matter names the file this tool writes."""
    return fields.get("feature_image") == f"images/{COVER_NAME}" and bool(fields.get("title"))


def is_current(style: dict, file: Path, fields: dict[str, str]) -> bool:
    folder = file.parent
    mark = mark_of(style, fields["title"], folder / "images" / ART_NAME)
    return mark_in(folder / "images" / COVER_NAME) == mark


def command_refresh(arguments: argparse.Namespace) -> None:
    style = load_style(arguments.theme, keep=not arguments.dry_run)
    made = 0
    for file, fields in posts(arguments.folders):
        if not made_here(fields) or (not arguments.all and is_current(style, file, fields)):
            continue
        made += 1
        if arguments.dry_run:
            print(f"Would make the cover of {file.parent.name} again.")
        else:
            make_cover(style, file.parent)
    if not made:
        print("Every cover is what its post says.")


PLAN_COLUMNS = ("Post", "Do", "Picture", "Focus")
PLAN_CHOICES = ("picture", "title", "skip")


def read_plan(plan: Path) -> list[dict[str, str]]:
    """The rows of the plan. A program for tables may have written it with semicolons, which is taken too."""
    text = plan.read_text(encoding="utf-8-sig")
    first = text.splitlines()[0] if text.strip() else ""
    rows = list(csv.DictReader(text.splitlines(), delimiter=";" if ";" in first else ","))
    for number, row in enumerate(rows, start=2):
        row["Do"] = (row.get("Do") or "").strip().lower()
        if not row.get("Post") or row["Do"] not in PLAN_CHOICES:
            choices = ", ".join(PLAN_CHOICES)
            fail(f"{plan.name}, line {number}: Do is one of {choices}, and Post is the folder of a post.")
    return rows


def write_plan(plan: Path, folders: list[str]) -> int:
    """A plan for every post that has a cover of its own, or none: one row each, with a first guess."""
    rows = []
    for file, fields in sorted(posts(folders), key=lambda found: found[0].parent.name):
        if fields.get("custom_template") or made_here(fields):
            # A post with a template of its own, such as a lesson, shows its picture in another way. And a
            # post that points to images/cover.jpg has the house style already.
            continue
        picture = fields.get("feature_image", "")
        local = bool(picture) and not re.match(r"^https?://", picture) and (file.parent / picture).is_file()
        rows.append({
            "Post": file.parent.name,
            "Do": "picture" if local else "title",
            "Picture": picture if local else "",
            "Focus": "0.5 0.5" if local else "",
        })
    plan.parent.mkdir(parents=True, exist_ok=True)
    with plan.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=PLAN_COLUMNS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return len(rows)


def point_to_cover(index: Path) -> None:
    """Makes feature_image in the front matter of a post name the cover, and leaves the rest of the file as it is."""
    raw = index.read_bytes()
    marked = raw.startswith(b"\xef\xbb\xbf")
    text = raw[3:].decode("utf-8") if marked else raw.decode("utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(newline)
    end = next((number for number in range(1, len(lines)) if lines[number].strip() == "---"), 0)
    if lines[0].strip() != "---" or not end:
        fail(f"{index} has no front matter to put feature_image in.")
    for number in range(1, end):
        match = re.match(r"^feature_image\s*:\s*(.*?)\s*$", lines[number])
        if match:
            # The quotes of the line stay the way the file has them.
            quote = match.group(1)[:1] if match.group(1)[:1] in ("'", '"') else ""
            lines[number] = f"feature_image: {quote}images/{COVER_NAME}{quote}"
            break
    else:
        lines.insert(end, f"feature_image: images/{COVER_NAME}")
    index.write_bytes((b"\xef\xbb\xbf" if marked else b"") + newline.join(lines).encode("utf-8"))


def command_adopt(arguments: argparse.Namespace) -> None:
    plan = Path(arguments.plan)
    if not plan.is_file():
        count = write_plan(plan, arguments.folders)
        print(f"{plan} is written: {count} posts, each with what would be done with its cover.")
        print("  Do = picture   the picture it has now goes on the new cover, next to the title")
        print("  Do = title     the new cover has the title alone: for a picture with words in it")
        print("  Do = skip      the post is left as it is")
        print("  Focus          the point of the picture to cut the square around: 0.5 0.5 is the middle")
        print("Nothing else was changed. Look at the file, then run this again: with -WhatIf to see the covers")
        print("without changing a post, and without it to do it.")
        return

    style = load_style(arguments.theme, keep=not arguments.dry_run)
    root = Path(arguments.folders[0])
    shown: list[tuple[str, Image.Image]] = []
    done = {"picture": 0, "title": 0, "skip": 0, "already": 0}
    long_titles: list[str] = []
    for row in read_plan(plan):
        folder = root / row["Post"]
        index = folder / "index.md"
        if not index.is_file():
            print(f"x  {row['Post']}: there is no such post. The row is passed over.")
            continue
        fields = front_matter(index)
        if made_here(fields):
            done["already"] += 1
            continue
        if row["Do"] == "skip":
            done["skip"] += 1
            continue
        title = fields.get("title", "")
        if not title:
            print(f"x  {row['Post']}: no title to put on a cover. The row is passed over.")
            continue
        source = None
        if row["Do"] == "picture":
            source = folder / (row.get("Picture") or "")
            if not row.get("Picture") or not source.is_file():
                print(f"x  {row['Post']}: its picture, {row.get('Picture')!r}, is not there. The row is passed over.")
                continue
        if not set_title(title)[-1]:
            long_titles.append(row["Post"])
        focus = ",".join((row.get("Focus") or "0.5 0.5").replace(",", " ").split())
        done[row["Do"]] += 1

        if arguments.dry_run:
            # Made the same way, and kept here and not in the folder of the post.
            art = square(source, focus) if source else None
            shown.append((f"{row['Do']}: {row['Post']}", render(style, title, art)))
            continue
        kept = folder / "images" / ART_NAME
        if source:
            save(square(source, focus), kept)
        elif kept.is_file():
            fail(f"{kept} is there, and the plan says title for {row['Post']}: remove the file, or say picture.")
        art = Image.open(kept) if kept.is_file() else None
        save(render(style, title, art), folder / "images" / COVER_NAME, mark_of(style, title, kept))
        point_to_cover(index)

    would = "would get" if arguments.dry_run else "got"
    print(f"{done['picture'] + done['title']} posts {would} a cover in the house style: {done['picture']} with the "
          f"picture they had, {done['title']} with the title alone.")
    print(f"  Skipped by the plan: {done['skip']}. In the house style already: {done['already']}.")
    for name in long_titles:
        print(f"  The title of {name} is too long to fit, even at the smallest size. Look at its cover.")
    if arguments.dry_run and shown:
        draw_sheet(style, shown, Path(arguments.sheet))
        print("No post was changed. That file shows the covers as they would be.")
    elif not arguments.dry_run:
        print("The pictures the posts had are still in their folders. A post points to images/cover.jpg now.")


def command_prompt(arguments: argparse.Namespace) -> None:
    style = load_style(arguments.theme)
    subject = arguments.subject.strip().rstrip(".")
    shape = ("Wide, 16:9. The subject in the middle" if arguments.wide else "Square, 1:1. The subject in the middle")
    print("\n".join((
        "An illustration for a technical blog with a dark look, like deep space.",
        f"Subject: {subject}.",
        "Style: clean line art that glows, as if drawn with thin lines of light. One line weight, rounded corners,",
        "simple flat shapes with at most a faint fill, a soft glow around the lines. No texture, no 3D render,",
        "no photograph, no realistic shading.",
        f"Colours: the background is one flat near-black, {style['background']}, from edge to edge, with nothing in it.",
        f"The lines are cyan, {style['primary']}. Blue, {style['accent'][1]}, for depth and for fills.",
        f"At most one small accent in magenta, {style['neon'][0]}. White only for a small highlight. No other colours.",
        f"Composition: {shape}, with empty space on every side.",
        "Never: text, letters, numbers, logos, the interface or the wallpaper of a real product, people, hands,",
        "faces, a watermark, a frame or a border.",
    )))


def command_picture(arguments: argparse.Namespace) -> None:
    style = load_style(arguments.theme)
    source = Path(arguments.source)
    if not source.is_file():
        fail(f"{source} is not there.")
    image = ImageOps.exif_transpose(Image.open(source))
    if image.mode in ("RGBA", "LA", "P"):
        # What is transparent becomes the background of the site.
        image = image.convert("RGBA")
        image = Image.alpha_composite(Image.new("RGBA", image.size, style["background"]), image)
    image = image.convert("RGB")
    if image.width > WIDTH:
        image = image.resize((WIDTH, round(image.height * WIDTH / image.width)), Image.Resampling.LANCZOS)
    save(image, Path(arguments.output))


def command_check(arguments: argparse.Namespace) -> None:
    style = load_style(arguments.theme, keep=False)
    wrong = 0
    elsewhere = 0
    for file, fields in posts(arguments.folders):
        name = f"{file.parent.parent.name}/{file.parent.name}"
        picture = fields.get("feature_image", "")
        if not picture or re.match(r"^https?://", picture):
            # No cover, or one that is on the site already, as the pages of the books have: there is no file here.
            elsewhere += 1
            continue
        problems: list[str] = []
        path = file.parent / picture
        if not path.is_file():
            problems.append(f"{picture} is not there")
        else:
            with Image.open(path) as image:
                width, height = image.size
            if abs(width * HEIGHT - height * WIDTH) > 0.01 * width * HEIGHT:
                problems.append(f"{width}x{height} is not 16:9")
            elif width < WIDTH:
                problems.append(f"{width}x{height} is smaller than {WIDTH}x{HEIGHT}")
            if kilobytes(path) > BUDGET_KB:
                problems.append(f"{kilobytes(path)} KB is more than {BUDGET_KB} KB")
            if made_here(fields) and not is_current(style, file, fields):
                problems.append("the cover is not what the post says now: ./cover.ps1 -Refresh makes it again")
        if not fields.get("feature_image_alt", "").strip():
            problems.append("feature_image_alt is empty")
        if problems:
            wrong += 1
            print(f"x  {name}: " + "; ".join(problems))
        else:
            print(f"ok {name}")
    if elsewhere:
        print(f"-  {elsewhere} without a cover, or with one that is an address: not looked at")
    if wrong:
        raise SystemExit(1)


def draw_sheet(style: dict, pictures: list[tuple[str, Image.Image | Path]], output: Path) -> None:
    """Pictures next to each other with their names, each cut the way a card of the site cuts a picture."""
    columns, cell, gap, text = 3, (480, 270), 24, 30
    rows = -(-len(pictures) // columns)
    size = (gap + columns * (cell[0] + gap), gap + rows * (cell[1] + text + gap))
    sheet = Image.new("RGB", size, style["background"])
    draw = ImageDraw.Draw(sheet)
    face = font("SemiBold", 15)
    for index, (name, picture) in enumerate(pictures):
        x = gap + (index % columns) * (cell[0] + gap)
        y = gap + (index // columns) * (cell[1] + text + gap)
        if isinstance(picture, Path):
            with Image.open(picture) as opened:
                picture = opened.convert("RGB")
        # Filled, from the middle.
        sheet.paste(ImageOps.fit(picture.convert("RGB"), cell, Image.Resampling.LANCZOS), (x, y))
        draw.text((x, y + cell[1] + 8), name[:56], font=face, fill=style["text_secondary"])
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, "JPEG", quality=85, optimize=True)
    print(f"{output}: {len(pictures)} covers")


def command_sheet(arguments: argparse.Namespace) -> None:
    style = load_style(arguments.theme)
    pictures: list[tuple[str, Image.Image | Path]] = []
    for file, fields in posts(arguments.posts):
        picture = fields.get("feature_image", "")
        if picture and not re.match(r"^https?://", picture) and (file.parent / picture).is_file():
            pictures.append((file.parent.name, file.parent / picture))
    if not pictures:
        fail("There is no cover to show: no post has a picture of its own.")
    draw_sheet(style, pictures[: arguments.limit], Path(arguments.output))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--theme", help="the folder of the theme, to read the style from")
    commands = parser.add_subparsers(dest="command", required=True)

    cover = commands.add_parser("cover")
    cover.add_argument("post")
    cover.add_argument("--image")
    cover.add_argument("--focus", default="0.5,0.5")
    cover.set_defaults(run=command_cover)

    refresh = commands.add_parser("refresh")
    refresh.add_argument("folders", nargs="+")
    refresh.add_argument("--all", action="store_true")
    refresh.add_argument("--dry-run", action="store_true")
    refresh.set_defaults(run=command_refresh)

    adopt = commands.add_parser("adopt")
    adopt.add_argument("folders", nargs=1)
    adopt.add_argument("--plan", required=True)
    adopt.add_argument("--sheet", required=True)
    adopt.add_argument("--dry-run", action="store_true")
    adopt.set_defaults(run=command_adopt)

    prompt = commands.add_parser("prompt")
    prompt.add_argument("subject")
    prompt.add_argument("--wide", action="store_true")
    prompt.set_defaults(run=command_prompt)

    picture = commands.add_parser("picture")
    picture.add_argument("source")
    picture.add_argument("output")
    picture.set_defaults(run=command_picture)

    check = commands.add_parser("check")
    check.add_argument("folders", nargs="+")
    check.set_defaults(run=command_check)

    sheet = commands.add_parser("sheet")
    sheet.add_argument("output")
    sheet.add_argument("--posts", action="append", required=True)
    sheet.add_argument("--limit", type=int, default=300)
    sheet.set_defaults(run=command_sheet)

    arguments = parser.parse_args()
    arguments.run(arguments)


if __name__ == "__main__":
    main()
