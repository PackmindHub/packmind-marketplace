---
name: 'curate-em-workshop'
description: 'Analyse and improve the output of a team Example Mapping workshop captured in a Miro frame. First calibrates understanding of the user story against any product context available in the repo (PRODUCT.md, DESIGN.md, README, related code) and confirms framing with the user before touching anything. Then reads stickies (yellow user story, blue rules, green examples, red questions), curates them against quality criteria, proposes missing scenarios, produces a Markdown review for human approval, and finally publishes a curated copy into a new Miro frame next to the original. Use whenever the user shares a Miro frame URL containing an Example Mapping board, asks to "review", "curate", "clean up", "améliorer", "relire" an EM workshop, or wants to turn a raw workshop into a shared specification. Also use when the user mentions sticky reviewing, rule reformulation, missing examples, or workshop debriefing in a BDD / Example Mapping context.'
---

# Curate Example Mapping Workshop

You help a facilitator turn the raw output of a live Example Mapping workshop into a curated, shareable artefact. The team produced sticky notes on a Miro frame; your job is to read them, lift the quality of each item, surface gaps, and republish the result — but only after the human has reviewed the analysis in Markdown.

## When this skill is in play

The user provides (or is about to provide) a Miro URL pointing at a frame that contains an Example Mapping workshop. Typical phrasing:

- "here is yesterday's workshop frame, can you clean it up"
- "review this example mapping board"
- "curate this EM frame and tell me what we missed"
- non-English phrasings count too (e.g. French "peux-tu nettoyer cette frame d'EM") — match the user's language back when speaking to them, but keep the skill's internal reasoning in English

If the user only gives a board URL (no specific frame), call `mcp__miro__context_explore` first to list frames, then ask which one to curate. Never guess.

## Sticky conventions

Example Mapping uses four sticky colours. Detect them by the colour metadata returned by Miro (`fill_color`, `style.fillColor`, or similar). Tolerate hex-vs-name variants; cluster by hue, not exact code.

| Colour | Meaning | Cardinality |
|---|---|---|
| Yellow | User Story (the subject of the workshop) | usually 1 |
| Blue | Business rule that constrains the story | several |
| Green | Concrete example illustrating a rule | many, grouped under a rule |
| Red | Open question / unknown | as many as the team raised |

**Clustering rule → examples.** Example Mapping is spatial: green stickies sit physically below or to the right of the blue rule they illustrate. Use sticky coordinates (`x`, `y`, `width`, `height`) returned by `board_list_items` to assign each green to its nearest blue. If clustering is ambiguous (a green is equidistant from two blues, or far from all blues), flag it in the Markdown — do **not** silently choose.

## Workflow

This skill runs in six phases. **Two phases are hard human checkpoints**: Phase 2 (Calibrate understanding) and Phase 5 (Markdown review). Do not skip either, even if the workshop looks self-explanatory. Curation without alignment on what the team meant produces confident nonsense.

### Phase 1 — Read the source frame

1. Parse the Miro URL. Extract the board ID and, if present, the `moveToWidget=` frame ID.
2. Call `mcp__miro__board_list_items` with `item_type="sticky_note"` and the frame-scoped URL. Page through all results.
3. Capture for each sticky: `id`, `content` (plain text), `fill_color`, `x`, `y`, `width`, `height`, `parent` (frame ID).
4. Detect the input language from sticky content. All curation output must match that language (rules, examples, questions, titles). The skill's internal reasoning stays in English; only user-facing artefacts switch.

If `board_list_items` returns nothing for the frame, fall back to `mcp__miro__layout_read` on the frame URL — it returns a DSL dump including stickies. See `references/miro-io.md` for parsing details.

### Phase 2 — Calibrate understanding of the user story (human checkpoint)

Curation is interpretive work. Before you rewrite a single example, make sure you understand what the team was solving for. A misread of the user story propagates into every rule and every example — silently and confidently.

This phase has three steps. **Do not skip step 3, even if the user story looks crystal clear.**

#### Step 1 — Extract and parse the yellow sticky

Pull the user story content out of the yellow sticky (or stickies, if there are several — flag the ambiguity). Identify:

