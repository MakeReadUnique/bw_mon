# Domain Docs

This is a single-context repository. Domain terminology lives in root `GLOSSARY.md`; architectural decision records belong in `docs/adr/` when needed.

## Before exploring

Read `GLOSSARY.md` and any ADRs relevant to the area being explored. If either is absent, proceed silently; do not create placeholder glossary entries or ADRs. The `domain-modeling` skill creates them when terms or decisions are resolved.

## Use the glossary vocabulary

Use the names defined in `GLOSSARY.md` in issue titles, design discussions, hypotheses, and tests. Avoid synonyms explicitly rejected by the glossary. A missing term is a topic for domain modeling, not a reason to silently invent competing terminology.

## Flag ADR conflicts

If a proposal contradicts an existing ADR, identify that ADR and explain the conflict rather than silently overriding it.

## Layout

- `GLOSSARY.md`: the project's domain vocabulary.
- `docs/adr/`: architectural decisions, created lazily as decisions warrant them.

Do not create a `GLOSSARY-MAP.md` or additional contexts unless the project's structure actually requires them.
