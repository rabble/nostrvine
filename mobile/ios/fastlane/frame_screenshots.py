#!/usr/bin/env python3
"""Composite App Store marketing frames: brand canvas + caption + screenshot.

Self-contained replacement for `frameit` (whose title layout is finicky and
whose ImageMagick dependency is heavy). Reads the same per-locale
`keyword.strings` (headline) and `title.strings` (subhead) files, draws the
caption in the top third, and places the raw device capture below with
rounded corners on the dark-green brand canvas.

Usage: frame_screenshots.py <screenshots_dir>
Writes `<name>_framed.png` next to each `<device>-<name>.png` capture.
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_PATH = os.path.join(HERE, "fonts", "BricolageGrotesque-Bold.ttf")
BG = (0x00, 0x15, 0x0D)
GREEN = (0x27, 0xC5, 0x8B)
WHITE = (0xFF, 0xFF, 0xFF)
# Output canvas per device size (App Store portrait). Keyed by a substring of
# the device name; falls back to the 6.9" canvas.
CANVASES = {
    "11 Pro Max": (1242, 2688),
    "16 Pro Max": (1290, 2796),
}
DEFAULT_CANVAS = (1290, 2796)


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
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def line_height(font, sample="Ag"):
    b = font.getbbox(sample)
    return b[3] - b[1]


def draw_centered(draw, lines, font, y, color, canvas_w, gap):
    lh = line_height(font)
    for ln in lines:
        tw = draw.textlength(ln, font=font)
        draw.text(((canvas_w - tw) / 2, y), ln, font=font, fill=color)
        y += lh + gap
    return y


def block_height(lines, font, gap):
    return len(lines) * line_height(font) + max(0, len(lines) - 1) * gap


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


def build(shot_path, out_path, device, headline, subhead):
    cw, ch = canvas_for(device)
    canvas = Image.new("RGB", (cw, ch), BG)
    draw = ImageDraw.Draw(canvas)

    # Fixed caption band so every screenshot starts at the same Y — the set
    # lines up when Apple shows them side by side. The caption is vertically
    # centered within the band, so 1- and 2-line headlines both look anchored.
    band_h = int(ch * 0.185)
    head_gap, sub_gap, between = 6, 6, int(ch * 0.012)

    if headline:
        head_font = ImageFont.truetype(FONT_PATH, int(cw * 0.072))
        head_lines = wrap(draw, headline, head_font, cw - 140)
        total = block_height(head_lines, head_font, head_gap)
        sub_lines = None
        if subhead:
            sub_font = ImageFont.truetype(FONT_PATH, int(cw * 0.034))
            sub_lines = wrap(draw, subhead, sub_font, cw - 180)
            total += between + block_height(sub_lines, sub_font, sub_gap)
        y = int(ch * 0.045) + max(0, (band_h - int(ch * 0.045) - total) // 2)
        y = draw_centered(draw, head_lines, head_font, y, GREEN, cw, head_gap)
        if sub_lines:
            y += between
            draw_centered(draw, sub_lines, sub_font, y, WHITE, cw, sub_gap)

    shot_top = band_h
    avail_h = ch - shot_top - int(ch * 0.045)
    avail_w = int(cw * 0.86)

    shot = Image.open(shot_path).convert("RGB")
    scale = min(avail_w / shot.width, avail_h / shot.height)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)))
    shot = rounded(shot, radius=int(shot.width * 0.055))
    x = (cw - shot.width) // 2
    canvas.paste(shot, (x, shot_top), shot)
    canvas.save(out_path)


def main(root):
    for locale in sorted(os.listdir(root)):
        ldir = os.path.join(root, locale)
        if not os.path.isdir(ldir):
            continue
        keywords = parse_strings(os.path.join(ldir, "keyword.strings"))
        titles = parse_strings(os.path.join(ldir, "title.strings"))
        for fn in sorted(os.listdir(ldir)):
            if not fn.endswith(".png") or fn.endswith("_framed.png"):
                continue
            m = re.match(r"(.+?)-(\d\d_.+)\.png$", fn)
            if not m:
                continue
            device, name = m.group(1), m.group(2)
            headline = keywords.get(name)
            if not headline:
                # No caption for this screen (e.g. 02 carries its own).
                headline = ""
            out = os.path.join(ldir, f"{device}-{name}_framed.png")
            build(
                os.path.join(ldir, fn), out, device, headline,
                titles.get(name),
            )
            print(f"framed {locale}/{device}-{name}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "./screenshots")
