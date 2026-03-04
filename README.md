# Provider Integration Skill (Safe Mode)

This repository contains a **non-executing** skill for checkout planning.

It is intentionally scoped to:
- architecture guidance
- data model planning
- UX state handling (`pending`, `approved`, `rejected`)
- mock provider scaffolding for local development

It is intentionally **out of scope** for this skill:
- gateway SDK installation
- API credentials or secret handling
- callback endpoint implementation
- creating or confirming live provider sessions
- any live external-provider execution path

## What You Can Use It For

- Prepare your Next.js checkout architecture before connecting any provider.
- Generate provider-agnostic interfaces and mock adapters.
- Build success/failure/pending UI states without external dependencies.
- Add testable server routes that use deterministic fake responses.

## What You Should Not Use It For

Do not use this skill as a production provider implementation. Real money movement must be implemented and reviewed separately under your org security controls.

## Installation

1. Clone this repository.
2. Copy `mercadopago-integration/` to your skills directory.
3. Invoke the skill for planning/scaffolding tasks.

## Structure

- `mercadopago-integration/SKILL.md`: skill behavior and safety constraints.
- `mercadopago-integration/references/server-implementation.md`: provider interface + mock server adapter.
- `mercadopago-integration/references/client-implementation.md`: mock checkout client flow.
- `mercadopago-integration/references/testing.md`: local testing strategy.
- `mercadopago-integration/references/troubleshooting.md`: common integration-prep issues.
- `mercadopago-integration/references/usage-examples.md`: safe prompts.

## License

MIT




