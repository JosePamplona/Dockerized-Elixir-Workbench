<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and the format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/):

- `Added` for new features.
- `Changed` for changes in existing functionality.
- `Deprecated` for once-stable features removed in upcoming releases.
- `Removed` for deprecated features removed in this release.
- `Fixed` for any bug fixes.
- `Security` to invite users to upgrade in case of vulnerabilities.

## Unreleased

> During development, milestones can be added to this section. Once finished working on them, it's only needed to copy the commented title template line, adjust the title version & date and uncomment it.
<!-- ## v0.0.0 - (0000-00-00) -->

    # CONTINUE
    2 exdocs & helthcheck controllers docs and tests
    3 Enhancements
        ecto enhacements for exdocs and schemas
        -> error: field types in documentation all are any() 
        -> change schema module name
        remove githooks?
    4 Auth0 <-------------- al terminar aqui, te pasas al sitio JayParcade
    5 Stripe
          

- db port change breask pgadmin maybe back
- Solve Gettext incompatibility when HTML (maybe it doesnt worth the time):
  
    <https://github.com/elixir-gettext/gettext/blob/main/CHANGELOG.md>

    mix.lock -> "gettext": {:hex, :gettext, "0.26.1" >= 0.26

    1. Change the file lib/my_app_web.ex

        (+/-) line 46: change from import MyAppWeb.Gettext to use Gettext, backend: MyAppWeb.Gettext;
        (+/-) line 88: change import MyAppWeb.Gettext to use Gettext, backend: MyAppWeb.Gettext

    2. Change the file lib/my_app_web/components/core_components.ex:

        (+/-) line 20: change import MyAppWeb.Gettext to use Gettext, backend: MyAppWeb.Gettext

    3. Change the file: lib/my_app_web/gettext.ex:

        (+/-) line 23: change from use Gettext, otp_app: :my_app to use Gettext.Backend, otp_app: :my_app

## v0.2.0 - (2024-10-24)

### Changed

- `README.md` adjustments.
- Workbench script refactor.
- The workspace script and its files are moved to a subfolder, leaving the new project files in root directory instead of creating the project in a subfolder.

### Added

- Generate `.tool-versions` file for [ASDF Version Manager](https://asdf-vm.com/) compatibility.
- Updating the workbench script version at the beginning of the file will update the version badge in the `README.md` file during the next script run.
- Workbench script implementation: **ExDoc**. The pages and content are adjusted following `config.conf` file.
- Workbench script in *ExDoc* documentation.
- Multiple architecture images and content for different project configurations in the *ExDoc* workbench documentation.
- Workbench script implementation: **Coveralls**.
- Mix task `mix cover` for test report generation for ExDoc.
- Workbench script implementation: **Healthcheck**.
- Workbench script implementation: **OpenAPI**.
- Workbench script implementation: **Stripe**.
- Workbench script implementation: **Auth0**.
- **Delete** command in workbench script.
- **Demo** command in workbench script.
- **Help** command in workbench script.
- Workbench script implementation: **Flame On**.
- Mix task `mix version` for update project version on `mix.exs` and `README.md` file.
- Workbench script implementation: **Ex Debug**.
- Workbench script implementation: **OS mon**.

## v0.1.0 - (2024-10-07)

### Added

- Second version after *Pitchers* testing cycle (Untracked changes).
