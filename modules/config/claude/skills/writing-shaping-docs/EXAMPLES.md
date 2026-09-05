# Before → after: real failures from a reviewed shaping doc

Each pair below is genericized from a real shaping document and the reviewer comments it drew. The "before" versions were all written by an agent; every one earned a comment.

## 1. Undefined acronym

**Before:** "pushing a SoR quote out the door is cumbersome"

**Reviewer:** *"What is a SoR quote?"* — asked by a stakeholder, on the second paragraph.

**After:** first use reads "a client's contractual Schedule of Rates (SoR)"; every later use is bare "SoR".

## 2. Pointer instead of fact

**Before:** "Price-list maintenance at v1 is a CLI a dev runs — this supersedes the discovery statement that a self-service maintenance path is non-optional."

**Reviewer:** *"As a first-time reader with no clue about the discovery statement, I don't understand this."*

**After:** "Price-list maintenance at v1 is a CLI a dev runs. Until an authoring UI ships (a follow-up project), a reprice needs an engineer — a risk we accept knowingly." The decision and its consequence are on the page; the discovery document is not.

## 3. Future-roadmap hook

**Before:** "…those states fall out of the decision the CSM already made, and they are the hook that later rate enforcement and evidence gating hang on."

**Reviewer:** *"Completely non-understandable by people that don't have the context / don't know the future epics."*

**After:** cut the clause. The states justify themselves in the present; if the forward link truly matters, it gets its own self-contained sentence ("a later project can enforce rates because every line records where its price came from").

## 4. Provenance noise

**Before:** "Interactive prototype — a carbon copy of the repair-request page with the picker layered in."

**Reviewer:** *"Why say that? Sure it was part of the ticket that originated it, but why would a first-time reader of the shaping care?"*

**After:** "Interactive prototype — the repair-request page with the picker layered in." What the artifact *is*, not how it was produced.

## 5. Clever prose where bullets belong

**Before:** "`RequestItem.price` means *cost to us*. `RequestItem.sellPrice` is what we charge. Confusing, pre-existing; `sellPrice` becomes `@deprecated` with this project, since the picker's action is creating a `QuoteLine` and never writes it."

**Reviewer:** *"What's confusing is this prose."* The reviewer rewrote it themselves:

**After:**
> - `RequestItem.price` should be renamed (not now) `RequestItem.cost`
> - `RequestItem.sellPrice` (a hack from before quote lines existed in our backend) is deprecated. We never write to it again.

Facts in a list read as facts. The same facts woven into prose read as a riddle.

## 6. Micro-decision in the doc

**Before:** "`sortOrder` deferred."

**Reviewer:** *"Useless."*

**After:** deleted. The deferral lives in the ticket that owns the field.

## 7. Insider shorthand

**Before:** "Computed-vs-recorded is the top-level division; the long tail (indexation formulas, caps, allowances, billing trigger) lives as text in `notes`."

**Reviewer:** *"Absolutely not understandable without context."* Twice, on two adjacent sentences.

**After:** either spell it out — "Lines the system can price (rates, coefficients) are structured rows; everything it only needs to remember (indexation formulas, caps, allowances) is prose in a `notes` field" — or leave it to the ticket where the division is defined.

## 8. The deep dive parked mid-document

**Before:** a full data-model section (five tables, aggregate design, migration plan, FK semantics) sat directly after the solution section, at equal rank with it.

**Reviewer:** *"This whole paragraph might be way too verbose. This should be an 'overview' and deep dives happen in each wayfinder ticket."* And: *"I moved it manually — it should be treated as an annex more than anything else."*

**After:** the main body ends at boundaries and open questions. The data model — make-or-break for this project, which is the only reason it appears at all — becomes an annex holding the entities, their relations, and the two load-bearing decisions, with each subsection linking to the wayfinder ticket that carries the full dive.

## 9. Solution section that describes the system, not the outcome

**Before:** the solution section led with field-authoring semantics, FK cardinalities, and Salesforce viability notes ("`QuoteLine` fields are authored at pick time…", "free-floating quote lines are viable in Salesforce…").

**Reviewer:** *"Way too verbose, way not solution/outcome centered."* The reviewer moved every one of those paragraphs out of the solution into the data-model annex.

**After:** the solution narrates the user's workflow: "The CSM opens the request as today, and for every item makes exactly one decision: take the contracted rate, price it off-list, or leave it out of the quote. No PDF to hunt down, no re-typing a price we already agreed with the client." The tables that make it work are the annex's business.
