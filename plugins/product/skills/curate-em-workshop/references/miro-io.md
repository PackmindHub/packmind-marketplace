# Miro I/O for Example Mapping frames

Reference for reading an Example Mapping frame and pushing a curated copy back. Read this once at the start of a curation session, then keep in context until Phase 5 is done.

## Reading a frame

### Step 1 — Normalise the URL

The user might paste any of:

- `https://miro.com/app/board/uXjVOakxTk0=/` (board, no frame target)
- `https://miro.com/app/board/uXjVOakxTk0=/?moveToWidget=3458764512345678901` (board scoped to a frame)
- A direct link copied from a frame's right-click menu (same shape as above)

If there is no `moveToWidget` parameter, the user has not pointed at a specific frame. Call `mcp__miro__context_explore` on the board URL — it returns all frames with their URLs and titles. Show the list and ask which one to curate.

### Step 2 — List the stickies in the frame

Use `mcp__miro__board_list_items`:

```
miro_url: <the frame-scoped URL>
item_type: "sticky_note"
limit: 1000
```

Page through results using the returned `cursor` until you have them all. Even small workshops produce 30–80 stickies, well under one page in practice, but never hardcode the assumption.

If `item_type="sticky_note"` returns zero results but the frame is visibly non-empty, the workshop may have used `shape` or `text` items instead of true sticky notes. Fall back: re-list with `item_type=null` (no filter) and inspect the types. Surface a warning to the user before curating — interpretation rules differ.

### Step 3 — Extract the fields you need

Each sticky returned by `board_list_items` exposes (field names may vary slightly across Miro API versions — adapt by inspection):

- `id` — Miro item ID. Keep it; useful if you ever need to update the original in place.
- `content` or `data.content` — the sticky text. May contain HTML tags (`<p>`, `<br>`, `<strong>`) if the user used Miro's rich-text editor. Strip tags for analysis; keep the plain text for rewriting.
- `style.fillColor` or `data.fillColor` or `style.fill` — colour. Miro returns either named values (`light_yellow`, `light_blue`, `green`, `red`) or hex codes. Map both.
- `position.x`, `position.y`, `geometry.width`, `geometry.height` — coordinates and size, used for clustering.
- `parent.id` — the frame the sticky belongs to. Useful sanity check that you're inside the right frame.

### Colour mapping

Miro's default sticky palette uses these names/hex codes (approximate — actual values may differ slightly):

| Bucket | Miro names | Approximate hex |
|---|---|---|
| Yellow (user story) | `light_yellow`, `yellow` | `#fef445`, `#f5f6a8` |
| Blue (rule) | `light_blue`, `blue`, `cyan` | `#a6ccf5`, `#67c6c0`, `#2d9bf0` |
| Green (example) | `light_green`, `green` | `#d5f692`, `#8fd14f`, `#12cdd4` |
| Red (question) | `red`, `light_pink`, `pink` | `#f5d128`, `#f24726`, `#ea94bb` |

**Treat colour matching as fuzzy.** Bucket by hue, not by exact hex. If a sticky's colour falls outside the four buckets (e.g., orange, purple, grey), surface it as unknown — the team may have used a private convention.

### Step 4 — Spatial clustering

Example Mapping conventions:

- The yellow user story sits at the top-left.
- Blue rules form a horizontal band underneath.
- Green examples cascade vertically under each blue.
- Red questions sit on the right edge.

Concretely: for each green, find the blue with the smallest distance to its top edge — typically the blue directly above it. A green's `centre_x` should be within `±width` of a blue's `centre_x`. If a green is more than ~3 sticky-widths away from any blue, treat it as orphan.

For each red, distance to the nearest blue tells you *which rule the question is about* — useful for Pass C. A red that's far from every blue is a global question (e.g., "what's the persona?").

## Writing the curated frame

### Step 1 — Refresh the DSL spec

Always call `mcp__miro__layout_get_dsl` once at the top of Phase 5. The DSL changes occasionally; reading the spec at runtime keeps the skill robust. Save the spec verbatim in your context — you'll quote from it when building the payload.

### Step 2 — Position the new frame

From the source frame (read via `mcp__miro__layout_read` on the frame URL):

- Same `y` as the source frame.
- `x = source.x + source.width + 200` (200 px gutter).
- Same `width` and `height` as the source. If the source is very small for the curated content, widen by 30%.

This keeps the original and curated versions side-by-side at the same vertical level — easy for the team to compare.

### Step 3 — Compose the DSL payload

Following the spec from `layout_get_dsl`, build a payload that creates, in this order (Miro DSL requires frames first):

