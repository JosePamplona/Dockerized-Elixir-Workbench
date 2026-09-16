# The design process: a draft

What is learned while designing the reference project (RELEASE_PLAN.md,
Phase 0), written down as it happens. It is the raw material of the
workbench's own design skill, which is written **after** the process
has been run once, from what actually happened, and lives in
`.claude/skills/` beside cartridge-covers. This file retires when that
skill exists; the CHANGELOG stays the record.

Entries are dated. Each says what was found, why it matters, and what
the skill should do about it. Findings about the *process* are marked
**(process)**; findings about the *reference project* are marked
**(project)**.

## 2026-09-15: a step opens with its terms and the shape of its deliverable (process)

**What happened.** The process asked "choose the domain" and the author
could not tell what was being asked: the word had been used in three
senses without saying which. The answer that unblocked it was not a
domain, it was a definition, and a table showing what a candidate
looks like.

**The finding.** A step of a creative process cannot start on its
verb alone. It opens with three things, before any creative work:

1. **The terms**, defined, and told apart from their neighbours when
   the same word means several things.
2. **The shape of the deliverable**: what is handed in at the end of
   the step, as a structure (a table, a list of sentences, a diagram
   type), so the author knows what done looks like.
3. **One filled example**, so the shape is read off a case and not off
   a description of it.

This is the same rule the cartridges' README applies to a DESIGN paper
(the reference paper is what makes the criteria readable) and the
cover guide applies to a cover (the prompt names what the box shows,
not how to draw). The skill's every step starts this way.

**The terms, for the first step.** Three senses of *domain*:

- **Domain (DDD)**: the sphere of activity the software is about, on
  the problem side, independent of any code. "A repair shop" is one.
  It decomposes into *subdomains*: core (what sets the business
  apart), supporting (needed, not distinctive), generic (the same in
  any business: accounts, billing).
- **Bounded context**: on the solution side, the boundary within
  which one model and its vocabulary are consistent. A subdomain is
  modelled by one or more contexts, ideally one. Contexts do not make
  up the domain; they model it. The same word ("order") meaning two
  things is the sign of two contexts.
- **Ash domain** (`Ash.Domain`): a module grouping resources and
  exposing their actions, which Ash's own docs compare to a Phoenix
  context. It is a bounded context, not a DDD domain.
- **Domain code**, in the cartridge script: what the project models
  for itself, what no cartridge installs.

**The deliverable of the first step: a candidate business**, one row
per candidate, with the columns the script needs. Every column must
have a name in the business's own words, and the core rule must be a
rule someone would argue about:

| Business | Tenant | Members and roles | What is worked on | Core rule |
| --- | --- | --- | --- | --- |
| Repair shop | Shop | Owner, mechanic | Work orders with states, comments | An order does not close with parts pending |
| Veterinary clinic | Clinic | Owner, vet, front desk | Patients and consultations | Only the assigned vet closes a consultation |
| Coworking | Space | Manager, member | Rooms and bookings | Two bookings do not overlap in a room |
| Academy | Academy | Head, teacher, student | Groups and hand-ins | A student sees only their group |
| Catering | Kitchen | Chef, cook | Orders per event | A confirmed order does not move its date |

A candidate without tenants, without roles, or without something that
changes state does not qualify: half the script's steps would have no
step to attach to.

**What the skill does about it.** Its first step is not "choose a
domain". It is "say what a domain is, show the table, fill five rows,
pick one". And every later step is written the same way: terms, shape,
example, then the work.

## 2026-09-15: the audience picks the business (process, project)

**What happened.** The first candidates table was filled from the
author's side: businesses that fit the shape. The author then said who
the portfolio is for: the medium and large industry installed around
Querétaro, Mexico (aerospace, auto parts, appliances, food, logistics),
and that the course's task manager appealed because a plant would
recognise it. A candidate that fits the shape but speaks to nobody the
author wants to reach is the wrong candidate.

**The finding.** The candidates table gets a column before the core
rule: **who recognises it**, the reader the demo has to speak to, in
their own words. The seed data of the demo (Phase 6) is written in that
reader's vocabulary too: lines, machines, shifts, not "project A".

