---
date: 2026-01-15
title: Next.js server-side error debugging
tags: [nextjs, server-side, debugging]
source_trigger: retrospective
---

# What happened

A Next.js page showed a generic server error, but the browser console was empty, which made the failure look client-side at first.

# What was learned

The failing code path was server-side, so the useful stack trace lived in the terminal running the app rather than in the browser console.

# Evidence

- The browser showed an error page with no actionable console output
- The dev server terminal contained the actual exception and file location
- Adding server-side logging confirmed the failing path

# Reuse signal

Likely recurring. This is a common debugging trap in server-rendered Next.js flows.
