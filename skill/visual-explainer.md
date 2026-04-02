---
name: visual-explainer
description: Generate visual explanations (whiteboard, infographic, presentation, diagram, mindmap) from any content using OpenAI or Gemini image generation. Use when the user wants to visualize, explain visually, create an infographic, draw a mind map, or make a whiteboard sketch of a topic.
argument-hint: "[--style whiteboard|infographic|presentation|diagram|mindmap|mindmap-structured] [--draw-level sketch|normal|polished] [--complexity simple|moderate|detailed] <content>"
allowed-tools: Bash, Read, Write, Glob, Grep
---

Generate a visual explanation (whiteboard, infographic, presentation, diagram, or mindmap) from content using the generate-images skill.

## Usage

- `/visual-explainer Explain how DNS resolution works` — whiteboard style (default)
- `/visual-explainer --style infographic How machine learning models are trained`
- `/visual-explainer --style presentation The software development lifecycle`
- `/visual-explainer --style diagram --complexity detailed Kubernetes pod networking`
- `/visual-explainer --style mindmap The principles of object-oriented programming` — colorful radial mindmap
- `/visual-explainer --style mindmap-structured Project management methodologies` — clean, data-oriented XMind-style
- `/visual-explainer --draw-level sketch How the internet works` — rougher hand-drawn feel
- `/visual-explainer --draw-level polished --style whiteboard React component lifecycle`
- `/visual-explainer --style infographic --from mermaid` — convert a Mermaid diagram into a polished infographic
- `/visual-explainer --style whiteboard --from mermaid-file docs/architecture.mmd` — read a .mmd file and convert it
- `/visual-explainer --backend gemini How the water cycle works` — use Gemini/Nano Banana 2 instead of OpenAI

## Arguments

The argument string is available as `$ARGUMENTS`. Parse it according to these rules:

### Flags (all optional)

| Flag | Default | Description |
|------|---------|-------------|
| `--style S` | `whiteboard` | Visual style: `whiteboard`, `infographic`, `presentation`, `diagram`, `mindmap`, `mindmap-structured` |
| `--draw-level L` | `normal` | How hand-drawn vs polished: `sketch` (rough/playful), `normal` (balanced), `polished` (clean/professional) |
| `--complexity C` | `moderate` | Content density: `simple` (3-4 concepts), `moderate` (5-7 concepts), `detailed` (8-12 concepts) |
| `--size WxH` | style-dependent | Image dimensions (passed to generate-images). Defaults: whiteboard=`1536x1024`, infographic=`1024x1536`, presentation=`1536x1024`, diagram=`1024x1024`, mindmap=`1536x1024`, mindmap-structured=`1536x1024` |
| `--output DIR` | `./` | Output directory |
| `--prefix NAME` | `visual-explainer` | Filename prefix |
| `--mode M` | `single` | `single` (one image) or `multi-frame` (series of images building up the concept) |
| `--from F` | (none) | Input source: `mermaid` (inline Mermaid in content or clipboard), `mermaid-file PATH` (read from a .mmd/.md file) |
| `--backend B` | auto-detected | Image generation backend: `openai` (gpt-image-1.5) or `gemini` (Nano Banana 2). Auto-detects based on available API keys if not specified. |

### Everything else is the content

After extracting flags, join the remaining text as the content to visualize.

## Steps

### Step 1: Validate prerequisites and detect backend

- If no content is provided, ask the user what they want to visualize and stop
- Check that `jq` is available

**Backend detection** (in priority order):

1. If `--backend openai` is specified, use OpenAI. Require `OPENAI_API_KEY`.
2. If `--backend gemini` is specified, use Gemini. Require `GEMINI_API_KEY`.
3. If `--backend` is NOT specified, auto-detect:
   - If only `OPENAI_API_KEY` is set, use OpenAI
   - If only `GEMINI_API_KEY` is set, use Gemini
   - If BOTH are set, use OpenAI (default)
   - If NEITHER is set, stop with setup instructions for both:
     ```
     No image generation API key found. Set one of:
       export OPENAI_API_KEY="sk-..."    # from platform.openai.com
       export GEMINI_API_KEY="AIza..."   # from aistudio.google.com/apikey
     ```

