# Markdown template for the curation review

This is the exact structure the curation Markdown must follow. The user relies on consistent positioning to scan quickly. Stick to the headings and ordering below; vary only the leaf content.

The file is named `tmp/em-curations/{slugified-story-title}-{YYYY-MM-DD}.md`, created at the project root.

**Language note.** The template is illustrated in English. When the workshop is in another language (French, Spanish, Portuguese, …), translate the section labels and prompt text below so the team reads the Markdown in their own words. Sticky content stays in the workshop's language regardless — never translate the team's vocabulary.

```markdown
# Curated Example Mapping — {Story title in the workshop's language}

> Source frame: {full Miro URL with moveToWidget}
> Curated on: {YYYY-MM-DD}
> Language: {en / fr / multi}
> Stickies read: {N yellow, M blue, P green, Q red} (+ {X unclassified} if any)

---

## 0. Agreed understanding

This section captures the framing aligned on before curation began. It is the contract for everything below.

- **Target user**: {persona, in clear words}
- **Goal**: {goal restated}
- **Why it matters**: {motivation, with one-line link to product context when relevant}
- **Relevant product context**:
  - {Bullet pulled from PRODUCT.md / DESIGN.md / README — only if it shaped curation}
  - {Optional bullet referencing a code area, e.g., `apps/api/src/checkout/` — only if relevant}
  - If no usable product context was found, say so here once: "*No applicable product context — calibration done from the yellow sticky alone.*" Do not also repeat this in the Sources line below.
- **Assumptions**: {anything you inferred rather than read, made explicit}
- **Sources consulted**: PRODUCT.md ✓/✗ · DESIGN.md ✓/✗ · code grep on `{terms}` ✓/✗ — single one-line audit trail. Do not append free-text disclaimers here; those go in the bullet above.
- **Role lenses applied in Pass E**: {comma-separated list, e.g., "PM, Dev, QA"}. Flag any default lens whose role is missing from the team: "⚠ no QA in team — QA lens kept active to surface what would otherwise be missed."
- **INVEST review (Pass G)**: {"applied" / "skipped — story already groomed upstream"}

---

## 1. User Story (yellow)

- **Original**: {verbatim text from the yellow sticky}
- **Curated**: {improved wording, or "unchanged"}
- **INVEST**: Independent {✓/✗} · Negotiable {✓/✗} · Valuable {✓/✗} · Estimatable {✓/✗} · Small {✓/✗} · Testable {✓/✗}
  - {one short line per ✗, e.g., "Small ✗ — 8 rules covering two distinct outcomes; see proposed splits."}
- **Proposed splits**: *(only when Small or Independent failed, OR rules cluster into distinct outcomes)*
  - **Slice 1 — {sub-story title in As a … / I want … / so that … shape}** — rules `{ids}`. Standalone value: {one line}. Defers: {one line, or "nothing"}.
  - **Slice 2 — …** — …
  - {Cap at 3 slices. If the story needs more than 3 slices, write: "*Story too broad for an in-curation split — needs an upstream conversation. See §1 notes for the trade-off.*"}
- **Notes**: {why curated, why these splits — or "fine as-is, INVEST clean"}

If there are multiple yellow stickies, list each and ask the team to pick the canonical one. If Phase 2 reframed the user story significantly (the team agreed the original sticky was off), note it here: *"User story reframed during calibration — original yellow sticky needs a rewrite in Miro too."*

If Pass G was skipped (the user declared the story already groomed in Phase 2), omit the **INVEST** and **Proposed splits** bullets entirely. Don't replace them with a "skipped" placeholder — the §0 line already says it.

---

## 2. Rules & Examples

> Every curated rule, example, and question heading **must** carry its original Miro sticky id in backticks. This lets the team trace each curated item back to the frame and prevents the "renamed but not deleted" reading ambiguity. The ids appear in the Markdown only — they are stripped at publication time so they don't clutter the Miro stickies (see Phase 6 / `miro-io.md`).

### Rule 1 (`s010`) — {curated rule wording}

- **Original wording**: {verbatim}
- **Rationale for change**: {why; or "unchanged"}
- **Attached examples**: {list of example titles with ids}

#### Example 1.1 (`s011`) — {Title}

- **Original**: {verbatim sticky text}
- **Curated**: {rewrite, or "unchanged"}
- **Criteria**: Concrete {✓/✗} · Unambiguous {✓/✗} · Realistic {✓/✗} · Minimal {✓/✗} · Revealing {✓/✗} · Named {✓/✗}
- **Notes**: {one sentence per ✗, what was wrong and what was changed; or "well-formed"}

#### Example 1.2 (`s012`) — {Title}

…

### Rule 2 (`s020`) — {curated rule wording}

…

---

## 3. Orphans & ambiguities

- Sticky `s160` (green): could attach to **Rule 1** or **Rule 3**; suggested: **Rule 1** because {short reasoning}.
- Sticky `s330` (blue): **no examples attached** — see proposed gap questions below.
- Sticky `s170` (colour {X}, content `…`): unclassified, please confirm intent.

If none: write "*No orphans or ambiguities.*"

---

## 4. Duplicates & overlaps

- **Duplicates**: Examples 1.2 (`s012`) and 1.4 (`s014`) describe the same outcome under Rule 1 (`s010`). Suggested: keep **1.2** ({why}).
- **Overlapping rules**: Rule 2 (`s020`) and Rule 5 (`s050`) seem to describe the same constraint ({short diff}). Suggested: merge / sharpen one.

If none: write "*No duplicates or overlaps detected.*"

---

## 5. Questions (red)

### Still open

- **Q1** (`s040`, original): {verbatim text}
- **Q2** (`s041`, original): {verbatim text}
- **Q3** *(new — proposed gap)*: {phrased as a question} — illustrates a potential gap around Rule N (`s0N0`).
- **Q4** *(new — proposed gap)*: …

New gap questions get no id — they did not exist in the workshop. The `*(new — proposed gap)*` tag is the signal.

### Resolved by curation

- **Q5** (`s201`, original): "{verbatim text}" → answered by Example 1.3 (`s013`) ({short answer pulled from the example}).

If a section is empty: write "*None.*"

---

## 6. Vocabulary drift

Terms used inconsistently across the workshop. The team picks one canonical form before the next session, or explicitly confirms the distinction is deliberate. Reported only when ≥2 surface forms AND ≥3 stickies are impacted (one-offs are noise). Capped at 5 clusters; if more were found, full list at `tmp/em-curations/vocabulary-drift-{slug}-{YYYY-MM-DD}.md`.

- **{cluster headword}** — {pattern: synonyms / polysemy / singular vs plural}
  - "{form 1}" → `s010`, `s013`
  - "{form 2}" → `s021`
  - "{form 3}" → `s032`, R3 (`s030`)
  - To resolve: {one-line trade-off the team needs to decide, e.g., "single concept, or three distinct personas?"}

If none: write "*No vocabulary drift detected.*"

---

## 7. Role-lens findings

Findings generated by re-reading the curated EM through each declared role mindset. These are **candidates** for the team to validate, not decisions. Each lens caps at 5 findings; every finding cites a sticky id.

### Through a PM lens (value, scope, persona, outcome)

- {finding} — references `{sticky id(s)}`
- …

### Through a Dev lens (implementability, edges, contracts)

- {finding} — references `{sticky id(s)}`
- …

### Through a QA lens (coverage, boundaries, regression)

> Add the warning banner here if applicable: "⚠ *no QA in team — these findings would otherwise be missed*".

- {finding} — references `{sticky id(s)}`
- …

### Through a {Design / Data / SRE / …} lens

> Include subsections only for lenses the user activated in Phase 2.

- {finding} — references `{sticky id(s)}`
- …

If a lens produced nothing worth raising, write "*No additional findings through this lens.*" — don't pad.

---

## 8. Suggestions for the next iteration

A short, bulleted list of pointers the facilitator can take into the next workshop. Examples:

- The rule "{X}" is the most fragile — three of its examples needed rewriting for ambiguity.
- Two boundary scenarios are missing (zero-quantity cart, expired card). See Q3 and Q4.
- The yellow user story conflates two outcomes — consider splitting in the next session.

Cap this section to 5 bullets. It's a takeaway, not a treatise.

---

*When you're satisfied, reply with "publish" (or "go", "ok", "ship it" — non-English equivalents like "publie", "envoie" also work) and I'll create the curated frame in Miro next to the original.*
```

## Stylistic guidelines

- **Verbatim originals** are quoted as-is, even with typos. Do not normalise.
- **Curated wording** matches the workshop's language. If the workshop was in French, curated text is in French — never translate the team's vocabulary, even if the rest of the Markdown is in English.
- **Titles** use Title Case in English, sentence-case in French. Stay short (2–5 words).
- **Criteria badges** use ✓ and ✗ (with a space-separated `·` between criteria) so they scan in one visual line.
- **No filler**. If everything is fine in a section, say "*Fine as-is.*" rather than padding with paragraphs.
- **Never use `TBD`** (consistent with `create-em-spec`). If something is genuinely uncertain, ask the user before writing.