- **Persona** — who acts ("En tant que …", "As a …")
- **Goal** — what they want ("je veux …", "I want …")
- **Motivation** — why ("pour …", "so that …")

If any of the three is missing or vague, that itself is a finding — note it and ask the user about it in step 3.

#### Step 2 — Pull domain context from the repo (when available)

The skill works in any project, but produces richer calibration when the repo provides product context. Look for the following files at the project root, in order, and read what you find:

1. `PRODUCT.md` — product purpose, users, jobs to be done (Packmind convention)
2. `DESIGN.md` — design rationale, target experiences
3. `README.md` — high-level overview (fallback when neither of the above exists)
4. `docs/product.md`, `docs/vision.md`, `docs/strategy.md` — alternative locations some teams use

Cross-reference the user story against these documents:

- Does the persona on the sticky match the personas described in PRODUCT.md? (e.g., a sticky saying "En tant qu'admin" against a product targeting "Tech leads, staff engineers, engineering managers" — there might be a mismatch worth surfacing.)
- Does the goal align with a documented job-to-be-done?
- Are there constraints or anti-patterns documented elsewhere that contradict or constrain the workshop's framing?

Then, optionally, run **light** code searches to spot whether the feature already exists or touches known surfaces:

- Pick 2–3 key nouns/verbs from the user story (e.g., "loyalty", "discount", "checkout").
- Run `grep -rli` on the codebase, capped at a handful of hits each.
- Surface the most relevant files (handler / route / domain entity names). One or two lines of summary, not a dump.

Be conservative: code search is here to *spot* relevance, not to deep-dive. If the user story is purely about a future feature with no code yet, this step yields nothing — that's fine, say so.

If no product context files exist and grepping turns up nothing useful, this phase becomes a lighter version: you only have the yellow sticky to go on. Still do step 3 — the human alignment is the point, the context is just there to make alignment richer.

#### Step 3 — Synthesise a Brief and ask for confirmation

Produce a short understanding brief and present it to the user. The skill itself is written in English; when the workshop is in another language (French, Spanish, etc.), translate the labels below so the user reads them in the workshop's language. Use this exact shape:

> **Before I touch any sticky, here is what I understand of this workshop:**
>
> - **Target user**: {persona, in your own words — note any link to a PRODUCT.md persona if relevant}
> - **Goal**: {goal restated}
> - **Why it matters**: {motivation + what PRODUCT.md / the code says about it, if there is anything}
> - **Relevant product context**: {1–3 bullets from PRODUCT.md / DESIGN.md / code — only what informs the US, not a dump}
> - **Assumptions I'm making**: {what you inferred rather than read — be explicit}
> - **Role lenses for Pass E (multi-role challenge pass)**: PM, Dev, QA. Add Design / Data / SRE if this workshop's scope calls for them. The QA lens stays active even without a QA in your team — that's where it brings the most value.
> - **US INVEST review (Pass G)**: **on** by default — I will score the user story against the six INVEST criteria and propose splits if the story is too large or coupled. Reply "skip INVEST" if the story has already been groomed upstream and you don't want a second pass on it.
>
> Is this the right framing? Correct me before I move on to rules and examples. You can also adjust the role lenses or toggle INVEST in your reply.

Then **wait**. Do not move to Phase 3 until the user responds. Accept three kinds of answers:

- **Confirmation** ("yes", "go", "that's it", "oui", "c'est ça") → proceed to Phase 3.
- **Correction** → integrate the correction, regenerate the brief, ask again. Iterate until aligned.
- **Reframing** ("no, the real US is more like …") → treat as a correction; the team's original yellow sticky may have been weak. Capture the corrected understanding as the basis for curation, and note in the Markdown that the user story itself needs to be revisited.

#### Step 4 — Capture the alignment in working state

Once the user has confirmed, store the agreed understanding (persona, goal, motivation, key context bullets, assumptions, **active role lenses**, **INVEST review on/off**) — you'll quote it verbatim in section 0 of the Markdown review (Phase 5). The team should be able to read the curated Markdown and see exactly what framing the curation was built on, including which role lenses were used in Pass E and whether Pass G ran.

### Phase 3 — Build the working model