1. **The new frame**, titled `{original frame title} — curated ({YYYY-MM-DD})`.
2. **The yellow user story sticky** at the top-left of the frame's interior.
3. **One blue sticky per rule**, laid out horizontally below the user story. Space them evenly: rule width 200 px, gap 40 px, top 240 px (below the user story).
4. **Green example stickies** under each rule, stacked vertically. See "Sticky content rules" below for what goes inside each one. Long examples should be tightened to ~30 words. If the curated text exceeds Miro's sticky limit (~1024 chars), split into two stickies with a `(1/2)` / `(2/2)` suffix on the title.
5. **Red question stickies** in a right-hand column. Resolved questions sit at the bottom of that column with an italic `<em>(resolved)</em>` tag at the top of the sticky; original wording is preserved.

Use the same colour names you saw on input (so resolved theming matches). If colours were inconsistent on input, normalise to the default palette and tell the user.

### Sticky content rules

These two rules apply to every sticky pushed to Miro — yellow, blue, green, red alike. They exist because the previous output had unreadable stickies and the user called it out.

**1. No sticky-id annotations on the board.**

The `(s_XXXXXX)` ids appear in the Markdown for traceability. **They never appear on a Miro sticky.** They make stickies barely readable, and the original frame sits right next door if the team needs to match items back. Do not put ids in the title line, the body, or any tag. The Markdown is the source of truth for id mapping; the Miro frame is the team-facing artefact and should be optimised for reading speed.

**2. Use rich-text formatting so stickies are scannable.**

Plain-text walls are hostile to read. Every sticky must use formatting where it helps. Confirm the supported tag set against the DSL spec returned by `layout_get_dsl` (Miro currently accepts HTML-like tags in sticky content), then apply at least:

- **Bold the title** on the first line.
- A line break between the title and the body.
- **Italic for inline tags** like `(PROPOSED)`, `(resolved)`, `(new — proposed gap)`, `(reframed)` — anything that flags a non-original item.
- **Short bullet lists** when the body has multiple atomic facts. Two or three bullets read far better than a comma-separated paragraph.
- **Line breaks between distinct ideas** inside the body.

Example sticky content (HTML form — adapt to Markdown if `layout_get_dsl` says so):

```
<strong>Marie buys at full price</strong><br>
<br>
She adds €120 of items to her cart and pays €120 at checkout.
<ul>
  <li>No discount code entered</li>
  <li>First-time customer</li>
</ul>
```

A proposed rule (not on the original frame) would look like:

```
<strong>R3 — Stack discount with loyalty</strong> <em>(PROPOSED)</em><br>
<br>
A logged-in member who also enters a promo code gets both reductions, applied multiplicatively.
```

A resolved question:

```
<em>(resolved)</em><br>
<strong>Can the discount stack with a promo code?</strong><br>
<br>
Answered by Example 2.3.
```

If a sticky has no body to add (a short rule, a one-line question), bolding the title and skipping the rest is fine — the formatting is here to help reading, not to inflate content.

### Step 4 — Execute and verify

Call `mcp__miro__layout_create` once with the full DSL payload. The response includes a list of items that failed. If any failed:

- Show the user the failures (sticky text + error).
- Offer to retry just the failures rather than re-running the whole frame creation.
- Never silently succeed-partial — the user must know what's in Miro and what isn't.

After success, share the new frame URL with the user. They can construct it as: `{board URL}?moveToWidget={new frame ID}`. The `layout_create` response should include the new frame's ID.

## Meta-findings sidecar frame

Pass G (US INVEST + proposed splits), Pass E (role-lens) and Pass F (vocabulary drift) outputs are published to a **separate sidecar frame** next to the curated frame, not onto the curated frame itself. This keeps the curated frame clean — it remains the team's authoritative artefact for the user story — while putting lens-driven findings on the board where the team actually does its work.

### Position

- Same `y` as the curated frame.
- `x = curated.x + curated.width/2 + 200 + sidecar.width/2` (200 px gutter).
- Default width: **2400 px**.
- Default height: **3200 px** when Pass G ran (room for the INVEST band on top). **2400 px** when Pass G was skipped (INVEST band is absent). Lengthen further if more than 3 lenses were activated.

### Layout (frame interior, parent-relative coordinates)

The frame is laid out top to bottom. Two layout variants depending on whether Pass G ran:

**Variant A — Pass G ran** (default; INVEST band present):