**Report the selected backend** immediately after detection:
```
Backend: OpenAI gpt-image-1.5 (auto-detected — OPENAI_API_KEY is set)
```
or
```
Backend: Gemini Nano Banana 2 (auto-detected — only GEMINI_API_KEY is set)
```
or if explicitly set:
```
Backend: Gemini Nano Banana 2 (--backend gemini)
```

### Step 1b: Detect and parse Mermaid input

If `--from mermaid` or `--from mermaid-file PATH` is specified, OR if the content contains Mermaid syntax (lines starting with `graph`, `flowchart`, `sequenceDiagram`, `classDiagram`, `stateDiagram`, `erDiagram`, `gantt`, `pie`, `mindmap`, `timeline`, or fenced in a ` ```mermaid ` block), treat the input as a Mermaid diagram and parse it.

**How to parse Mermaid input:**

If `--from mermaid-file PATH` is specified, read the file at PATH first using the Read tool.

If `--from mermaid` is specified without a file path, the content itself IS the Mermaid code (it may also appear inline in the content argument, or the user may have pasted it in a previous message — check the conversation context).

Parse the Mermaid syntax to extract the following structured data:

1. **Diagram Type**: What kind of Mermaid diagram is it? Map to the best visual style:

   | Mermaid Type | Suggested Style (if user didn't specify) |
   |---|---|
   | `flowchart` / `graph` | diagram or whiteboard |
   | `sequenceDiagram` | diagram or whiteboard |
   | `classDiagram` | diagram |
   | `stateDiagram` | diagram or whiteboard |
   | `erDiagram` | diagram |
   | `gantt` | infographic |
   | `pie` | infographic or presentation |
   | `mindmap` | mindmap or mindmap-structured |
   | `timeline` | infographic or whiteboard |

   If the user explicitly specified a `--style`, always use their choice — ANY Mermaid diagram type can be rendered in ANY visual style. The table above is only for auto-selection when no style is given.

2. **Nodes/Entities**: Extract every node with its:
   - ID (internal reference)
   - Display label (the human-readable text)
   - Shape hint (if the Mermaid syntax specifies one — e.g., `[rect]`, `(round)`, `{diamond}`, `[(cylinder)]`, `((circle))`)

3. **Connections/Edges**: Extract every connection with:
   - Source node → Target node
   - Arrow style (solid `-->`, dotted `-..->`, thick `==>`, bidirectional `<-->`)
   - Edge label (text on the arrow, if any)

4. **Subgraphs/Groups**: Extract any `subgraph` blocks as logical groupings with their title and contained nodes.

5. **Participants/Actors** (sequence diagrams): Extract participant names, aliases, and message flow.

6. **Attributes/Fields** (class/ER diagrams): Extract class names, methods, fields, relationships, cardinality.

7. **Timeline/Gantt data**: Extract dates, milestones, sections, task names, durations.

8. **Title**: If a `title` directive exists, use it. Otherwise, infer a title from the diagram content.

**CRITICAL**: Mermaid input gives you EXACT structure — use it. Every node becomes a labeled visual element. Every edge becomes an arrow or connection. Every subgraph becomes a visual grouping/container. This is MORE precise than free-text input, so the resulting prompts should be MORE detailed, not less.

After parsing, proceed to Step 2 using the extracted structure as the input for analysis. The Mermaid data pre-fills much of the analysis:
- Nodes → Sub-Topics
- Edges → Relationships (with exact labels)
- Subgraphs → Layout groupings
- You still need to add: Visual Metaphors, Color Coding, and style-specific decorative elements

### Step 2: Analyze the content

Before generating any image, you MUST deeply analyze the input content to extract structure. This is the most critical step — the quality of the visual depends entirely on this analysis.

Perform the following analysis and write it out explicitly:

1. **Core Concept**: What is the single main idea?
2. **Key Sub-Topics**: List 3-12 sub-topics depending on complexity setting
3. **Relationships**: How do sub-topics connect? (hierarchy, sequence, cause-effect, comparison, part-whole)
4. **Visual Metaphors**: What real-world objects or metaphors could represent each concept? (e.g., "security" → shield, "data flow" → pipeline/river, "scaling" → mountains/ladder)
5. **Layout Strategy**: How should sections be arranged spatially? (radial from center, left-to-right flow, top-to-bottom hierarchy, grid, timeline)
6. **Color Coding**: Assign a color theme to each major section for visual grouping

### Step 3: Construct the image generation prompt

Build an extremely detailed prompt following the style-specific templates below. The prompt MUST be comprehensive — typically 400-800 words. Vague prompts produce generic results. Every visual element must be explicitly described.

**CRITICAL PROMPT ENGINEERING RULES:**
- Describe the EXACT layout with spatial positions (top-left, center, bottom-right, etc.)
- Specify EVERY icon, illustration, and decorative element
- Include exact text/labels that should appear in the image
- Describe colors using specific names (not just "colorful")
- Specify typography style (bold headers, handwritten labels, etc.)
- Describe connections between elements (arrows, dotted lines, flowing curves)
- Include background details and textures
- Specify the overall composition and visual flow (where the eye should travel)

---

## Style Templates

### WHITEBOARD Style

Use this template structure to build the prompt. Replace bracketed sections with content-specific details.

```
Create a stunning hand-drawn whiteboard visual explanation. The image should look like an expert educator spent hours crafting an engaging whiteboard illustration — vibrant, energetic, and visually rich.

CANVAS: A large whiteboard with [slight off-white texture / clean white surface based on draw-level]. [If sketch: visible whiteboard frame edges, slight marker smudges, eraser marks. If polished: pristine surface with subtle shadow at edges.]

TITLE: "[Title text]" written in large, bold [hand-lettered / marker-style] text across the top [center/left]. Use [color] for the title with [decorative underline / banner / box around it]. [If sketch: slightly uneven lettering with personality. If polished: confident, clean hand-lettering.]

LAYOUT: [Describe the spatial arrangement — e.g., "Radial layout with the central concept in the middle and 5 sub-topics arranged around it like spokes of a wheel" or "Left-to-right flow with 4 stages connected by large curved arrows"]

SECTIONS:
[For each sub-topic, describe:]
- "[Section Title]" in [color] bold marker text [position]
- [Icon/illustration description — be VERY specific, e.g., "a hand-drawn brain with visible folds and small lightning bolts coming from it" not just "a brain icon"]
- Key points written in smaller [handwriting/print] text: "[exact text]"
- [Border style: colored rounded rectangle, cloud bubble, banner, torn paper effect, etc.]
- [Any annotations: stars, exclamation marks, arrows pointing to important parts]

CONNECTIONS:
[Describe every arrow, line, and visual connection between sections]
- [e.g., "A thick curved arrow in blue flows from Section 1 to Section 2 with the word 'triggers' written along it"]
- [e.g., "Dotted red lines connect the three related concepts with small heart icons at the endpoints"]

DECORATIVE ELEMENTS:
[Scatter appropriate decorations throughout — these bring the whiteboard to life]
- Small doodles: [stars, lightbulbs, question marks, exclamation points, checkmarks, sparkles, small rockets, gears, clouds]
- Color splashes: [small colored dots, underline accents, highlighted keywords]
- Margin notes: [small speech bubbles with "Wow!", "Key!", "Remember this!", "Important!", etc.]
- [If sketch: more scattered doodles, playful elements, slight imperfections that feel human]
- [If polished: fewer but more carefully placed decorations, consistent spacing]

COLORS: Use a vibrant palette — [specify 4-6 exact colors, e.g., "cherry red, ocean blue, emerald green, sunshine yellow, deep purple, and tangerine orange for markers on the white background"]. Each section should have its own dominant color.

TYPOGRAPHY: All text should appear [hand-written with markers / carefully hand-lettered]. Headers in thick marker strokes (like Expo dry-erase markers). Body text in thinner pen-style writing. [If sketch: casual, slightly messy handwriting. If normal: confident educator handwriting. If polished: beautiful hand-lettering with consistent sizing.]

OVERALL FEEL: Energetic, educational, like walking into a classroom where the best teacher just finished an amazing visual lecture. The board should feel FULL but not cluttered — every element has purpose and the eye naturally flows through the content.
```

### INFOGRAPHIC Style

```
Create a professional, publication-quality infographic. This should look like it was designed by a professional graphic designer for a premium educational publication — clean, structured, and visually sophisticated.

CANVAS: [Portrait/landscape] format with a [color] background. [If polished: subtle gradient or textured background. If sketch: slightly more organic/craft feel with paper texture.]

HEADER: "[Title]" in large, bold [sans-serif / modern] typography at the top. [Subtitle if applicable] in lighter weight below. Use [color scheme] for the header area with [a decorative banner, geometric shape, or colored background block].

COLOR PALETTE: Use a sophisticated, cohesive palette — [specify exact scheme, e.g., "slate blue (#4A6FA5), warm taupe (#B8A898), olive green (#6B7F3B), charcoal (#3D3D3D), and cream (#F5F0E8) — inspired by modern editorial design"]. Use color consistently to group related concepts.

LAYOUT: [Describe the grid/flow structure — e.g., "Two-column layout with numbered sections flowing top-to-bottom. Left column covers theory, right column covers application. A central dividing line with decorative elements separates them."]

NUMBERED SECTIONS:
[For each section, describe:]
- Section number in a [colored circle / hexagon / badge] with [icon inside or beside it]
- "[Section Title]" in bold [font style], [color]
- [Icon/illustration: use flat-design style icons, e.g., "a flat-design gear icon in slate blue with a small dollar sign overlay" — NOT hand-drawn]
- Content organized as: [bullet points / comparison table / flow arrows / stat callouts]
- [Specific data visualizations if applicable: bar charts, pie charts, simple graphs]
- [Visual container: rounded rectangle card with subtle shadow, colored sidebar, etc.]

ICONS AND ILLUSTRATIONS:
[Describe the visual style for all icons]
- Style: [flat design / line art / isometric / duotone] — consistent throughout
- [List specific icons for each concept with exact descriptions]
- Each icon should be [size] and use [color approach — monochrome with accent, full color, etc.]

FLOW AND CONNECTIONS:
- [Describe how sections connect visually — numbered progression, timeline, flowchart arrows]
- [Use consistent connector styles — thin lines, dotted paths, thick arrows with labels]

DATA CALLOUTS:
- [Any statistics, key numbers, or highlight boxes]
- [e.g., "A large '6' in a teal circle with 'Key Determinants' written below in small caps"]

FOOTER: [Attribution, source notes, or summary bar at the bottom]

TYPOGRAPHY:
- Headers: [Bold sans-serif, e.g., Montserrat or Roboto style]
- Body: [Clean sans-serif, good readability]
- Callouts: [Slightly larger, maybe italicized or in accent color]
- All text must be crisp and legible — this is a polished publication piece

OVERALL FEEL: Clean, authoritative, and visually balanced. Like a premium educational poster you'd see in a university or a well-designed report. Information hierarchy is immediately clear — the viewer knows exactly where to start and how to navigate the content. White space is used intentionally. Nothing feels cramped or cluttered.
```

### PRESENTATION Style

```
Create a single, visually striking presentation slide that explains [topic]. This should look like a keynote slide from a world-class conference talk — bold, minimal, and impactful.

CANVAS: Widescreen (16:9) format. [Dark background with light text / Light background with dark text / Gradient background]. [Specify exact colors.]

TITLE: "[Title]" in [large/extra-large] bold [modern sans-serif] text. Positioned [top-left / center-top]. [Color and styling details.]

VISUAL HIERARCHY: The slide should have ONE dominant visual element that immediately captures attention, supported by [2-4] secondary elements.

PRIMARY VISUAL:
[Describe the main illustration, diagram, or graphic — e.g., "A large circular diagram in the center showing the 4 stages of the process, with each quadrant in a different color and connected by curved arrows"]

SUPPORTING ELEMENTS:
[For each supporting element:]
- [Position on slide]
- [Visual description]
- [Text labels]

KEY POINTS:
[2-5 key takeaways displayed as clean bullet points or visual callouts]
- [Exact text and position for each]

DESIGN DETAILS:
- [Subtle grid lines, geometric decorations, or accent shapes in background]
- [Icon style and placement]
- [Color accent usage]

TYPOGRAPHY: [Conference-quality — bold headers, clean body text, consistent sizing. Specify font style.]

OVERALL FEEL: TED-talk quality. Bold, confident, focused. Every element earns its place. High contrast and strong visual hierarchy. The key message is understood within 3 seconds of looking at it.
```

### MINDMAP Style

```
Create a vibrant, colorful mind map illustration. This should look like a beautifully hand-crafted mind map created by someone who loves visual thinking — organic, radial, bursting with color and personality.

CANVAS: [White / cream / light gray] background, landscape orientation. Clean but with subtle paper texture.

CENTER NODE: A large, eye-catching central element in the exact center of the image:
- Shape: [rounded rectangle / circle / cloud / organic blob] with a bold fill color (e.g., rich coral, deep teal, or vibrant purple)
- Text: "[Central Topic]" in large, bold white or dark text inside the shape
- [Optional: a small icon or illustration inside or beside the central node that represents the topic — e.g., a brain, a gear, a lightbulb]
- The center should feel like the "sun" of the map — everything radiates outward from it

MAIN BRANCHES: [4-8 depending on complexity] thick, organic, curved branches radiating outward from the center node like tree limbs. Each branch should:
- Be a DIFFERENT bold color (e.g., branch 1: cherry red, branch 2: ocean blue, branch 3: emerald green, branch 4: golden amber, branch 5: deep purple, branch 6: tangerine orange)
- Curve gracefully outward — NOT straight lines. Use smooth, flowing, slightly wavy curves
- Taper from thick (near center) to thinner as they extend outward
- End at a rounded rectangle or pill-shaped node containing the sub-topic title

BRANCH NODES (Level 1): At the end of each main branch:
- A rounded rectangle or pill shape filled with the SAME color as its branch (but slightly lighter tint)
- "[Sub-Topic Title]" in bold text inside
- [Small relevant icon next to or inside the node — be specific about each icon]

SUB-BRANCHES (Level 2): From each Level 1 node, extend 2-4 thinner branches outward:
- Same color family as the parent branch but thinner lines
- End at smaller nodes or simple text labels
- Text: "[detail point]" — keep these short (2-5 words each)
- [Optional: tiny icons, checkmarks, or bullet dots at each endpoint]

SUB-BRANCHES (Level 3, if complexity is detailed): From some Level 2 nodes, extend even thinner branches:
- Finest lines, same color family
- Simple text labels, no boxes needed
- These are leaf-level details

DECORATIVE ELEMENTS:
- Small icons scattered near relevant branches: [specify icons per topic — gears, stars, arrows, hearts, lightbulbs, clouds, locks, etc.]
- Colorful dots or circles at branch connection points
- Subtle shadow or glow behind the central node
- [Optional: small doodles, emoji-style icons, or illustrative elements that make it feel alive]
- Curved connector lines (dotted, in gray) between related branches that aren't directly connected — with small labels explaining the cross-connection

COLORS: Use a vibrant, saturated palette — each main branch has its own distinct color. Colors should be bold and joyful: [specify 4-8 colors]. The overall impression should be a rainbow of organized knowledge.

TYPOGRAPHY:
- Central node: Large, bold [sans-serif or hand-lettered]
- Level 1 nodes: Medium bold text
- Level 2: Smaller regular text
- Level 3: Smallest text, still legible
- All text should be horizontal and easy to read (not rotated along branches)

OVERALL FEEL: Organic, radiant, visually stunning. Like a beautifully crafted mind map from a skilled visual thinker's notebook. The eye is drawn to the center and naturally follows branches outward. Balanced composition — branches fill the space evenly without crowding. Feels creative, energetic, and intellectually stimulating.
```

### MINDMAP-STRUCTURED Style

```
Create a clean, professional, data-oriented mind map in the style of XMind or MindMeister. This should look like a structured knowledge map from a business intelligence tool — organized, precise, and information-dense with minimal decorative elements.

CANVAS: Clean white or very light gray (#F8F9FA) background, landscape orientation. No texture — pure and minimal.

CENTER NODE: A prominent but understated central element in the center:
- Shape: Rounded rectangle with subtle shadow or thin border
- Fill: Muted professional color (e.g., dark slate blue #2C3E50, charcoal #34495E, or dark teal #1A5276)
- Text: "[Central Topic]" in clean, white, bold sans-serif text
- Subtle drop shadow or thin 1px border — no glow, no decoration
- [Optional: a small monochrome icon to the left of the text]

MAIN BRANCHES: [4-8 depending on complexity] — these are clean, straight or gently curved lines:
- Use a MUTED, PROFESSIONAL color palette — not vibrant. Colors like: steel blue (#5B7B9A), sage green (#6B8E6B), warm gray (#8E8E7A), muted coral (#C27B6B), slate purple (#7B6B8E), dusty teal (#5B8E8E)
- Lines should be clean and consistent width (2-3px) — NOT organic or hand-drawn
- Lines connect from center node edge to Level 1 nodes with clean right-angle or gentle curve routing
- Use a structured layout: top branches go up-right and up-left, bottom branches go down-right and down-left — creating a balanced tree structure

BRANCH NODES (Level 1): Connected to the center:
- Rounded rectangles with thin colored border matching the branch color, white or very light fill
- "[Sub-Topic Title]" in dark text, bold, clean sans-serif
- Consistent sizing across all Level 1 nodes
- [Optional: small monochrome or duotone icon (line-art style) to the left of text]

SUB-BRANCHES (Level 2): Extend from Level 1 nodes:
- Thinner lines (1-2px), same color as parent branch
- Connected to smaller nodes or inline text blocks
- Nodes: Smaller rounded rectangles or simple bordered pills
- Text: "[detail]" in regular weight, dark gray text
- Aligned neatly — sub-branches should be vertically stacked or fanned in an organized pattern, NOT randomly scattered

SUB-BRANCHES (Level 3, if complexity is detailed):
- Finest lines (1px), lighter shade of parent color
- Simple text labels with small bullet dots or dashes
- May use a simple table or list format within a container

DATA ELEMENTS (what makes this style distinct):
- [Where applicable, include small inline data representations:]
  - Small tag/badge elements: e.g., "[HIGH]" "[LOW]" priority badges in colored pills
  - Percentage indicators: small progress-bar style elements
  - Status markers: green checkmarks, yellow circles, red X marks
  - Count badges: small numbered circles showing "3 items", "5 types", etc.
  - Category labels: small muted pills like "[Core]" "[Advanced]" "[Optional]"
- These data elements should feel like metadata attached to nodes — compact and informative

CROSS-CONNECTIONS:
- Thin dashed gray lines connecting related nodes across different branches
- Small text labels on these connections explaining the relationship
- Arrows showing direction of influence or dependency

LAYOUT RULES:
- Maintain strict visual hierarchy through size and weight, not color intensity
- Equal spacing between sibling nodes
- Branches should not overlap or cross each other
- White space is used generously — the map should breathe
- Overall structure should feel like a well-organized org chart or knowledge taxonomy

COLORS: Muted, desaturated, professional palette. Think corporate presentation, not children's art. [Specify 4-6 muted colors.] Use color primarily for branch differentiation, not decoration. Gray (#666) for all body text. Darker shade for headers.

TYPOGRAPHY:
- All text in clean sans-serif (Helvetica/Arial/Roboto style)
- Center: 18-20pt bold, white
- Level 1: 14pt bold, dark charcoal
- Level 2: 11-12pt regular, dark gray
- Level 3: 10pt regular, medium gray
- NO hand-drawn, script, or decorative fonts anywhere
- All text horizontal, left-aligned within nodes

OVERALL FEEL: Professional, structured, corporate-ready. Like a screenshot from XMind Pro or MindMeister in "business" theme. Information-dense but well-organized. Could be dropped into a board presentation or strategy document without modification. Clean lines, muted colors, clear hierarchy. The focus is on the DATA and RELATIONSHIPS, not visual flair.
```

### DIAGRAM Style

```
Create a clear, precise technical diagram explaining [topic]. This should look like a professionally created technical illustration — accurate, well-labeled, and easy to follow.

CANVAS: Clean [white / light gray] background. [Specify dimensions context.]

TITLE: "[Title]" in [position] using clean, professional [sans-serif] text in [color].

DIAGRAM TYPE: [Flowchart / Architecture diagram / Sequence diagram / Mind map / Process flow / Comparison matrix / Hierarchy tree / Network topology]

NODES/ELEMENTS:
[For each node:]
- Shape: [rectangle / rounded rectangle / circle / diamond / hexagon / cylinder / cloud]
- Color: [specific color]
- Label: "[exact text]"
- Position: [where in the diagram]
- [Any internal details or sub-elements]

CONNECTIONS:
[For each connection:]
- From [node] to [node]
- Line style: [solid / dashed / dotted / thick / thin]
- Arrow: [one-way / bidirectional / none]
- Label: "[text on the connection]"
- Color: [specific color]

LEGEND/KEY: [If applicable, describe a legend box]

ANNOTATIONS:
- [Numbered callouts, notes, or labels outside the main diagram]

GROUPING:
- [Visual containers/boundaries that group related nodes — dashed rectangles, shaded regions, swim lanes]

TYPOGRAPHY: Clean, technical, highly legible. All labels crisp. Use consistent font sizing — larger for main nodes, smaller for connection labels.

OVERALL FEEL: Engineering-quality documentation. Precise, unambiguous, and professionally typeset. Should look like it belongs in official technical documentation or an architecture review deck.
```

---

## Step 4: Handle multi-frame mode

If `--mode multi-frame` is specified:

1. Break the content into 3-5 progressive frames that build up the concept
2. Frame 1: Introduction — show the core concept and title
3. Frame 2-N-1: Progressive elaboration — add sections one at a time
4. Frame N: Complete picture with all elements and a summary
5. Generate each frame as a separate image, maintaining consistent style/layout
6. Each prompt should reference "this is frame X of Y in a series" for consistency

## Step 5: Generate the image(s)

Determine the appropriate image size based on style (unless overridden):
- `whiteboard`: `1536x1024` (landscape)
- `infographic`: `1024x1536` (portrait)
- `presentation`: `1536x1024` (landscape)
- `diagram`: `1024x1024` (square)
- `mindmap`: `1536x1024` (landscape)
- `mindmap-structured`: `1536x1024` (landscape)

**Report before generating:**
```
Generating with: <Backend Name> (<size>, high quality)
```

### If backend is OpenAI (gpt-image-1.5):

1. Call the OpenAI API:

```bash
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-1.5",
    "prompt": "<the constructed prompt>",
    "size": "<size>",
    "quality": "high",
    "output_format": "png"
  }'
```

2. Decode and save:
```bash
echo '<response>' | jq -r '.data[0].b64_json' | base64 --decode > <output_dir>/<prefix>-<n>.png
```

### If backend is Gemini (Nano Banana 2):

1. Call the Gemini API:

```bash
curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [
      {
        "parts": [
          {"text": "<the constructed prompt>"}
        ]
      }
    ],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"]
    }
  }'
```

2. Extract and save the image. The response contains image data in `candidates[0].content.parts`. Find the part where `inlineData` exists:
```bash
echo '<response>' | jq -r '.candidates[0].content.parts[] | select(.inlineData) | .inlineData.data' | base64 --decode > <output_dir>/<prefix>-<n>.png
```

3. Note: Gemini returns the image MIME type in `.inlineData.mimeType` (usually `image/png`). Use the appropriate file extension.

### Size handling differences:

- **OpenAI**: Supports exactly `1024x1024`, `1536x1024`, `1024x1536`. Pass the size directly.
- **Gemini**: Does not accept a size parameter in the same way. Include the desired dimensions in the prompt text itself (e.g., "Create a 1536x1024 landscape image..."). The model will approximate the requested dimensions.

### Quality:

- Always aim for highest quality on both backends.
- OpenAI: set `"quality": "high"`.
- Gemini: quality is controlled by the model tier and prompt detail. The detailed prompts this skill generates are already optimized for high quality output.

## Step 6: Generate structured text companion

After generating the image, also output a structured text summary in this format:

```
## Visual Explainer: [Title]

**Style:** [style] | **Backend:** [OpenAI gpt-image-1.5 or Gemini Nano Banana 2] | **Draw Level:** [draw-level] | **Complexity:** [complexity]

### Sections
1. **[Section Title]** — [brief description]
2. **[Section Title]** — [brief description]
...

### Key Relationships
- [Concept A] → [Concept B]: [relationship]
...

### Image
Generated: [filepath]
```

## Step 7: Summary

Report to the user:
- The generated image path(s)
- The style and settings used
- A brief description of what's depicted
- Suggestions for refinement (e.g., "Try `--draw-level sketch` for a more casual feel" or "Try `--style infographic` for a more structured layout")

---

## Prompt Quality Checklist

Before sending any prompt to the image generator, verify it includes ALL of these:

- [ ] Explicit canvas/background description
- [ ] Title text and styling
- [ ] Spatial layout description (where things are positioned)
- [ ] 3-12 section descriptions with titles, icons, and text
- [ ] Specific icon/illustration descriptions (not generic — describe what each looks like)
- [ ] Connection/arrow descriptions between related elements
- [ ] Color palette with specific color names
- [ ] Typography/text style description
- [ ] Decorative elements appropriate to the style
- [ ] Overall mood/feel description
- [ ] At least 300 words of prompt detail

If any item is missing, add it before generating.

## Error Handling

- If no API key is available (neither `OPENAI_API_KEY` nor `GEMINI_API_KEY`), stop with setup instructions for both
- If `--backend` is specified but the corresponding API key is missing, stop with instructions for that specific key
- If `jq` is not available, stop with install instructions
- If no content is provided, ask the user what to visualize
- If the API returns an error, report it and suggest the user try simplifying the content or switching backends
- If the content is too complex for the chosen complexity level, suggest upgrading to `detailed`

## Notes

- The prompt engineering is the primary value of this skill — spend time on analysis and prompt construction
- The same prompts work across both backends; the style templates are backend-agnostic
- Always use `quality: "high"` (OpenAI) — these are meant to be premium visuals
- For best results with text-heavy content, prefer `infographic` style
- For process/flow content, prefer `diagram` style
- For engaging/fun explanations, prefer `whiteboard` style
- For hierarchical/categorical content, prefer `mindmap` (colorful) or `mindmap-structured` (data-oriented)
- Use `mindmap` when the audience values visual appeal and creativity
- Use `mindmap-structured` when the audience values precision, data density, and professional presentation
- The `draw-level` parameter only significantly affects `whiteboard` and `presentation` styles
- Multi-frame mode costs more (one API call per frame) — warn the user about cost
- Estimated cost (OpenAI): ~$0.19 per image at high quality, 1024x1024. Larger sizes ~$0.29
- Estimated cost (Gemini): Free tier available; check current pricing at aistudio.google.com
