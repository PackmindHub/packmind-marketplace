---
name: 'em-to-github-issue'
description: 'Turn a user story from an Example Mapping Miro frame into a GitHub issue, in one of two modes — a short dev-ready ticket (US + Gherkin + DoD) or a full Product Requirement Document (PRD) covering context, goals/non-goals, personas, success metrics, functional + non-functional requirements, dependencies, rollout plan and design links, with an engineering checklist appendix. Reads yellow user story, blue rules, green examples and red questions from the frame, warns on unresolved questions, builds an English issue body, previews it, then publishes via `gh issue create` after explicit human confirmation. Use when a Miro EM frame URL is paired with intent to ship to developers or formalise a product spec — triggers include "create the GitHub issue", "make the dev ticket", "draft the PRD", and French equivalents ("crée l''issue", "rédige le PRD", "publie la US"), or piping `curate-em-workshop` output toward GitHub.'
---

# EM to GitHub Issue

You turn the output of an Example Mapping workshop into a GitHub issue developers and stakeholders can act on. The Miro frame holds the team's thinking; the issue is the contract that crosses into the dev and product worlds.

The skill ships in **two modes**, chosen at the very start of the run:

- **Short ticket** — the historical mode. A compact dev-ready issue: US, Gherkin acceptance criteria, technical hints, DoD. Use it for small, well-scoped stories where the team already shares full product context.
- **PRD (Product Requirement Document)** — a full product spec published as a GitHub issue. Adds context & problem, goals/non-goals, personas, success metrics, non-functional requirements, dependencies & risks, rollout plan and design links — with the dev-ready checklist relegated to an *Engineering checklist* appendix. Use it for net-new features, cross-team work, anything a PM or stakeholder needs to align on before code starts.

The issue body is always in **English**, regardless of the workshop or conversation language. Developers and stakeholders across the repo work in English in tickets; the workshop language stays on Miro.

## When this skill is in play

The user shares (or has already shared) a Miro frame URL pointing at an Example Mapping board, and signals intent to move the story toward implementation or formalise it as a product spec. Typical phrasings:

- "ok this US is ready, create the GitHub issue"
- "publish this user story to GitHub" / "make the dev ticket from this frame"
- "draft the PRD for this story" / "turn this workshop into a product spec"
- "crée l'issue GitHub pour cette US" / "publie cette user story sur GitHub" / "fais le ticket"
- "rédige le PRD pour cette US" / "transforme ce workshop en doc produit"

If the user gave only a Miro board URL (no specific frame), call `mcp__miro__context_explore` first to list frames and ask which one to publish. Never guess.

If the user is mid-conversation with `curate-em-workshop` and the curation is approved, the natural next move is this skill. You can offer it proactively: "Want me to publish this as a GitHub issue — short ticket or full PRD?"

## Workflow

Six phases. **Phase 0 picks the mode** and shapes everything downstream. **Phase 4 (preview + confirmation)** is a hard human checkpoint — do not call `gh issue create` until the user has explicitly approved the rendered body.

### Phase 0 — Pick the output mode

Before doing anything else, ask the user which mode to produce. Use `AskUserQuestion` with two options:

1. **Short dev ticket** — compact ticket with US, Gherkin acceptance criteria, technical hints, and a Definition of Done checklist. Best for small, well-scoped stories.
2. **Full PRD** — product-grade spec with context, goals, personas, success metrics, functional + non-functional requirements, dependencies, rollout plan, design links, plus an engineering checklist appendix. Best for net-new features or cross-team work.

If the user's initial phrasing strongly signals one mode ("create the PRD", "rédige le PRD" → PRD; "make the ticket", "fais le ticket court" → short ticket), confirm rather than ask blindly: "I read this as PRD mode — confirm or switch?"

Remember the choice for the rest of the run. The template, the metadata defaults, and the section gating in Phase 4 all depend on it.

### Phase 1 — Locate the source material

The source of truth is the Miro frame. Curated EM specs from `curate-em-workshop` are typically transient working artefacts that have been deleted or moved by the time this skill runs — don't look for them on disk, just work from the frame.