**The industrial candidates.** Same shape as the course (tenant,
members and roles, invitations, a live board, comments, activity, plan
limits, billing), each a thing a plant already runs, often on paper or
a spreadsheet:

| Business | Tenant | Members and roles | What is worked on | Who recognises it | Core rule |
| --- | --- | --- | --- | --- | --- |
| Plant maintenance (a light CMMS) | Plant | Maintenance head, technician, operator who reports | Work orders on assets, by line, with states | Every plant; maintenance is universal | An order on a critical asset does not close without its checklist and parts |
| Quality: non-conformances and corrective actions | Plant | Quality, production, and the supplier as an outside member | Non-conformance reports through containment, root cause, action, verification | Auto parts and aerospace (IATF 16949, AS9100 vocabulary) | A report does not close without a verified corrective action |
| Permit to work and contractor safety | Plant | Safety, supervisor, contractor | Work permits (hot work, heights, lockout) with signatures and expiry | Any plant with contractors on site | A permit is not active without every signature, and expires |
| Shift handover | Plant | Supervisor, operator | Open issues per line, handed from shift to shift | Production floors | An issue open at shift end is handed over or escalated |
| Dock scheduling | Warehouse | Logistics, carrier as an outside member | Truck appointments on docks | Logistics and distribution centres | Two appointments do not overlap on a dock |

Two of them (quality, docks) have an **outside member**, someone who
belongs to several tenants at once: a richer multi-tenancy than the
course's, and a policy worth reading. Maintenance is the most
recognisable and the closest to the course's task manager (task → work
order, project → asset or line); quality is the most distinctive and
the most demanding to model.

**What the skill does about it.** Step one asks who the reader is
before it asks for candidates, and the table carries them.

## 2026-09-15: the business is plant maintenance, and its vocabulary has an owner (project, process)

**Decided.** The reference project is **plant maintenance**: a light
CMMS. The author's reason: it is the course's task manager in a
plant's words, the one every plant around Querétaro recognises.

**The term.** CMMS, *Computerized Maintenance Management System*: the
software category a plant uses to run maintenance. Its objects are the
assets (machines, lines, equipment), the work orders on them,
preventive maintenance scheduled by calendar or by hours of use, the
spare parts in stock, and each asset's history. The commercial products
of the category (Fiix, UpKeep, MaintainX) are the names a plant manager
already knows. A *light* CMMS keeps assets, work orders and
preventives, and leaves out stock and purchasing.

**The finding.** When the business belongs to an established software
category, the vocabulary is **taken from the category, not invented**:
work order, asset, preventive, downtime, criticality, technician. The
glossary step (the `domain-modeling` skill's) starts from the
category's terms and records where the project departs from them. The
acronym is spelled out the first time it appears, everywhere, as the
first finding asks: the author had to ask what CMMS meant.

**What is out**, so it is not re-argued: spare parts stock and
purchasing (the supplier as an outside member is a later chapter, when
an order's parts are requested from one), and predictive maintenance
off sensor data.

## 2026-09-15: the stories speak the business's language, which is not the repository's (process)

**What happened.** The stories were to be written and the first
question was which language. The repository is English; the plant
speaks Spanish; the reader of the portfolio reads English.

**The finding.** A paper written in the business's voice (the stories,
the glossary) is in the business's language, because a story that
translates the plant's words is already a model, and a wrong one. The
code, its names and its documentation are in the repository's
language, and the glossary is the bridge: every term carries its
English name beside it. This is a decision the reference project will
carry (its `reference/README.md` says it); whether it deserves an ADR
is decided when the project exists.

**The step's brief**, as run: a domain story tells one concrete
situation with its actors, work objects and activities, in the
business's words; it says what happens on the floor today, not what
the system does. Six to eight, each a title and one paragraph in the
second person, no list, the NEED files' register; together they cover
the whole cycle. The example given was the first story, the press on
line 3. Eight were drafted for the author's correction, and the
glossary was started from them at the same time, marked as proposed:
the review of the stories is the review of the terms.

## 2026-09-15: the stories' review is four questions, and the storming finds the actors that are not people (process)

**What happened.** The author reviewed the stories by answering four
questions the stories had left open (who opens an order, whether roles
accumulate, whether every asset has a line, who confirms a closing),
not by editing the prose. Each answer resolved a term: *reporte*
apart from *paro*, *servicios*, the three-step *cierre* with its
*visto bueno*. The storming then surfaced two actors no story named,
because they are not people: **time**, which opens preventives, and
**billing**, which says whether the plant paid; and two objects no
story named: the **reading** of hours of use a preventive by hours
depends on, and the **finding**, what a technician meets that was not
the breakdown.

**The finding.** A story review is best driven by the questions the
stories leave open, asked as concrete scenarios, one at a time; the
author answers from what they know of the floor, and each answer lands
in the glossary at once. And the storming's yield is less the events
than the **hot spots**: what had to be assumed to write an event down.
Those go back to the author as numbered questions, the same way.

**The step's brief**, as run: an event is something that happened, in
the past tense, in the business's words; each has the command that
caused it, who gave it, and what it is about. Events in the order of
the cycle, grouped by stage; then the hot spots, the resources that
emerge and the contexts they hint at. One page (`reference/EVENTOS.md`).

## 2026-09-15: what the author does not know, the category answers, and it is written as an assumption (process)

**What happened.** Asked how often a meter reading is taken, the author
said they did not know and asked what the industry does. The answer
came from the category's practice (the operator at shift end, the
products accepting readings at any time and estimating the next due
date) and was recorded as such, with its source named as "practice of
the category", beside the decisions the author made themselves.

