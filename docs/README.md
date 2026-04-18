# Documentation Index

This folder documents the target architecture for future feature work.

## Read In This Order

1. [../plan.md](../plan.md)
2. [architecture.md](architecture.md)
3. [feature-playbook.md](feature-playbook.md)
4. [refactor-roadmap.md](refactor-roadmap.md)
5. [../AGENTS.md](../AGENTS.md)

## What Each Doc Does

- [architecture.md](architecture.md): target architecture, boundaries, and reusable patterns
- [feature-playbook.md](feature-playbook.md): the checklist for implementing a new metric feature
- [refactor-roadmap.md](refactor-roadmap.md): how to migrate the current codebase toward the target architecture without a rewrite

## Important Context

The codebase is currently in a transition state:

- steps/activity, sleep, heart, and activities already follow the newer period-based detail pattern
- body and browse are still older patterns
- the repository is still centralized and will need cleanup over time

New work should follow the target architecture in these docs, even if some older files still use legacy patterns.
