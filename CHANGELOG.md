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

- db port change breask pgadmin maybe back

### Changed

- Workbench script refactor.
- The workspace script and its files are moved to a subfolder, leaving the new project files in root directory instead of creating the project in a subfolder.

### Added

- Workbench script implementation: **ExDoc**. The pages and content are adjusted following `config.conf` file.
- Workbench script in *ExDoc* documentation.
- Multiple architecture images and content for different project configurations in the *ExDoc* workbench documentation.
- Workbench script implementation: **Coveralls**.
- Mix task `mix cover` for test report generation for ExDoc
- Workbench script implementation: **Healthcheck**.
- Workbench script implementation: **OpenAPI**.
- Workbench script implementation: **Stripe**.
- Workbench script implementation: **Auth0**.
- **Delete** command in workbench script.
- **Demo** command in workbench script.
- **Help** command in workbench script.

## v0.1.0 - (2024-10-07)

### Added

- Second version after *Pitchers* testing cycle (Untracked changes).