1. Parse the Miro URL — extract the board ID and (if present) the `moveToWidget=` frame ID.
2. Read the Miro frame via `mcp__miro__board_list_items` (item_type `sticky_note`). Capture for each sticky: content, fill colour, position (x, y, width, height), and id. This is the single source-of-truth read — don't re-fetch later in this phase.
3. Identify the yellow user story (or `light_yellow` — Miro returns either depending on the team's sticky styling). Slugify its goal portion into kebab-case (e.g. "Apply loyalty discount at checkout" → `apply-loyalty-discount-at-checkout`); this slug is used for the local issue-body file in Phase 4.
4. Cluster green examples under the nearest blue rule using spatial proximity (same approach as `curate-em-workshop`).
5. Detect **adjacent answer stickies** (see below) before classifying red stickies as open questions.
6. Translate non-English sticky content into clean English when constructing the issue body — but flag in the preview that translation happened, so the user can correct any term that has a canonical form in code.

In PRD mode, also read `PRODUCT.md`, `DESIGN.md`, and the top-level `README.md` of the repo if they exist. They feed the Context, Personas, and Non-functional requirements sections. Don't deep-dive — a single read each is enough to anchor terminology and avoid contradicting positioning. If they don't exist, carry on.

#### Detecting adjacent answer stickies

Teams routinely place a non-EM sticky (often violet, but any colour outside yellow/blue/green/red counts) next to a red question to record a proposed answer or decision the workshop reached. The standard EM palette doesn't model this — but missing it means treating already-discussed questions as if they were still open, which puts noise in the issue and erodes trust in the curation.

Detection rule, applied to each red sticky:

- Look for any sticky whose fill colour is **not** yellow / `light_yellow` / blue / `dark_blue` / green / `dark_green` / red.
- Pair it to the red sticky if it sits within roughly one sticky width (use the red sticky's `width` as the threshold) on the same row or directly adjacent on either side.
- When a pair is detected, treat the red sticky as a **proposed-answer question**: the workshop discussed it and parked a candidate disposition, but it hasn't been formally validated.

Render proposed-answer questions in the "Open questions to clarify" section with the candidate inline and flagged for confirmation: `*(proposed: {answer text} — confirm before starting)*`. Reds that have no adjacent answer sticky stay fully open.

In Phase 2, count proposed-answer questions as open for the purpose of the warning — they still warrant the user's decision — but mention in the prompt that {M} of {N} have proposed answers, so the user knows what they're choosing between.

### Phase 2 — Check for unresolved questions

Red stickies are the workshop's open questions. An issue is a "ready to develop" artefact; shipping it with unresolved questions means a developer will spin out as soon as they pick it up. In PRD mode the same rule applies — the PRD is the *product contract*, and leaving open questions in it dilutes its authority.

Detect open questions: every red sticky counts toward the "open" set, but separate them into two buckets using the adjacency detection from Phase 1:

- **Fully open** — no adjacent answer sticky; the team hasn't discussed a candidate.
- **Proposed answer** — adjacent non-EM sticky detected; the team parked a candidate but hasn't formally validated it.

If any open questions exist (in either bucket), **stop and ask the user** which path to take:

1. **Curate first** — back out and run `curate-em-workshop` (or a manual resolution session) on the frame. Recommended when the curation skill hasn't been run yet and many questions are fully open.
2. **Include as "Open questions to clarify"** — publish anyway, but surface the items as a dedicated section in the issue (with proposed answers inline when present) so the developer triggers a clarification round before starting. Use when the team consciously decided these questions are for the implementation phase.
3. **Promote proposed answers into the body, drop the rest** — for each proposed-answer question, treat the candidate as a decision and fold it into Technical hints / Dependencies / the relevant rule; ignore fully-open questions. Use when the team validated the candidates offline and you want a clean issue.
4. **Drop everything and publish clean** — the user takes full responsibility for the gap.

Wait for the user's pick. Default messaging (adapt counts and examples to the actual frame):

> {N} question(s) detected on the frame — {M} have a proposed answer, {N-M} are fully open:
>
> - "How do we do the linking?" *(proposed: Github App)*
> - "Refresh Git → background job?" *(proposed: Yes)*
> - "What happens to in-flight carts on price change?" *(fully open)*
>
> An issue should normally be free of open questions. How do you want to handle these?
> 1. Curate the frame first (recommended when many are fully open)
> 2. Include them in the issue as "Open questions to clarify" (with proposed answers inline)
> 3. Promote proposed answers into the body, drop the fully-open ones
> 4. Skip everything and publish clean

If no open questions exist, say one line ("No unresolved questions on this frame — good to go.") and continue.

### Phase 3 — Detect the target repository and metadata

The skill assumes the user is in the right working directory. Run `gh repo view --json nameWithOwner,defaultBranchRef -q .nameWithOwner` to confirm the target repo. If `gh` reports no repository (e.g. the cwd isn't a GitHub repo), tell the user and ask where the issue should go — never invent a repo.

Then ask three optional questions in **one** turn (use `AskUserQuestion` — multiSelect, low pressure):

- **Labels**: any labels to apply? List existing labels via `gh label list --limit 50` to give the user choices. In PRD mode, suggest `prd` / `product` / `spec` if such labels exist in the repo — don't create them automatically.
- **Assignees**: any assignee? Default: none.
- **Milestone**: milestone to attach? Default: none.

Keep all three optional — the issue is valid without them, and the user can always add them post-publication.

### Phase 4 — Build the body, preview, and wait for approval

Construct the issue body following the template for the chosen mode (see below). Save it to `tmp/github-issues/{slug}-{YYYY-MM-DD}.md` (create the directory if missing) so the user has a local copy regardless of whether publication succeeds.

In PRD mode, sections fed by inference (Success metrics, Non-functional requirements, and sometimes parts of Personas / Dependencies) **must be visibly marked** when the workshop didn't supply them. Use the suffix ` *(inferred — confirm)*` on the relevant bullets or paragraphs. Never silently invent product commitments.

Then show the **full rendered body** in the conversation along with the proposed title, target repo, and metadata. Use this exact closing line (translate to the workshop's language if it isn't English):

> Here is the issue I will open against `{owner/repo}` — title, body, labels, assignees, milestone. Read it through and tell me what to adjust. I won't call `gh issue create` until you've approved.

Wait for explicit approval ("ok", "publish", "go", "ship it", "publie", "envoie"). If the user asks for changes, iterate on the body and present it again. Repeat until approved.

### Phase 5 — Publish via `gh`

Once approved, call:

```bash
gh issue create \
  --repo {owner/repo} \
  --title "{title}" \
  --body-file tmp/github-issues/{slug}-{YYYY-MM-DD}.md \
  --label "{label1}" --label "{label2}" \
  --assignee "{user}" \
  --milestone "{milestone}"
```

Use `--body-file` rather than `--body "..."` — it preserves multi-line formatting and avoids quoting hell. Pass `--label`, `--assignee`, `--milestone` only when set; omit the flag entirely otherwise (passing an empty string makes `gh` reject the call).

Report the resulting issue URL to the user. If the call fails (auth, missing label, etc.), surface the exact error and propose a fix — never silently retry with mutated inputs.

## Issue body — Short ticket mode

Strip sticky ids from the rendered output — they belong in the Miro frame, not in the developer-facing ticket. Keep links so a developer can jump back to the workshop.

```markdown
## User story

As a **{persona}**,
I want **{capability}**,
so that **{outcome}**.

## Business value

{2–4 lines: why this matters now, what problem it solves, what changes for the user once shipped. Infer from the yellow sticky and the rules.}

## Acceptance criteria

{One Gherkin scenario per green example, grouped under their blue rule. Use the example's title as the scenario name. Derive Given/When/Then from the example's content. Stay close to the team's wording — translate to English but don't paraphrase aggressively. If an example is too vague to Gherkinize, mark the scenario "(needs sharpening)" rather than inventing precision.}

### Rule: {curated rule wording}

**Scenario: {example title}**
- **Given** {precondition}
- **When** {action}
- **Then** {expected outcome}

**Scenario: {next example title}**
- …

### Rule: {next curated rule wording}

…

## Out of scope

{Bullet list of what is explicitly NOT in this ticket. Lift any "Out of scope" notes the workshop captured. If none, infer 2–3 anti-scope bullets from adjacent rules or product context, and mark them "(inferred — confirm)".}

## Technical hints

{Best-effort. Optional if there is nothing useful to say.}

- **Likely affected areas**: {packages, endpoints, components — from light grep over key nouns in the story}
- **Considerations**: {perf, security, edge cases the workshop touched on}

## Links

- Example Mapping (Miro): {miro_frame_url}

## Open questions to clarify

{Only present if Phase 2 path 2 was chosen. List each red sticky as a short question in plain English. For questions with a proposed answer detected on the frame, append the candidate inline so the developer knows what was discussed.}

- {fully-open question}
- {proposed-answer question} *(proposed: {answer} — confirm before starting)*

## Definition of Done

- [ ] Implementation matches the acceptance criteria above
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing (where relevant)
- [ ] `nx lint` passes on edited projects
- [ ] `nx typecheck` / build passes on edited projects
- [ ] CHANGELOG updated under the Unreleased section
- [ ] End-user documentation updated under `apps/doc/` (only if user-facing)
- [ ] Feature flag wired in (only if the change is gated — name the flag, audience, and rollback plan)
- [ ] Amplitude events tracked (list each event name and the properties to capture; skip only if the change has no user-observable interaction)
```

The project uses **trunk-based development** — there is no PR-linking reminder. Work lands on `main` via small, self-contained commits referencing this issue.

## Issue body — PRD mode

The PRD is still a GitHub issue — same publication path, same file save location. What changes is the body. It is longer, structured around product concerns, and pushes the engineering checklist into an appendix.

Order matters: a reader should be able to stop after section 3 and already know *why* and *for whom*; stop after section 5 and know *what success looks like*; stop after section 6 and know *what exactly must work*; and only the implementer needs to keep reading through 7–11 and the appendix.

```markdown
# {Title in product language — see "Title" guidance below}

## 1. Context & problem

{3–6 lines. What problem are we solving, for whom, and why now? Lift from PRODUCT.md / README positioning where relevant. End on the current state vs. the desired state.}

## 2. Goals & non-goals

**Goals**
- {1–4 bullets describing the outcomes this PRD commits to. Outcomes, not features.}

**Non-goals**
- {1–4 bullets describing what is explicitly NOT part of this PRD. Lift "Out of scope" content the workshop captured when present. Mark inferred non-goals with *(inferred — confirm)*.}

## 3. Personas & use cases

{Primary persona pulled from the yellow sticky. Enrich with role/context from PRODUCT.md / DESIGN.md if applicable — domain term preserved (e.g. "Packmind admin", "tech lead"), never generalised to "user".}

- **{Persona name}** — {one line: who they are and in what situation they hit this story}
- **Frequency / volume** — {how often this scenario occurs; mark *(inferred — confirm)* if the workshop didn't say}
- **Secondary personas** — {optional, only if the workshop or context surfaced others}

## 4. User story

As a **{persona}**,
I want **{capability}**,
so that **{outcome}**.

## 5. Success metrics

{What we will measure to know this PRD delivered its goals. Propose Amplitude events (event name + key properties) and adoption / quality indicators that match the user story. Mark every metric or event the workshop didn't explicitly name with *(inferred — confirm)*. Skip the section entirely only if the change is genuinely invisible to users and operators.}

- **Activation**: {e.g. "% of {persona} who complete the new flow within 7 days of release" — *(inferred — confirm)*}
- **Adoption**: {weekly active users on the new flow, or equivalent}
- **Quality / health**: {error rate, latency p95, support tickets tagged X}
- **Amplitude events to track**:
  - `{event_name}` — properties: `{prop1}`, `{prop2}`
  - …

## 6. Functional requirements

{One Gherkin scenario per green example, grouped under their blue rule. Same logic as the short-ticket mode: use the example's title as the scenario name, stay close to the team's wording, mark vague examples "(needs sharpening)" rather than inventing precision. If a rule has no examples, render it with a placeholder noting "(no concrete example — needs one before merge)".}

### Rule: {curated rule wording}

**Scenario: {example title}**
- **Given** {precondition}
- **When** {action}
- **Then** {expected outcome}

### Rule: {next curated rule wording}

…

## 7. Non-functional requirements

{Performance, security, accessibility, i18n, observability constraints. Infer from the nature of the story and project context, and mark every inferred line with *(inferred — confirm)*.}

- **Performance**: {e.g. "operation completes under 500ms p95 for catalogues up to 10k items" — *(inferred — confirm)*}
- **Security & privacy**: {auth surface, sensitive data handling, audit trail}
- **Accessibility**: {WCAG level if UI-touching, keyboard navigation, screen reader behaviour}
- **Internationalisation**: {locales supported, RTL, currency/date formatting}
- **Observability**: {logs, metrics, traces to add; alerts to wire}

## 8. Dependencies & risks

**Dependencies**
- {Pre-requisites — other PRs/PRDs, infra changes, external services that must exist first}

**Risks & mitigations**
- {Risk — e.g. "third-party API rate limits during initial backfill"} → {mitigation, e.g. "throttled rollout, retry queue"}

## 9. Rollout plan

- **Feature flag**: {flag name, audience progression (internal → beta → GA), kill-switch behaviour, fallback when disabled}. Mark *(inferred — confirm)* if the workshop didn't decide.
- **Phasing**: {step-by-step rollout — which sub-feature ships first, what the dependency order is}
- **Rollback**: {how to revert safely — code revert, flag flip, data migration reversal}
- **Communication**: {who needs to know — internal channels, customer-facing release notes}

## 10. Design & references

- **Example Mapping (Miro)**: {miro_frame_url}
- **Designs / mockups**: {Figma links, screenshots — leave a placeholder "(none yet — to attach)" if absent rather than omitting the section}
- **Related PRDs / issues**: {optional}

## 11. Open questions to clarify

{Only present if Phase 2 path 2 was chosen. List each red sticky as a short question in plain English. For questions with a proposed answer detected on the frame, append the candidate inline so the reader knows what was discussed.}

- {fully-open question}
- {proposed-answer question} *(proposed: {answer} — confirm before starting)*

---

## Appendix — Engineering checklist

- [ ] Implementation matches the functional requirements (section 6)
- [ ] Non-functional requirements (section 7) verified — perf budget, a11y pass, observability wired
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing (where relevant)
- [ ] `nx lint` passes on edited projects
- [ ] `nx typecheck` / build passes on edited projects
- [ ] CHANGELOG updated under the Unreleased section
- [ ] End-user documentation updated under `apps/doc/` (only if user-facing)
- [ ] Feature flag wired in per section 9 (name, audience, rollback)
- [ ] Amplitude events from section 5 implemented and verified in staging
```

### How to derive each section

**Title (both modes)**: short, imperative, ≤70 chars. Take the *goal* part of the user story ("I want X") and rewrite it as an action — e.g. story "As a buyer, I want to apply a loyalty discount at checkout, so that…" becomes title "Apply loyalty discount at checkout". Avoid trailing periods. Don't prefix with `[FEATURE]` or `[PRD]` unless the repo's other issues do.

**User story block (both modes)**: take the yellow sticky. If the workshop ran in French ("En tant que / Je veux / Pour"), translate to "As a / I want / so that". Preserve the persona's domain term (e.g. "tech lead", "Packmind admin") — don't generalise to "user".

**Acceptance / functional requirements (both modes)**: one Gherkin scenario per green example. Group scenarios under their rule using a `### Rule: …` heading. Don't omit a rule that has no green examples — render it with a placeholder scenario noting "(no concrete example — needs one before merge)". Better to expose the gap than to silently drop the rule.

**Context & problem (PRD)**: anchor on PRODUCT.md / README positioning when available — quote terminology verbatim ("governance/curation layer", whatever the repo uses) rather than reinventing wording. Two-pass: (a) what's the problem in the workshop's terms, (b) where does this fit in the product's overall narrative. Keep it under ~6 lines — a PRD intro is a setup, not an essay.

**Goals & non-goals (PRD)**: goals are *outcomes*, not features ("buyers can discover loyalty value without prompting", not "add a banner on the cart"). Non-goals lift cleanly from any "Out of scope" content the workshop captured. If you have to infer a non-goal, mark it.

**Personas (PRD)**: anchor on the yellow sticky's persona, then add domain context only if PRODUCT.md or DESIGN.md gives you matter to enrich. Frequency / volume is almost always inferred — mark it.

**Success metrics (PRD)**: infer plausible metrics from the US and from any analytics conventions already present in the repo (e.g. `analytics/events.ts`, Amplitude wrappers, PRODUCT.md mention of north-star metrics). Always include at least one Amplitude event suggestion. Mark every inferred line. If the workshop explicitly named metrics, lift them as-is and don't mark.

**Non-functional requirements (PRD)**: infer from the *kind* of story — UI-touching → a11y + i18n; data-touching → privacy + audit; backend service → perf + observability. Mark every inferred line. If the workshop named NFRs, lift them as-is.

**Dependencies & risks (PRD)**: lift any "depends on" mentions the workshop captured; otherwise infer 1–2 plausible items and mark them. Risks should pair with mitigations — a risk without a mitigation is just FUD.

**Rollout plan (PRD)**: if the workshop named a feature flag, use it. Otherwise propose one (`flag.{slug}` is a reasonable default) and mark *(inferred — confirm)*. Always include rollback — even if it's "code revert + flag flip".

**Design & references (PRD)**: never omit the section, even if there's no Figma link yet. A `*(none yet — to attach)*` placeholder is more useful than silence, because it tells the reader "we know this is missing".

**Open questions**: only render when Phase 2 path 2 was chosen. Don't include the section as an empty placeholder otherwise. Same in both modes.

**Engineering checklist (PRD appendix) / Definition of Done (short ticket)**: keep exactly as in the template. If the user has additional repo-specific reminders they want by default, add them to the skill rather than baking them per-issue.

## Failure modes to watch for

- **Publishing with open questions**: never call `gh issue create` if the user didn't pick a path in Phase 2. The whole point of the warning is to keep half-baked stories out of the dev queue. Same rule in PRD mode — a PRD with open questions undermines its own authority.
- **Inventing acceptance criteria the workshop didn't cover**: if a rule has no examples, expose the gap in the issue ("needs one before merge") rather than fabricating a scenario. Inventing scenarios = inventing requirements.
- **Inventing product commitments**: in PRD mode, every section fed by inference (success metrics, NFRs, parts of personas / dependencies / rollout) must be flagged `*(inferred — confirm)*`. A PRD reader will treat unmarked content as agreed — silent invention is the worst failure mode of this mode.
- **Skipping the preview**: Phase 4 is non-negotiable. Even when the user says "just publish it" upfront, render the body once and wait for approval. The cost of a wrong issue (developer confusion, public artefact, edit history) far exceeds the cost of one extra turn.
- **Skipping Phase 0 (mode pick)**: don't default silently to short-ticket mode (the legacy behaviour). Ask, or confirm an inferred choice. A misread mode produces either a too-thin product spec or a bloated dev ticket.
- **Posting non-English content**: even when the workshop is in French/Spanish/etc., the issue body is in English. Translate sticky content; flag any term you weren't sure how to translate so the user can correct it.
- **Hard-coding the repo**: the target repo comes from `gh repo view` in the cwd. Don't assume `packmind/packmind` or any specific repo — the skill should work for any project the user runs it in.
- **Quoting sticky ids in the issue**: `s001`, `s010` etc. are Miro-internal traceability artefacts. They have no place in the issue, in either mode — they make the body noisier and have no meaning to the reader. Strip them.
- **Mixing modes in one issue**: don't append PRD sections to a short ticket "just in case", or strip PRD sections to make a ticket "lighter". The two templates are coherent wholes; cherry-picking sections produces an issue that satisfies neither audience.

## Iterating on an existing issue

If the user comes back saying "the issue I opened needs an update" with the same Miro frame:

- Look up the existing issue: ask the user for the number, or search by title via `gh issue list --search "{title}"`.
- Re-confirm the mode (Phase 0) — sometimes a short ticket has graduated to PRD as scope grew.
- Re-run Phases 1–3 to rebuild the body from the (possibly updated) frame.
- Show the diff between the existing issue's body and the new body in the preview.
- On approval, call `gh issue edit {number} --body-file …` rather than creating a new issue.