**The finding.** A design question the author cannot answer from the
floor is answered from the category's practice and its products, and
recorded as an assumption with its source, never as the author's
decision. The glossary and the hot spots say which is which.

Two of the author's proposals were argued against and changed with the
reason written down (the time an asset runs again, the closing flow),
which is the review loop the covers use: one take, the critique, the
fix, and the record. A third (the same closing for every order) was
taken and its consequence settled at once (no reporter, no
confirmation).

**The step's brief for the rules**, as run: a rule is written as the
maintenance head would say it, with the examples that show it and the
ones that test it, and the questions it leaves; each example is a
future policy test, each question a decision. Ten rules
(`reference/REGLAS.md`), with recommendations where the author will be
asked.

## 2026-09-15: an either/or question can hide a both, and the rules step ends in ADRs (process)

**What happened.** Asked whether two overlapping breakdowns on a line
add up or count once, the author answered that they are two
independent measures, one per asset and one per line, both read off
the same breakdowns. Neither option offered was the answer; the
question's shape had hidden it. The rules step closed with every
question decided but two details (the grace period's length and the
lockout's form), and four decisions met the ADR bar of the
`domain-modeling` skill (hard to reverse, surprising in the code, a
real trade-off): the language split, the three-step closing for every
order, closed orders that never change or reopen, and the two downtime
measures that are never stored. They are in `reference/docs/adr/`.

**The finding.** When a question is put as a choice between two
options, add the third: "or is it both, or neither?" The author knows
the floor; the options are the designer's. And the rules step has a
natural end: the glossary is confirmed by the rules that use it, and
the ADRs are the decisions the rules exposed that a future reader of
the code would try to "fix".

## 2026-09-15: a project's paper lives with the project, not with the workbench (process)

**What happened.** The plan said the entity diagram would be drawn in
`assets/diagrams/`, where the cartridges' figures are made. The author
asked why it would not go in `reference/` with the rest of the
project's papers. It should: `assets/diagrams/` is the workbench's own,
and the reference project's papers move with the project when it gets
a repository. Only the way of drawing (the diagram-design skill) is
shared.

**The finding.** Every artefact of the design has an owner, the
project or the workbench, and lives with its owner. The skill says so
of each deliverable, and the reference project's directory is the
test: if it moves with the project, it is the project's.

## 2026-09-15: the diagram is derived, drawn with the house's script, and checked by looking (process)

**What happened.** The entity diagram was drawn last, off `DOMAINS.md`,
as Ash asks (model the actions, derive the rest). The skill's ER budget
is eight entities and the model has thirteen, so it became two figures
along the domains' own seam: the plant's model, and the plant with its
people and what it pays. The drawing reused the workbench's diagram
script for the skin and the geometry helpers, from a script of the
project's own in `reference/diagrams/`. The skill's self-check passed
on both pages; a screenshot then showed three things the check cannot
see — a field name running into its type, a cardinality chip on a box
edge — fixed in one pass.

**The finding.** The step's brief: an ER figure shows entities, their
fields and the cardinality at each end, nothing of behaviour; it is
derived from the domains paper, never drawn first; over the budget, it
splits along a domain boundary. The deliverable is the `.html` source
and the `.svg` a paper embeds, both from a script. And a self-check is
not a look: the taste gate ends with a screenshot read by eye.

## 2026-09-15: the crossing sorts the shelf into lines, and the design ends (process)

**What happened.** The last step put every step of the reference
project against the shelf, in build order: twenty-four rows, each with
its need in the developer's words, what answers it (a box with its
options, domain code, or missing) and the chapter it becomes. The Ash
box answered five rows by itself, through its options. Eight boxes
went unused, and not one of them was wrong: each belongs to the
Phoenix line, the project without Ash. What the shelf lacks is not a
box but a word: which line a box is on. Three boxes are missing (ci,
deploy, stripe finished), one is a decision (oban or ash_oban), and
one the plan had named (agents) mostly dissolved into an ash option.
Two things surfaced that no earlier step had: seed data as a chapter
of its own, and the UI's language, which the language ADR had not
said.

