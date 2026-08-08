# Art Direct

A Claude Code skill for art directing visuals. Point it at any content — an essay, a deck, a document, a webpage — and get back a creative direction you can execute.

## What It Does

1. **Ingests content** — reads any format (HTML, PDF, DOCX, PPTX, markdown, URLs)
2. **Analyzes** — extracts structure, themes, narrative arc, audience, tone
3. **Proposes 2-3 visual directions** — each with mood, photography style, reference touchstones, and anti-cliche guidance
4. **Generates section-by-section visual briefs** using a Five-Lens Framework (Literal, Human, Environmental, Metaphorical, Oblique)
5. **Outputs AI generation prompts** — formatted for Midjourney, DALL-E, Gemini, Ideogram, and Flux
6. **Generates images directly** via fal.ai (Flux 2 Pro, ReCraft v3, or any supported model)
7. **Critiques existing visuals** — reviews images against content intent and recommends replacements

## Installation

Copy the skill files to your Claude Code skills directory:

```bash
# Clone the repo
git clone https://github.com/nraford7/art-direct.git

# Copy to Claude Code skills directory
cp -r art-direct ~/.claude/skills/art-direct
```

The skill will be available as `/art-direct` in Claude Code.

## Usage

```
/art-direct                          # Full workflow — ingest, propose, brief
/art-direct --style editorial-warmth # Apply a house style template
/art-direct --critique               # Review existing visuals against content
/art-direct --section "concept"      # Quick single-section visual brief
```

## Image Generation

When you select "Generate now," the skill generates images via the fal.ai API. Requires `$FAL_API_KEY` environment variable.

Supported models:
- **Flux 2 Pro** (`fal-ai/flux-pro/v1.1`) — photographic realism
- **ReCraft v3** (`fal-ai/recraft-v3`) — high-res photorealistic
- **Ideogram v2** (`fal-ai/ideogram/v2`) — text-in-image, conceptual

Typical cost: ~$0.05-0.10 per image.

## House Style Templates

Reusable visual directions stored as YAML in `styles/`. Two included:

- **Editorial Warmth** — Documentary photography, warm human focus. Think National Geographic meets Kinfolk.
- **Bold Minimalism** — High-contrast, graphic imagery. Think Apple keynote meets architectural photography.

Create your own by following the template structure in any existing style file.

## The Five-Lens Framework

For any concept, five ways to see it:

| Lens | "Digital transformation" | "Supply chain resilience" |
|------|--------------------------|--------------------------|
| **Literal** | Server room corridor, blinking LEDs | Cargo ship cutting through rough seas |
| **Human** | Developer's face lit by dual monitors at 2am | Dockworker's hands checking manifest in rain |
| **Environmental** | Empty office at dawn, single laptop glowing | Fog lifting off container yard at sunrise |
| **Metaphorical** | Old film projector casting light on blank wall | Spider web holding dew drops |
| **Oblique** | Child's hand drawing a robot | Dominos frozen mid-fall, one glowing |

The oblique lens is the hardest and the most valuable.

## Anti-Cliche Guide

The skill actively rejects visual cliches:
- Handshakes, lightbulbs, puzzle pieces, mountain summits
- Hands holding globe, diverse team at whiteboard
- Plant sprouting = growth, rocket = speed, chess = strategy

Instead, it asks: what does this concept *feel* like? Specificity kills cliche.

## Requirements

- [Claude Code](https://claude.ai/claude-code)
- `$FAL_API_KEY` for image generation (optional — skill works without it, exporting prompts for manual use)

## License

MIT
