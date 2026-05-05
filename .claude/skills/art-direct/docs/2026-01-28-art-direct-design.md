# Art Direct Skill Design

## Overview

A skill for art directing visuals in PowerPoint and HTML presentations. Transforms concepts into compelling imagery by teaching a structured visual thinking process, then sources actual images across stock libraries and generates AI prompts.

**Core philosophy:** Great visual selection is about *thinking differently*, not searching harder.

## Problem Statement

- Translating abstract concepts into effective image searches is hard
- Stock photography clichés are invisible to viewers (seen thousands of times)
- Maintaining visual consistency across a deck requires intentional planning
- The process is slow and often produces generic results

## The Art Direction Hierarchy

```
┌─────────────────────────────────────────┐
│  1. DECK ANALYSIS                       │
│     Read full content/outline           │
│     Understand themes, audience, tone   │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  2. CONCEPT DIRECTION                   │
│     Either:                             │
│     • Match to house style template     │
│     • Suggest direction based on content│
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  3. VISUAL STYLE GUIDE                  │
│     Photography style, color treatment, │
│     composition rules, what to avoid    │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  4. SLIDE-BY-SLIDE EXECUTION            │
│     Specific images guided by the above │
└─────────────────────────────────────────┘
```

## Five-Lens Framework

For each slide, generate options through five distinct lenses:

| Lens | Purpose | Example: "Supply chain resilience" |
|------|---------|-----------------------------------|
| **Literal** | The thing itself, cinematically shot | Cargo ship cutting through rough seas |
| **Human** | People experiencing/doing it | Dockworker's hands checking manifest in rain |
| **Environmental** | Setting, atmosphere, texture | Fog lifting off container yard at dawn |
| **Metaphorical** | Concrete visual analogy | Chain with one link glowing, spider web with dew |
| **Oblique** | Abstract, unexpected angle | Dominos frozen mid-fall |

**When to use each:**
- **Literal** — Content is already specific ("Our new Rotterdam facility")
- **Human** — Need emotional connection, trust, relatability
- **Environmental** — Setting mood, breathing room, transitions
- **Metaphorical** — Explaining concepts, making abstract tangible
- **Oblique** — Grabbing attention, provoking thought, standing out

## Stage 1 & 2: Deck Analysis + Concept Direction

**Input:** Deck content (markdown, outline, or existing PPTX) + optional house style template

**Stage 1: Deck Analysis extracts:**
- Core themes (2-3 big ideas)
- Narrative arc
- Audience
- Tone
- Key moments (which slides carry most weight)

**Stage 2: Concept Direction**

If house style provided:
- Validate content fits the style
- Note tensions and how to bridge them
- Output adapted style guide

If no house style:
- Propose 2-3 visual directions based on content analysis
- Each includes: name, mood, photography style, reference touchstones, what to avoid
- User picks one, skill locks as working style guide

## Stage 3: Visual Style Guide Format

```
VISUAL STYLE GUIDE: [Deck Name]
Direction: [Chosen direction name]

PHOTOGRAPHY STYLE
─────────────────
Type: Documentary / Editorial / Conceptual / Abstract
Subjects: [What to feature - people, environments, objects, textures]
Composition: [Rule of thirds, off-center, close crop, wide establishing]
Lighting: [Natural, dramatic, soft, high-contrast]
Color treatment: [Saturated, muted, warm shift, cool shift, monochromatic]

MOOD & TONE
───────────
Primary emotion: [e.g., quiet confidence]
Supporting emotions: [e.g., warmth, clarity]
Energy level: [Calm / Dynamic / Tense / Contemplative]

CONSISTENCY RULES
─────────────────
• All images share [specific quality - e.g., natural lighting]
• Human subjects: [candid only / eye contact OK / hands focus]
• Color palette anchors: [2-3 hex codes that images should harmonize with]
• Aspect ratio: [16:9 / 4:3 / mixed with rules]

CLICHÉ BLACKLIST
────────────────
• [Specific images to avoid for this deck's themes]
• [Generic stock tropes to reject]
• [Overused metaphors]

REFERENCE IMAGES
────────────────
[Links or descriptions of 3-5 images that nail the style]
```

## Stage 4: Slide-by-Slide Execution

**Process:**
1. Interpret the slide's job
2. Apply style guide filters
3. Generate options using five-lens framework
4. Output actionable sourcing (search terms + AI prompts)
5. Fetch examples from all sources
6. Display in HTML preview

**Output format:**

```
SLIDE: "Our market is shifting faster than ever"

STYLE GUIDE CHECK: Documentary Intimacy — candid, warm, natural light

VISUAL OPTIONS
──────────────

OPTION 1: Literal
Concept: Trading floor during market hours, screens, movement
Search terms: "trading floor action", "stock exchange screens traders"

OPTION 2: Human
Concept: Trader's hands hovering over keyboard, split-second decision
Search terms: "stock trader hands keyboard tension"

OPTION 3: Environmental
Concept: Empty trading floor at dawn, screens glowing
Search terms: "empty trading floor dawn", "financial office early morning"

OPTION 4: Metaphorical
Concept: Chess pieces mid-game, hand moving knight
Search terms: "chess strategy hand moving piece", "chess mid-game tension"

OPTION 5: Oblique
Concept: Blurred city crowds from above — movement, anonymity
Search terms: "aerial crowd motion blur", "pedestrians overhead long exposure"

RECOMMENDATION: Option 2 — most aligned with style guide's human-focus
```