**The finding.** The crossing's brief: a step is what the project
does to exist, in build order; its need is written as a NEED file
would; what answers it is named with its options, or is *domain code*,
which is as much an answer as a box; the chapter comes last. Its
yield is three lists: what the shelf has that the project does not
use (and why, which is never "delete"), what the shelf lacks, and what
the workbench must not try to install. And the process has a natural
end: when the last step produces decisions for the author rather than
new steps.

## 2026-09-16: the drawer questions — what no story names and every interface has (process)

**What happened.** The crossing surfaced the interface's language,
which no story, event, rule or domain had named: the author and the
plant both speak Spanish, so the question hid. The author then asked
whether the skill should always ask about translation, i18n and l10n
whenever there is a visual interface.

**The finding.** Yes, and wider than translation. There is a small set
of decisions every project with an interface has to make and no story
ever names, because the story's teller takes them for granted: the
language of the interface, the time zone the days are counted in (a
shift crosses midnight; downtime is counted in the plant's day), the
currency, the formats of dates, hours and numbers, the units. They
are *drawer questions*: the skill keeps them in a drawer and asks them
at the step where an interface or a number first appears — for this
project, at the crossing's row 14 — and records each answer as a
decision, with an ADR when it meets the bar (the language did:
ADR-0005). The drawer is short, and it is not a checklist for the
author to fill: each question is asked once, in the author's
situation, with the consequence that makes it matter.

## 2026-09-16: a drawer question reopens the design, and the glossary is the door (process)

**What happened.** The drawer's three questions (the plant's time
zone, the plans' currency, the formats) could not be answered as
notes: each touches papers already closed. A time zone per plant is a
term in the glossary, an attribute of `Plant` in the domains and the
diagram, and a clause in R4 (downtime counted in the plant's day). The
author asked whether the context's design should be reopened with the
agent to settle them, and the discovery recorded.

**The finding.** The process is not a line but a loop with the
glossary as its door: a late question re-enters through the term it
adds or changes, and the change walks outward to every paper that
uses the term — rules, domains, diagram, ADRs — in that order, each
one edited in place, none rewritten. The `domain-modeling` skill's
rule of updating the glossary the moment a term resolves is what makes
the loop cheap. The skill's last step therefore says: after the
crossing, open the drawer; each answer goes in through the glossary.
Run once (2026-09-16): the three answers — a time zone per plant, plans
in Mexican pesos, day-month-year and the 24-hour clock — entered as one
term (*zona horaria*) and two clauses, walked to R4, `Plant` and `Plan`
in the domains, ADR-0005's consequences and the Accounts diagram, and
touched nothing else.

## Findings still to be made

Done and recorded above: the candidates, the stories, the storming,
the rules, the glossary and the ADRs. The Ash domains, the derived entity
diagrams and the crossing with the shelf are done: the design has been
run once, end to end. What is left is the skill, written from these
entries. Each gets its entry here when it has been
run once: its terms, its deliverable's shape, its example, and what
surprised.
