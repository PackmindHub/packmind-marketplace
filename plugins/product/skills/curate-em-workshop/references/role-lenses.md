# Role lenses for Pass E

Pass E of the curation runs the EM analysis through different role mindsets to surface what the workshop didn't say. Each lens is defined by its **epistemic angle** — the kind of question that role's brain asks naturally — not by a personality stereotype.

A good lens finding cites at least one sticky id. Floating "best practice" advice ("you should think about scalability") is not a finding; it's noise.

## Default lenses (activated unless the user removes them)

These three are activated by default in any workshop. Confirm or adjust them in Phase 2.

### PM lens — value, scope, persona, outcome

Questions a PM's brain asks naturally:

- Is the persona unique and unambiguous? If a sticky says "user", does it mean end-user, admin, or both?
- Does each rule map to a **user-observable behaviour**, or to an internal implementation detail?
- Is the business outcome measurable? "Conversion goes up" — by how much? Measured how?
- Is the scope (in / out of this story) explicit? What's deliberately deferred?
- Is there a path in the examples that would degrade trust, conversion, or NPS — even if technically correct?
- Does any rule conflict with the documented product strategy (PRODUCT.md)?

> **Overlap with Pass G (INVEST).** The PM lens looks at value at the **example and rule level** — is each rule user-observable, is each example revealing of real value. Pass G's `Valuable` criterion looks at the **story as a whole** — does shipping this US deliver something a user can perceive. They cohabit without duplicating: a PM lens finding may flag "R3 is implementation-detail, not user-observable" while INVEST flags "the story as a whole only benefits an internal pipeline". When in doubt, place rule-level concerns in §7 PM lens and story-level concerns in §1 INVEST.

### Dev lens — implementability, edges, contracts

Questions a Dev's brain asks naturally:

- Is each rule deterministic and testable? "Should feel fast" is not a rule a dev can ship.
- What happens on errors, retries, partial failures, concurrent writes?
- What's the data model implied by these rules? Are entities and their relationships clear?
- What hidden dependencies exist on other systems (auth, payment, third-party APIs)?
- Do rules conflict at runtime under specific input combinations?
- Is **idempotency** defined where it matters (publish-twice, re-submit, retry)?

### QA lens — coverage, boundaries, regression

Questions a QA's brain asks naturally:

- **Equivalence classes**: zero / one / many / max. Which are covered by examples, which aren't?
- **Error paths**: timeout, denial, partial failure, network split. Covered?
- **State combinations**: (logged in × first time × payment failed) and similar product matrices. Which combinations have an example, which don't?
- What's the **regression surface**? Which existing features could break if these rules ship?
- Are non-functional concerns (latency, throughput, race conditions) addressed by any example?

⚠ **The QA lens stays active even if no QA was in the workshop — that's precisely when it brings the most value.** Tag its findings with `⚠ (no QA in team — would otherwise be missed)`.

## Optional lenses (activate when the workshop's scope calls for them)

The user declares these in Phase 2 by adding them to the lens list.

### Design lens — user flow, empty states, accessibility

- What's the user flow assumed by these rules? Are there steps the team didn't draw?
- Empty / loading / error states for each rule's UI?
- Accessibility (keyboard nav, screen reader, contrast) implied but never said?

### Data lens — tracking, segmentation, KPIs

- What user actions implied by these rules should be tracked?
- Are there segmentation variants (free vs paid, region, locale) that affect the rules?
- Which KPI moves if these rules ship correctly? Wrong?

### SRE lens — operability, SLA, observability

- What SLA is implied by these rules?
- What alerts would fire if these rules break in production?
- Are there scale limits ("up to N users") that aren't stated?

## How to role-play without caricature

The point of Pass E is to bring missing perspectives. The failure mode is to bring **stereotypes** — a cartoonish PM "obsessed with ROI", a cartoonish QA "looking for edge cases everywhere". Stereotypes produce shallow findings that the team will (rightly) ignore.

- **Lead with the lens's epistemic angle**, not its personality. A PM doesn't "care about ROI"; a PM **asks whether the outcome is measurable**. The angle generates substantive questions; the personality generates clichés.
- **Ground every finding in a sticky id.** "Boundary case unclear" is not a finding; "R2 (`s020`) — boundary on package size unclear, no example covers max size" is.
- **Cap at 5 findings per lens, hard.** If you have more, you're listing concerns rather than ranking them. Pick the top 5 by potential impact on the next workshop.
- **Don't duplicate §3–5.** If a concern is already in Orphans / Duplicates / Questions, skip it. The lens earns its keep by adding new information, not by repackaging the obvious.
- **Findings are candidates, not decisions.** Frame them as "the team may want to consider …", not "the team must …". The skill is a collaborator, not a stakeholder.