## House Style Templates

**Template structure (YAML):**

```yaml
name: "Editorial Warmth"
description: "Documentary-style photography with warm, human focus"

photography:
  style: documentary
  subjects:
    preferred: [hands at work, candid faces, real environments]
    avoid: [posed groups, empty handshakes, obvious stock]
  lighting: natural, soft, golden hour preferred
  composition: off-center subjects, negative space, shallow depth of field
  color:
    treatment: warm shift, slightly desaturated
    palette_anchors: ["#D4A574", "#8B7355", "#F5E6D3"]

mood:
  primary: quiet confidence
  energy: calm, contemplative
  emotions: [trust, authenticity, craft]

lens_preferences:
  default_order: [human, environmental, literal, metaphorical, oblique]
  weight_toward: human

cliche_blacklist:
  universal:
    - handshake silhouette
    - lightbulb moments
    - puzzle pieces connecting
    - person on mountain summit
  brand_specific:
    - blue corporate tones
    - glass building reflections

ai_prompt_suffixes:
  photography: "documentary style, natural lighting, Kodak Portra 400 --ar 16:9"
  illustration: "editorial illustration, muted palette, subtle texture"
```

**Storage locations:**
- `~/.claude/skills/art-direct/styles/` (user global)
- `.art-direction/styles/` (project local)

**Cross-skill template sourcing:**
- Can extract from frontend-design skill when instructed
- Maps design tokens (colors, typography, principles) to photography direction
- Command: `art-direct --from-frontend <project-name>`

## Image Fetching

**Sources (query all in parallel):**
- Unsplash API
- Pexels API
- Google Images (web search)

**AI generation — prompt export:**
Generates formatted prompts for manual use:
- Midjourney format
- DALL-E format
- Ideogram format

Future: `--generate` flag will call configured API directly.

## Display & Review

**Primary: HTML preview file**

Skill generates visual review page at `.art-direction/previews/slide-XX-name.html`

Features:
- Images organized by lens (Literal, Human, Environmental, Metaphorical, Oblique)
- Source attribution (Unsplash, Pexels, Google)
- Style guide match indicators
- Copy buttons for AI prompts
- Download selected images
- Navigate between slides

**Fallback:** Markdown with image URLs or save to `.art-direction/images/`

## Integration with Existing Skills

**Handoff manifest:** `.art-direction/manifest.yaml`

```yaml
deck: Q4 Strategy Presentation
style_guide: Editorial Warmth
created: 2026-01-28

slides:
  - slide: 1
    title: "Opening"
    image:
      selected: ".art-direction/images/slide-01-selected.jpg"
      source: "unsplash"
      url: "https://unsplash.com/photos/abc123"
      alt: "Morning light through office windows"

color_palette:
  extracted_from_images: ["#D4A574", "#1A3A5C", "#F5E6D3"]

suggested_brand_overrides:
  accent_color: "#D4A574"
```

**Export commands:**
- `art-direct --export pptx` → Prepares for branded-pptx-converter
- `art-direct --export keynote` → Prepares for keynote-slides-skill

## Commands

| Command | Purpose |
|---------|---------|
| `art-direct` | Full workflow from deck content |
| `art-direct --style <name>` | Apply existing house style |
| `art-direct --from-frontend <project>` | Derive style from frontend-design |
| `art-direct --slide "concept"` | Quick single-slide lookup |
| `art-direct --export pptx` | Prepare assets for branded-pptx-converter |
| `art-direct --export keynote` | Prepare assets for keynote-slides-skill |

## Anti-Cliché Principle

Stock photography trains us to reach for the obvious:
- "Innovation" → lightbulb
- "Teamwork" → hands stacked
- "Growth" → plant sprouting

These images are invisible — viewers process them as noise.

**Three-level reframing:**
1. **Literal** → What the concept looks like directly (often cliché)
2. **Metaphorical** → What the concept is *like* (better but can be tired)
3. **Emotional/Atmospheric** → What the concept *feels* like (most distinctive)

Example: "Digital transformation"
- Literal: Circuit boards, binary code (cliché)
- Metaphorical: Butterfly emerging, bridge old/new (tired)
- Emotional: Empty office at dawn with single laptop glowing (distinctive)

## Dependencies

- WebSearch tool (Google Images)
- Unsplash API (MCP tool or script)
- Pexels API (MCP tool or script)
- HTML generation for previews

## Next Steps

1. Create SKILL.md with workflow
2. Create style template examples
3. Build HTML preview generator
4. Implement image fetching scripts
5. Test with real deck content