1. **Banner** (`TEXT`, ~y=60): "Meta-findings — companion to the curated frame"
2. **Sub-banner** (`TEXT`, ~y=120): one-line explanation that these are candidates, each citing a sticky id
3. **§1 — INVEST & proposed splits section header** (`TEXT`, ~y=215)
4. **INVEST scorecard sticky** (`STICKY`, ~y=400, `color=light_yellow`, `shape=rectangle`, `w=1200`, centred): one sticky carrying the six-criterion line + one short line per ✗. Format inside the sticky: `<strong>INVEST scorecard</strong><br><br>Independent ✓ · Negotiable ✓ · Valuable ✓ · Estimatable ✓ · Small ✗ · Testable ✓<br><br><em>Small ✗ — 8 rules over two distinct outcomes; see splits below.</em>`
5. **Proposed split stickies** (`STICKY`, ~y=720, `color=yellow`, `shape=rectangle`, `w=700`): 0–3 stickies, laid out in a horizontal row. Each carries the slice title + the rule ids it absorbs + the standalone-value line. Omit this row entirely if no splits were proposed.
6. **§6 — Vocabulary drift section header** (`TEXT`, ~y=1050)
7. **Vocabulary cluster stickies** (`STICKY`, ~y=1240, `color=cyan`, `shape=rectangle`, `w=700`): one per cluster, horizontal row. Stop at 5 clusters; overflow to the sidecar Markdown file.
8. **§7 — Role-lens findings section header** (`TEXT`, ~y=1470)
9. **One column per activated lens** (3 by default: PM, Dev, QA). Column header is a `TEXT` at ~y=1570 above each column. Findings are `STICKY` rectangles, `w=700`, with centres at y=1740, 2020, 2300, 2580, 2860 (vertical spacing 280 px, room for 5 findings per lens). Column centres at x=400, 1200, 2000 for a 2400-wide frame.
10. **Footer** (`TEXT`, ~y=3100): pointer to the Markdown file for full reasoning.

**Variant B — Pass G skipped** (INVEST band absent — falls back to the original layout):

1. Banner (y=60), sub-banner (y=120)
2. §6 header at y=215, vocab stickies at y=400
3. §7 header at y=625, lens column headers at y=720, findings at y=900/1180/1460/1740/2020
4. Footer at y=2300

### Colour scheme

Findings use distinct colours from the curated frame's palette to make the sidecar visually independent:

| Source | Colour | Rationale |
|---|---|---|
| INVEST scorecard (§1) | `light_yellow` | echoes the US colour without competing with the curated frame's yellow |
| Proposed splits (§1) | `yellow` | each split is a candidate sub-US, so the strongest US-coded hue |
| Vocabulary clusters (§6) | `cyan` | neutral / observational, no conflict with R/G/B/Y |
| PM lens | `light_blue` | strategic / cool |
| Dev lens | `violet` | technical / distinct |
| QA lens | `orange` | "warning" tone; also flags the no-QA case when relevant |
| Design lens (optional) | `light_pink` | UX hue |
| Data lens (optional) | `light_green` | metrics hue (distinct from `dark_green` examples on curated frame) |
| SRE lens (optional) | `gray` | operational tone |

When the team has no QA, the QA column header includes `⚠ <em>no QA in team — would otherwise be missed</em>` to make the missing perspective explicit.

### Per-finding sticky content

Every **lens or vocabulary** finding sticky follows the same shape:

```
<strong>{Title — short, 4–8 words}</strong>
<br><br>
{Body — 1–3 short paragraphs. Reference sticky ids in plain text: `s_4606601`, `Ex 2.4`, `R2c`. Use <br> between distinct ideas.}
```

The **INVEST scorecard** sticky is a single wider sticky carrying the full six-criterion line + italic explanations for each ✗:

```
<strong>INVEST scorecard</strong>
<br><br>
Independent ✓ · Negotiable ✓ · Valuable ✓ · Estimatable ✓ · Small ✗ · Testable ✓
<br><br>
<em>Small ✗ — 8 rules over two distinct outcomes; see splits below.</em>
```

Each **proposed split** sticky is shaped like a candidate sub-US:

```
<strong>Slice 1 — {short slice title}</strong>
<br><br>
<em>As a {persona}, I want {goal}, so that {motivation}.</em>
<br><br>
Rules: <strong>R1</strong>, <strong>R3</strong>, <strong>R4</strong>.
<br>
Standalone: {one-line standalone value}.
<br>
Defers: {what this slice does not cover}.
```

Per the workshop-wide sticky rules: no `(s_XXXXXX)` annotations on stickies themselves, even meta-finding ones; the sticky id refs in the body are short tokens (`R1`, `s_4606601`), not the full `(s_XXXXXX)` annotation form used in the Markdown.

### Failure of the sidecar should not block the curated frame

If the curated frame succeeded but the sidecar fails, that's still a partial-success outcome. Report both URLs (curated succeeded, sidecar failed with reason) rather than rolling back the curated frame.

## Common pitfalls

- **HTML in sticky content (reading)**: always strip tags before analysis — you want the team's plain words, not the formatting they used.
- **HTML in sticky content (writing)**: the opposite direction is mandatory. Curated stickies must be formatted per the "Sticky content rules" section above (bold titles, italic tags, line breaks, bullets where useful). A plain-text wall is a failed publication.
- **Multilingual workshops**: detect language per sticky, not per workshop. Some teams mix French and English. Curate each in its own language; flag mixing in the Markdown.
- **Empty stickies**: a blank sticky is a finding. Flag it in the Markdown ("Empty sticky at position …") and do not propagate to the curated frame.
- **Misclassified colours**: if a team used a green for a question (rare but happens), do not auto-recolour. Surface it in the orphan section: "Sticky '…' is green but reads as a question — please confirm intent."
- **Sticky size variation**: teams sometimes resize a sticky for emphasis. Ignore size for clustering; use centre coordinates only.
