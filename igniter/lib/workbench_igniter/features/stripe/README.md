# Cartridge: stripe

Stripe payments and subscriptions — **pending**, not done yet.

* **Task**: `mix workbench.install.stripe` (does not exist yet)
* **Requires**: `auth0` (subscriptions belong to users)

## Description

Payments and subscriptions with Stripe. The manifest is registered so
the catalog shows the box as pending, but the installer is not done:
nothing can insert it yet.

When it is done, fill this directory in like any other cartridge (see the
checklist in the package README): `task.ex`, `templates/`, its test and
this README.

## Contents

| File | Role |
| --- | --- |
| `stripe.ex` | Manifest only (`pending?/0` returns `true`) |

Cartridge test: none until ported.