Bucket stickies by colour. For each rule (blue), compute the set of examples (green) anchored to it via spatial proximity. Hold orphan greens (no nearby blue) and orphan blues (no examples) explicitly — they are findings, not noise.

### Phase 4 — Curate

Run up to seven passes, in this order. Each pass produces a section of the Markdown output.

Passes A–D work on what the team **said** (lifting, deduplicating, gap-detecting). Passes E and F add the value that a curator brings beyond mechanical clean-up: Pass E surfaces what the team **didn't say** by reading through multiple role mindsets; Pass F surfaces what the team **said incoherently** by detecting vocabulary drift. Pass G turns the lens back on the **user story itself** to check INVEST fitness and propose splits when the story is too large or coupled. Passes E, F, G all produce candidates for the team to validate, never decisions. Pass G is the only optional one — skip it when the user disabled INVEST in Phase 2.

**Four invariants govern every pass.** They are not "nice-to-haves" — they are what makes curation *trustworthy* to the team that ran the workshop:

1. **Never silently rewrite a rule or an example.** Every change shows both the original text and the curated version side-by-side, plus a one-line rationale. The team must be able to see exactly what you did and why. A rewrite without the original is indistinguishable from invention.
2. **Never delete a sticky from the record.** Duplicates, off-topic stickies, misclassified colours — all stay visible in the curated output, marked with their issue and a suggested action. Deletion belongs to the team, not the curator. A skill that deletes is a skill that quietly rewrites history.
3. **Never promote a missing scenario to a green example.** Gap analysis surfaces *questions* (red), not new examples. The team validates them and may turn them into examples in the next workshop. This is the user's explicit preference and the difference between "the curator helped the team think" and "the curator made up business rules".
4. **Always preserve sticky-id traceability.** Every curated rule, example, and question heading carries the original Miro sticky id in backticks next to its label — e.g. `### Rule 1 (\`s010\`) — wording`, `#### Example 1.1 (\`s011\`) — Title`, `- Q1 (\`s040\`, original): …`. Without this, the team cannot match the curated Markdown back to the original frame, and a "renamed Example 1.1" looks indistinguishable from a deleted sticky. New gap questions get no id (they did not exist in the workshop); proposed gaps are tagged `*(new — proposed gap)*` instead.

If you catch yourself wanting to break one of these invariants for any reason, stop and surface it as a finding instead.

#### Pass A — Examples (green)

For every green sticky, evaluate against the six quality criteria below. When a criterion is missed, rewrite the example to fix it while keeping the team's intent. Always preserve the original text alongside the rewrite so the team can compare.

**A good example is:**

- **Concrete** — real values, never variables. "Marie pays €29.90" beats "a user pays an amount". If the original says "a user" with no value, invent plausible domain-realistic values *and flag the rewrite* so the team can swap in their own.
- **Unambiguous** — exactly one interpretation. If two readers could imagine two different outcomes, the example is too vague. Surface the ambiguity, propose a disambiguated version.
- **Realistic** — drawn from actual business life, not a contrived edge case. Skip "what if a user is 999 years old" unless age-gating is a real rule.
- **Minimal** — no superfluous data. If removing a detail does not change the outcome, remove it. Mention the removal in the comparison block.
- **Revealing** — illustrates a typical case, an edge case, or a key business rule. If an example is just a duplicate of another with cosmetic changes, mark it as a duplicate (do not delete — let the team decide).
- **Named** — has a short title (2–5 words) the team can use as shared vocabulary in code and conversation. If the original lacks a title, invent one. Titles must be unique within the workshop.

These are the standard six EM quality criteria (originally framed in French as Concret · Univoque · Réaliste · Minimal · Révélateur · Nommé). Use the English labels above when speaking to the user in English, and translate them to the workshop's language when filling the Markdown criteria scorecard so the team reads them in their own words.

For each example, produce: original text, curated text, title, criteria scorecard (✓/✗ per criterion), notes.

#### Pass B — Rules (blue)

A rule is a generalisation of its examples. After Pass A, re-read the curated examples grouped under each blue sticky and ask: does the rule's wording match what the examples actually show?

