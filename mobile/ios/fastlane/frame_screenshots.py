#!/usr/bin/env python3
"""Composite App Store marketing frames: brand canvas + caption + screenshot.

Self-contained replacement for `frameit`. Reads the per-locale
`keyword.strings` (headline) and `title.strings` (subhead), draws the caption
in the top band, and places the raw device capture below inside a rounded
iPhone body. `09_endcard` is a typographic brand card (no capture, carries the
only wordmark in the set).

Usage: frame_screenshots.py <screenshots_dir>
Writes `<device>-<slide>_framed.png` for each slide in SLIDES.
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_PATH = os.path.join(HERE, "fonts", "BricolageGrotesque-Bold.ttf")
# Official white brand wordmark from about.divine.video/media-resources
# (Divine-Logo-White.png). The mark is the stylised "diVine" lettering — the
# real logo, not a font approximation.
WORDMARK_PATH = os.path.join(HERE, "endcard_assets", "divine-logo-white.png")
BG = (0x00, 0x15, 0x0D)
GREEN = (0x27, 0xC5, 0x8B)
WHITE = (0xFF, 0xFF, 0xFF)
BODY = (0x0B, 0x0B, 0x0D)
EDGE = (0x44, 0x46, 0x4A)

# Output canvas per device size (App Store portrait). Keyed by a substring of
# the device name; falls back to the 6.9" canvas.
CANVASES = {
    "11 Pro Max": (1242, 2688),
    "16 Pro Max": (1290, 2796),
    "iPad Pro 13": (2064, 2752),
}
DEFAULT_CANVAS = (1290, 2796)

# Ordered slide set. Each captured slide's `src` is the raw snapshot name on
# disk; the endcard has src=None and is generated. The old share sheet is
# intentionally absent — captured by the tests but excluded from the export.
SLIDES = [
    ("01_classics", "01_classics"),
    ("02_verification", "02_verification"),
    ("03_creator_post", "03_creator_post"),
    ("04_capture", "04_capture"),
    ("05_discover", "05_discover"),
    ("06_lists", "06_lists"),
    ("07_profile", "07_profile"),
    ("08_editor", "08_editor"),
    ("09_endcard", None),
]


def parse_strings(path):
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path, encoding="utf-8"):
        m = re.match(r'\s*"(.+?)"\s*=\s*"(.*)"\s*;\s*$', line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def wrap(draw, text, font, maxw):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=font) <= maxw:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def line_height(font, sample="Ag"):
    b = font.getbbox(sample)
    return b[3] - b[1]


def block_height(lines, font, gap):
    if not lines:
        return 0
    return len(lines) * line_height(font) + (len(lines) - 1) * gap


def draw_centered(draw, lines, font, y, color, canvas_w, gap):
    lh = line_height(font)
    for ln in lines:
        tw = draw.textlength(ln, font=font)
        draw.text(((canvas_w - tw) / 2, y), ln, font=font, fill=color)
        y += lh + gap
    return y


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, img.width, img.height), radius=radius, fill=255
    )
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def canvas_for(device):
    for key, size in CANVASES.items():
        if key in device:
            return size
    return DEFAULT_CANVAS


def device_body(w, h, radius):
    """A rounded black iPhone body with a subtle titanium edge highlight."""
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=BODY)
    d.rounded_rectangle(
        (2, 2, w - 3, h - 3), radius=max(1, radius - 2), outline=EDGE, width=2
    )
    return body


def draw_caption(draw, cw, ch, headline, subhead):
    """Draw captions without allowing wider iPad canvases to crowd vertically."""
    if not headline:
        return
    head_font = ImageFont.truetype(FONT_PATH, int(min(cw * 0.068, ch * 0.040)))
    head_lines = wrap(draw, headline, head_font, cw - 150)
    head_top = int(ch * 0.052)
    head_bottom = draw_centered(draw, head_lines, head_font, head_top, GREEN, cw, 6)
    if subhead:
        sub_font = ImageFont.truetype(FONT_PATH, int(min(cw * 0.033, ch * 0.022)))
        sub_lines = wrap(draw, subhead, sub_font, cw - 180)
        sub_top = max(int(ch * 0.140), head_bottom + int(ch * 0.020))
        draw_centered(draw, sub_lines, sub_font, sub_top, WHITE, cw, 4)


def build_captured(shot_path, out_path, device, headline, subhead):
    cw, ch = canvas_for(device)
    canvas = Image.new("RGB", (cw, ch), BG)
    draw = ImageDraw.Draw(canvas)
    draw_caption(draw, cw, ch, headline, subhead)

    band_h = int(ch * 0.185)
    shot_top = band_h
    avail_h = ch - shot_top - int(ch * 0.045)
    avail_w = int(cw * 0.86)

    shot = Image.open(shot_path).convert("RGB")
    bezel_frac = 0.026
    scale = min(
        avail_w / (shot.width * (1 + 2 * bezel_frac)),
        avail_h / (shot.height + 2 * shot.width * bezel_frac),
    )
    sw, sh = round(shot.width * scale), round(shot.height * scale)
    bezel = max(6, round(sw * bezel_frac))
    shot = shot.resize((sw, sh))
    screen_radius = int(sw * 0.058)
    shot = rounded(shot, radius=screen_radius)

    body = device_body(sw + 2 * bezel, sh + 2 * bezel, screen_radius + bezel)
    body.paste(shot, (bezel, bezel), shot)
    x = (cw - body.width) // 2
    canvas.paste(body, (x, shot_top), body)
    canvas.save(out_path)


def sentence_lines(draw, text, font, maxw):
    """Break an endcard headline at sentence boundaries so each sentence is
    its own balanced line (e.g. 'All human.' / 'No AI slop.')."""
    parts = re.findall(r"[^.]+\.?", text)
    lines = []
    for part in parts:
        lines.extend(wrap(draw, part.strip(), font, maxw))
    return lines


def build_endcard(out_path, device, headline, subhead):
    cw, ch = canvas_for(device)
    canvas = Image.new("RGB", (cw, ch), BG)
    draw = ImageDraw.Draw(canvas)

    head_font = ImageFont.truetype(FONT_PATH, int(cw * 0.092))
    head_lines = sentence_lines(draw, headline, head_font, cw - 200)
    sub_font = ImageFont.truetype(FONT_PATH, int(cw * 0.040))
    sub_lines = wrap(draw, subhead, sub_font, cw - 200) if subhead else []

    gap = int(ch * 0.02)
    block = block_height(head_lines, head_font, 8)
    if sub_lines:
        block += gap + block_height(sub_lines, sub_font, 6)
    y = (ch - block) // 2 - int(ch * 0.04)
    y = draw_centered(draw, head_lines, head_font, y, WHITE, cw, 8)
    if sub_lines:
        y += gap
        draw_centered(draw, sub_lines, sub_font, y, GREEN, cw, 6)

    # Official white "diVine" wordmark, bottom-centre — the only slide that
    # carries the logo.
    if os.path.exists(WORDMARK_PATH):
        mark = Image.open(WORDMARK_PATH).convert("RGBA")
        target_w = int(cw * 0.34)
        scale = target_w / mark.width
        mark = mark.resize((target_w, round(mark.height * scale)))
        mx = (cw - mark.width) // 2
        my = int(ch * 0.85)
        canvas.paste(mark, (mx, my), mark)
    canvas.save(out_path)


def main(root):
    failures = []
    if not os.path.isdir(root):
        print(f"ERROR: screenshots directory does not exist: {root}", file=sys.stderr)
        return 1

    locales = 0
    for locale in sorted(os.listdir(root)):
        ldir = os.path.join(root, locale)
        if not os.path.isdir(ldir):
            continue
        locales += 1
        keywords = parse_strings(os.path.join(ldir, "keyword.strings"))
        titles = parse_strings(os.path.join(ldir, "title.strings"))

        devices = set()
        for fn in os.listdir(ldir):
            m = re.match(r"(.+?)-\d\d_.+\.png$", fn)
            if m and "_framed" not in fn:
                devices.add(m.group(1))

        if not devices:
            failures.append(f"{locale}: no raw device captures found")
            continue

        for device in sorted(devices):
            for name, src in SLIDES:
                out = os.path.join(ldir, f"{device}-{name}_framed.png")
                headline = keywords.get(name, "")
                subhead = titles.get(name)
                if not headline:
                    failures.append(f"{locale}/{device}-{name}: missing headline")
                    continue
                if src is None:
                    build_endcard(out, device, headline, subhead)
                    print(f"framed {locale}/{device}-{name} (endcard)")
                    continue
                shot = os.path.join(ldir, f"{device}-{src}.png")
                if not os.path.exists(shot):
                    failures.append(f"{locale}/{device}-{name}: missing {src}.png")
                    continue
                build_captured(shot, out, device, headline, subhead)
                print(f"framed {locale}/{device}-{name}")

    if locales == 0:
        failures.append("no locale screenshot directories found")

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "./screenshots"))
