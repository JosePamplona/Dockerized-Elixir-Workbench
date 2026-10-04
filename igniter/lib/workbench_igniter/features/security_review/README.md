# Cartridge: security_review

A review of the project against the OWASP Top 10, kept in the
repository, with the checks a machine can run — **pending**:
identified, not designed yet.

* **Task**: `mix workbench.install.security_review` (does not exist yet)

## Description

The [OWASP Top 10](https://owasp.org/www-project-top-ten/) is the list
a client, an auditor or a questionnaire asks an application to answer
for. Answering it is a review: for each risk, whether it applies, where
the code deals with it, and what is still open. This box makes that
review a file of the project instead of an afternoon repeated from
memory, and shortens it with what can be automated.

The manifest is registered so the catalog shows the box as pending,
but nothing is designed and the installer is not written: nothing can
insert it yet.

## What it is expected to bring

Not decided — this is where the design starts from, and its
`DESIGN.md` settles each line:

* **The review, in the repository**: one document with a section per
  risk of the Top 10's current edition, each opened with what Phoenix
  already does about it and the questions only the project can answer.
  Which edition is current is read off OWASP on the day the design is
  written, and the document says which one it follows.
* **The checks that run**: static analysis of the Phoenix code
  ([Sobelow](https://hexdocs.pm/sobelow)) and the known
  vulnerabilities and retired releases among the dependencies
  (`mix deps.audit` from [mix_audit](https://hexdocs.pm/mix_audit),
  `mix hex.audit`), behind one Mix task, each finding filed under the
  risk it belongs to.
* **Settings that close a risk by configuration**, where there is one
  to offer, each as an option the reader chooses and never as a
  default they did not ask for.

Open, for the design: which risks a tool can speak to and which stay a
person's to answer; where the task runs (by hand, before a commit, in
CI); and how a finding that was reviewed and accepted is kept from
coming back every run.

When it is built, fill this directory in like any other cartridge (see
the checklist in the package README): `DESIGN.md`, `task.ex`, its
templates under `priv/features/security_review/`, its test and this
README.

## Contents

| File | Role |
| --- | --- |
| `security_review.ex` | Manifest only (`pending?/0` returns `true`) |
| `NEED.md` | The need it answers |

Cartridge test: none until built.
