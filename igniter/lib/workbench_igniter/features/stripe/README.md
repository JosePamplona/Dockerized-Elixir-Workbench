# Cartridge: stripe

Stripe payments and subscriptions — **pending**, not ported yet.

* **Task**: `mix workbench.install.stripe` (does not exist yet)
* **Enabled by**: `--stripe` on `workbench.setup` (config.conf: `STRIPE`)
* **Implies**: `--auth0` (subscriptions belong to users)

## Description

Payments and subscriptions with Stripe. The manifest is registered so
`workbench.setup` knows the flag, applies the implied `--auth0` and
documents the feature in the generated README.md and .env, but the
installer is not ported: setup emits a notice instead of composing it.

When ported, fill this directory in like any other cartridge (see the
checklist in the package README): `task.ex`, `templates/`, its test and
this README.

## Contents

| File | Role |
| --- | --- |
| `stripe.ex` | Manifest only (`pending?/0` returns `true`) |

Cartridge test: none until ported.
