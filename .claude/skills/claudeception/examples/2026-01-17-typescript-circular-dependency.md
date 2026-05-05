---
date: 2026-01-17
title: TypeScript circular dependency diagnosis
tags: [typescript, imports, architecture]
source_trigger: retrospective
---

# What happened

A TypeScript module behaved inconsistently at runtime even though type-checking passed, and the failure moved depending on import order.

# What was learned

The instability came from a circular dependency chain that left one module partially initialized during evaluation.

# Evidence

- Runtime behavior changed with import order
- Static typing alone did not flag the issue clearly
- Breaking the import cycle stabilized initialization

# Reuse signal

Likely recurring in larger codebases. Keep as an incident note unless a broader pattern emerges across multiple entries.