- If the examples are narrower than the rule wording, the rule is overclaiming — tighten it.
- If the examples cover scenarios the rule does not mention, the rule is incomplete — widen it or split it.
- If two rules end up illustrated by overlapping examples, propose a merge or a sharper distinction.

Each rule gets: original wording, curated wording (or "unchanged"), rationale, list of attached example titles.

#### Pass C — Duplicates & resolved questions

Cross-check the whole frame:

- **Duplicate examples**: same outcome under the same rule, different wording. Group them; suggest which to keep.
- **Overlapping rules**: two blues that describe the same constraint. Flag for merge.
- **Resolved questions**: for each red sticky, check whether the curated examples or rules already answer it implicitly. If yes, move the question to a "Resolved" subsection with the answer pulled from the relevant example(s).

#### Pass D — Missing examples (gap analysis)

For each curated rule, brainstorm scenarios the team likely forgot. Useful prompts:

- The happy path is present — what about the most common failure mode?
- Is there a boundary (zero, max, threshold, expiry, empty collection)?
- Is there a privileged-actor variant (admin, owner, guest)?
- What happens when two rules collide on the same input?
- Are there time-of-day / locale / currency / unit variants the rule is silent about?

Each gap becomes a **new red sticky** (a question, not a stated example). Phrasing: "What if Marie tries to pay with an expired card?" rather than "Marie tries to pay with an expired card and …". The team validates and decides whether to convert to a real example later. This is the user's explicit preference — never promote a proposed gap directly to a green sticky.

#### Pass E — Multi-role lens

