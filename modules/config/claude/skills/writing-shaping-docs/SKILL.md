---
name: writing-shaping-docs
description: Write up an already-shaped project as a shaping document (e.g. a Linear project description) — the write-up craft, not the shaping process.
disable-model-invocation: true
---

The shaping is done: the exploration happened, the decisions are made, wayfinder tickets exist. This skill governs the **write-up** — packaging what the shapers know so a **cold reader** reaches the same a-ha they had. The document is judged by whether the cold reader gets there, never by template completeness.

## The two readers

Every paragraph serves two readers at once, and both are cold — they weren't in the shaping room, haven't read the discovery, don't know the roadmap:

1. **The stakeholder** — smart, fluent in the business, technically literate but indifferent to implementation. Reads for problem, why, and solution.
2. **The dev** — strong technically, short on business context. Needs the why to understand the work, then the solution and its boundaries.

Write for whichever of the two knows less about the sentence you're writing. The stakeholder gates the main body; the dev gates the annex.

**Cold-reader rules** (each one is a real failure a reviewer flagged — see [EXAMPLES.md](EXAMPLES.md)):

- Expand every acronym and domain term at first use.
- A sentence that leans on prior work must carry the fact, not the pointer. "This supersedes the discovery statement that X" is unreadable cold; state the decision and its consequence, in place.
- Future plans get mentioned only when the sentence explains itself without the roadmap. "These states are the hook later enforcement hangs on" assumes the reader knows the later epics — either give the one-line context or cut.
- Provenance is noise. How the doc, prototype, or decision came to be ("a carbon copy of...", "this was originally in the ticket that...") matters to the authors, not the readers.

## Altitude — what goes where

The document is the top of a stack, and each layer has an owner:

| Layer | Carries | Reader |
|---|---|---|
| Main body | Problem → why → solution, readable end-to-end | Both, led by the stakeholder |
| Boundaries | Out of scope, open questions | Both |
| Annex | **Overview** of make-or-break technicals | The dev |
| Wayfinder tickets | Full depth, micro-decisions, sequencing | The dev who picks up the ticket |

- The annex exists only for material the project stands or falls on (a data model that is make-or-break, a migration that constrains everything). It stays an overview — the entities, the relations, the one or two load-bearing decisions — and links to the tickets that carry the dives. If the main body depends on the annex to be understood, the body is broken.
- Sequencing and dependencies live in the ticket graph. Mention a dependency in the doc only when it shaped the solution itself.
- Micro-decisions ("field X deferred", a naming call) live in the ticket that owns them. In the doc they are pure noise.

An example skeleton — an example, not a template; shape sections to the project:

> Problem / Why now / The solution / Out of scope / Still to settle / Annex: *the make-or-break thing*, overview

## Section craft

- **Problem** — open with one specific story that shows why the status quo fails (the customer who did the absurd workaround), then generalize minimally. Numbers only if already quantified; a shaping doc re-litigates nothing.
- **Why** — connect to the company priority and the prize. Settle "why now" and "why this is the dependency" in a few sentences each.
- **Solution** — outcome-centered: narrate what the user does and what they get, in workflow order. Annotated screenshots or prototype captures carry it. Mechanics and data shapes stay out of this section entirely.
- **Out of scope** — explicit exclusions that tell the team where to stop, each with its one-line reason.
- **Still to settle** — genuinely open questions, each with where it gets decided.
- **Annex** — the overview described above.

## Prose

- Short declarative sentences, one idea each. A sentence packing three facts behind em-dashes reads as clever to the author and opaque to everyone else.
- When the content is a set of facts (states, field meanings, rules), write bullets, not woven prose. Prose implies flow; a list implies a list.
- Every sentence must matter to at least one of the two readers. A sentence that matters to neither — however true — gets cut, not compressed.
- Use the project's ubiquitous language, defined at first use, then never varied for elegance.
- Bold marks the sentence a skimmer must not miss — at most one per paragraph.

## The cold-reader pass

After drafting, reread the whole document twice — once as each reader — and fix what fails. Done when:

- every acronym and term of art is defined at its first occurrence;
- every sentence survives with zero knowledge of the discovery, prior tickets, or future epics;
- the main body reads end-to-end with the annex deleted;
- every technical detail sits at its altitude — body, annex overview, or ticket — with none orphaned in between.

For before→after pairs of the failures these rules exist to prevent, read [EXAMPLES.md](EXAMPLES.md) while drafting or reviewing.
