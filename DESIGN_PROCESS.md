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

## Findings still to be made

The steps after the first, as planned (RELEASE_PLAN.md, Phase 0):
domain stories, a light event storming, example mapping for the rules,
glossary and ADRs (the public `domain-modeling` skill), Ash domains
with resources, actions and policies, the derived entity diagram, and
the crossing with the shelf. Each gets its entry here when it has been
run once: its terms, its deliverable's shape, its example, and what
surprised.