Passes A–D work on what the team said. Pass E works on what the team **did not say** — by reading the curated EM through the mindset of each role that was (or wasn't) in the room. This is where a curated EM stops being a clean-up and starts being an alignment tool: the lens that wasn't in the workshop is the one most likely to spot the angle the team missed.

For each lens declared in Phase 2 (default: PM, Dev, QA), run one mini-pass:

1. Re-read the curated rules, examples, and questions through that role's **epistemic angle**. See `references/role-lenses.md` for the specific questions each lens asks naturally.
2. Generate up to **5 findings** for that lens — new questions, gaps, or angles the workshop didn't surface. The cap is hard: beyond 5, the lens loses focus and findings dilute each other.
3. Each finding **must** reference a specific sticky id (the one it challenges) or be tied to a specific rule. Floating "good practice" advice ("you should think about scalability") is not a finding — it's noise.
4. **Do not duplicate §3–5.** If a concern is already in Orphans, Duplicates, or Questions, skip it. The lens earns its keep by adding new information, not by repackaging the obvious.

When the team **does not have one of the default roles** (e.g., no QA), keep that lens active anyway and tag its findings with `⚠ (no {role} in team — would otherwise be missed)`. Bringing missing perspectives into the room is precisely the value Pass E adds for sub-staffed teams; suppressing the lens in that case removes the most useful output.

Findings populate section 7 of the Markdown (one subsection per lens), framed as **candidates for team validation** — not decisions. The team picks which to bring into the next workshop. Pass E findings are **also** published to Miro in Phase 6, on a dedicated sidecar "meta-findings" frame next to the curated frame — not on the curated frame itself. This keeps the curated frame clean (it remains the team's authoritative artefact for *this* US) while putting the lens-driven findings where the team actually does its work.

#### Pass F — Vocabulary drift

A workshop's vocabulary is a hidden artefact. Two stickies saying "user" may mean two different people; one sticky saying "publish" may mean a different action elsewhere on the board. The team rarely notices — the words look the same.

Scan **all** curated stickies (yellow, blue, green, red) and detect three patterns:

1. **Multiple words, same concept** — synonym clusters. E.g., "user" / "customer" / "member" used interchangeably across the workshop.
2. **Same word, multiple meanings** — polysemy. E.g., "publish" meaning *upload to marketplace* in some stickies and *make public* in others.
3. **Singular / plural usage revealing a hidden question** — "the marketplace" vs "marketplaces" can imply a "how many per org?" question that nobody actually asked.

**Surface thresholds (to avoid noise):**

- A cluster appears in §6 only if it has **≥2 distinct surface forms AND ≥3 stickies impacted**. One-offs are noise.
- Cap §6 at **5 clusters**. If more drift was detected, dump the full list to `tmp/em-curations/vocabulary-drift-{slug}-{YYYY-MM-DD}.md` and reference it from §6 with one line ("Full drift report: {path}").

**Never auto-merge or rename.** "user" vs "admin user" may be a legitimate distinction the team made deliberately. The skill **surfaces** the inconsistency and points to the trade-off; the team picks the canonical form (or declares the distinction intentional). Auto-renaming would break the team's vocabulary asset and would itself become an invisible source of misalignment — exactly the failure mode Pass F is supposed to prevent.

Like Pass E, vocabulary clusters are **also** published to the sidecar meta-findings frame in Phase 6 — they form the middle band of that frame, between the INVEST band (top) and the role-lens columns (bottom).

#### Pass G — US INVEST review (optional)

Passes A–F work on the EM body. Pass G turns the lens back on the **user story itself** to check whether it's a story the team can deliver well, and proposes splits when it isn't.

This pass runs **last** by design. Assessing **Small** and **Independent** requires having seen all the rules and examples first; **Valuable** can be sharpened by Pass E's PM-lens findings; **Testable** depends on how Pass A scored the examples. Earlier in Phase 4 you don't yet know the story's true shape.

Skip Pass G entirely if the user replied "skip INVEST" in Phase 2 — running it on an already-groomed story produces noise the team will rightly ignore.

Score the user story against the six INVEST criteria. For each ✗, write one short line explaining what's missing.

- **Independent** — the story doesn't rely on another story to ship. If the rules cross-reference an in-flight feature or a not-yet-built capability, flag the coupling.
- **Negotiable** — the wording leaves room for the team to shape the solution. A sticky that prescribes implementation ("via a modal dialog…", "using endpoint X") fails N.
- **Valuable** — completing the story delivers something a real user can observe and benefit from. If only an internal system or a future story benefits, flag it.
- **Estimatable** — the team would be able to size the work after this curation. If too many rules stayed unsharpened or too many examples are missing, E fails.
- **Small** — the story can be completed in a short delivery window. Heuristic: ≥6 well-formed rules, OR rules clustering into clearly distinct outcomes, OR a curated example set deep enough to imply multi-sprint work — any of these strongly suggest the story is too large.
- **Testable** — the curated examples give a clear acceptance set. If most examples failed Pass A's Concrete or Unambiguous criteria, T fails.

**Propose splits when Small or Independent fails — OR when the rules cluster into distinct user-observable outcomes.** A split is a candidate sub-story carrying a subset of the rules:

- Group rules into clusters by **user-observable outcome**, not by topic. Two rules belong to the same cluster only if they support the same outcome a user can perceive.
- For each cluster, propose a sub-story title (As a … / I want … / so that …) and list the rules it absorbs by sticky id.
- Surface the trade-off: what does this slice deliver standalone, and what does it explicitly defer?
- Cap proposals at **3 splits**. Beyond that, the original story is so broad it needs a different conversation upstream, not a split — say so in §1 notes.

Splits are **candidates**, not decisions — same posture as Pass E and Pass F findings. The team picks the slicing strategy.

Pass G populates section 1 of the Markdown (alongside the original/curated US wording) and the top band of the sidecar Miro frame (above vocabulary, above the lens columns). It is the only Pass G output — there is no separate §G or §9.

### Phase 5 — Produce the Markdown review and STOP

Write the curated workshop to a Markdown file the user can scan. Format is fixed — see `references/markdown-template.md`. Save to `tmp/em-curations/{slugified-story-title}-{YYYY-MM-DD}.md` at the project root (create the directory if missing). Display the full Markdown in the conversation as well.

Then say (translate to the workshop's language if it isn't English — keep the meaning identical):

> Here is the curated analysis. Read through it and tell me what to adjust before I publish to Miro. I won't write anything to the frame until you've approved.

**Do not call any `mcp__miro__*` write tool yet.** Wait for an explicit go-ahead ("ok", "publish", "go", "ship it", "looks good", "publie", "envoie", etc.). If the user asks for changes, iterate on the Markdown and present it again. Repeat until approved.

### Phase 6 — Publish to a new Miro frame

Once approved:

1. Call `mcp__miro__layout_get_dsl` once to refresh the DSL spec (the format can evolve). Inspect what rich-text formatting the spec supports — typically HTML-like tags such as `<strong>`, `<em>`, `<br>`, `<ul>/<li>`. You'll use these in step 3.
2. Compute the target frame position: same `y` as the source frame, `x = source.x + source.width + 200` (gap of 200 px to the right). Same width/height as the source.
3. Generate a DSL payload that creates:
   - A new frame with title `{original frame title} — curated ({YYYY-MM-DD})`
   - The yellow user story sticky at top-left
   - Blue rule stickies in a horizontal row
   - Green example stickies in a column under each rule, in the order they appear in the Markdown
   - Red question stickies in a right-hand column, with resolved ones visually separated

   **Two non-negotiable rules for what goes on each sticky:**

   - **Strip sticky-id annotations.** The `(s_XXXXXX)` ids belong in the Markdown for traceability, but they make published stickies barely readable on the board. Each curated item appears in Miro with its title and body only — never the source id, never an id-tagged heading. The original frame is still right next door if the team needs to match items back.
   - **Use rich-text formatting to make stickies scannable.** A wall of plain text on a sticky is hostile to read. Apply, at minimum:
     - **Bold** the title on the first line (e.g., `<strong>Marie buys at full price</strong>`)
     - A line break (`<br>`) between the title and the body
     - **Italic** inline tags such as `<em>(PROPOSED)</em>`, `<em>(resolved)</em>`, `<em>(new — proposed gap)</em>` — anything that flags a non-original item
     - Short bullet lists (`<ul><li>…</li></ul>`) when the body has multiple atomic facts (acceptance criteria, sub-cases). Two or three bullets read far better than a comma-separated run-on.
     - Line breaks between distinct ideas inside the body — don't pack everything into one paragraph
   - Confirm the exact tag set from the DSL spec returned by `layout_get_dsl` at step 1. If the spec uses Markdown syntax (`**bold**`, `*italic*`) instead of HTML, use that instead. The principle stays the same: the sticky must be visually scannable in under three seconds.

   Keep wording terse so it fits a standard sticky — formatting helps readability but does not justify long content.
4. Call `mcp__miro__layout_create` with the DSL.
5. **Build and publish the meta-findings sidecar frame** carrying §1 (INVEST + proposed splits, if Pass G ran), §6 (vocabulary) and §7 (role-lens) content. This frame is positioned to the right of the curated frame (same `y`, `x = curated.x + curated.width/2 + 200 + sidecar.width/2`). Layout, top to bottom: a banner explaining the frame, then the **INVEST band** (one `light_yellow` sticky for the scorecard with ✗ explanations + up to 3 `yellow` split-proposal stickies, omitted entirely if Pass G was skipped), then the **vocabulary band** (cyan stickies, horizontal row), then the **role-lens columns** (N vertical columns, one per lens activated in Phase 2). Use `light_blue` for PM, `violet` for Dev, `orange` for QA (with the `⚠ no QA in team` banner above the column when applicable), and pick distinct colours for any additional lenses (Design / Data / SRE). Each finding sticky carries a bold title + body referencing the sticky ids it challenges. The curated frame stays clean — these findings belong on a companion frame, not on top of the workshop content. See `references/miro-io.md` for the full sidecar layout spec.
6. Report **both** frame URLs to the user (curated + sidecar). If any items failed to create in either frame (the response lists them), tell the user which ones and propose a retry rather than silently dropping them.

See `references/miro-io.md` for DSL specifics (colours, sizing, sticky text limits, formatting examples, sidecar layout).

## Output Markdown format

The intermediate Markdown is the contract between you and the user. It must follow `references/markdown-template.md` exactly so the user always knows where to look for what.

Top-level shape (illustrated in English — when the workshop is in another language, translate the labels so the team reads them in their own words):

```markdown
# Curated Example Mapping — {Story title}
> Source frame: {miro_url}
> Curated on: {YYYY-MM-DD}
> Language: {en / fr / …}

## 0. Agreed understanding
- **Target user**: …
- **Goal**: …
- **Why it matters**: …
- **Relevant product context**: …
- **Assumptions**: …
- **Sources consulted**: PRODUCT.md / DESIGN.md / code (or "none available" — a single line, do not duplicate)

## 1. User Story (yellow, `s001`)
- Original: …
- Curated: …
- INVEST: Independent ✓ · Negotiable ✓ · Valuable ✓ · Estimatable ✓ · Small ✗ (8 rules covering two distinct outcomes) · Testable ✓
- Proposed splits:
  - **Slice 1 — As a buyer, I want to apply a promo code** (rules `s010`, `s020`, `s030`) — delivers cart-side discount standalone.
  - **Slice 2 — As a buyer, I want my loyalty discount auto-applied** (rules `s040`, `s050`) — depends on Slice 1's price model.
- Notes: …

## 2. Rules & Examples
### Rule 1 (`s010`) — {curated rule wording}
- Original wording: …
- Rationale: …

#### Example 1.1 (`s011`) — {Title}
- Original: …
- Curated: …
- Criteria: Concrete ✓ · Unambiguous ✓ · Realistic ✓ · Minimal ✗ (removed phone number, irrelevant) · Revealing ✓ · Named ✓
- Notes: …

#### Example 1.2 (`s012`) — {Title}
…

### Rule 2 (`s020`) — …

## 3. Orphans & ambiguities
- Sticky `s160` (green): could attach to Rule 1 or Rule 3; suggested: Rule 1 because …
- Sticky `s330` (blue): no examples — suggested gap questions below.

## 4. Duplicates & overlaps
- Examples 1.2 (`s012`) and 1.4 (`s014`) describe the same outcome — propose keeping 1.2.

## 5. Questions (red)
### Still open
- Q1 (`s040`, original): …
- Q2 (proposed gap): What happens if Marie's card is expired? *(new — not from the workshop)*

### Resolved by curated examples
- Q3 (`s201`, original): "Can the discount stack with a promo code?" → answered by Example 2.3 (`s022`).

## 6. Vocabulary drift
- **user / customer / member** — used interchangeably across stickies (`s010`, `s021`, `s032`). To resolve: single concept, or three distinct personas?

## 7. Role-lens findings
### Through a PM lens (value, scope, persona, outcome)
- §0 — Persona "user" ambiguous: R3 (`s030`) implies admin scope but Example 2.1 (`s021`) reads end-user.

### Through a Dev lens (implementability, edges, contracts)
- R2 (`s020`) — Implies atomicity; no example covers partial upload failure.

### Through a QA lens ⚠ (no QA in team — would otherwise be missed)
- **Boundary**: marketplace with zero packages — no example covers this state.

## 8. Suggestions for the next iteration
- …
```

## Failure modes to watch for

- **Translating without flagging**: if you rewrote a French sticky into English (or vice versa), you broke the team's vocabulary. Match the input language.
- **Inventing facts**: if a sticky says "le client paie" with no amount, you may suggest "29,90 €" *as a placeholder*, never as a fact. Mark suggestions with *(suggested value — please confirm)*.
- **Auto-deleting**: never remove a sticky from the team's record. Duplicates and stale items get flagged, not removed.
- **Skipping a checkpoint**: Phase 2 (calibration) and Phase 5 (Markdown review) are both non-negotiable. Even if the curation feels obviously right, the human aligns first on the user story, and approves before Miro is touched. Two stops, both mandatory.
- **Skipping calibration because the user story "looks fine"**: this is the most common failure mode. The team that ran the workshop knows what they meant; you are guessing. Always do Phase 2.
- **Over-curating titles**: a sticky title is a vocabulary asset. Stay close to terms the team already used. Don't rename "Panier abandonné" to "Cart Abandonment Workflow".

## Iterating on a previously curated frame

If the user returns with the same source frame later (the Markdown file already exists under `tmp/em-curations/`), treat it as a continuation:

- Read the existing Markdown first.
- Re-pull the Miro frame to detect new stickies, edits, or removals since last curation.
- Surface the diff explicitly ("3 new green stickies added under Rule 2; Example 1.4 was edited") before re-running the curation passes.
- Preserve curated titles you previously agreed on, unless the underlying example changed enough to warrant renaming.