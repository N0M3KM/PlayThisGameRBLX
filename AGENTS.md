# Repository Guidelines

## Project Structure & Module Organization

This repository is currently empty. No source directories, tests, assets, or project configuration are present. When adding the initial implementation, organize application code under `src/`, automated tests under `tests/`, and static resources under `assets/` when appropriate. Keep root-level files focused on project configuration and contributor documentation. Update this guide to reflect the actual structure once established.

## Build, Test, and Development Commands

No build system, package manager, or development commands are configured yet. When selecting the project tooling, document exact installation, local development, build, and test commands in `README.md`. Ensure each documented command works from the repository root. Do not assume commands such as `npm test` exist until the corresponding configuration is committed.

## Coding Style & Naming Conventions

Follow the conventions of the language and framework chosen for the implementation. Configure a formatter and linter early, and commit their configuration so contributors use consistent rules. Use descriptive filenames and identifiers, keep modules focused, and avoid unrelated formatting changes. Document indentation and naming rules here when the toolchain is established.

## Testing Guidelines

No testing framework or coverage threshold is currently defined. Add automated tests alongside new behavior, including relevant edge cases and failure paths. Use descriptive test names that identify the behavior being verified. Document test discovery rules and the command for running the suite when introducing the framework.

## Commit & Pull Request Guidelines

No Git history is available to establish existing commit conventions. Use concise, imperative commit subjects, such as `Add initial project configuration`. Keep commits focused. Pull requests should explain the change, summarize validation performed, link relevant issues, and include screenshots for visible interface changes.

## Security & Configuration

Never commit credentials or private configuration. Provide sanitized configuration examples and document required environment variables as they are introduced.