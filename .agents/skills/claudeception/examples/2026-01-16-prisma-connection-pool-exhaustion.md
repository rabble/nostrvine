---
date: 2026-01-16
title: Prisma connection pool exhaustion in serverless
tags: [prisma, database, serverless]
source_trigger: retrospective
---

# What happened

A serverless deployment started failing under moderate concurrency with connection-count errors that did not reproduce during low-volume local testing.

# What was learned

The root issue was connection churn from per-request client creation in a serverless environment, not an isolated query bug.

# Evidence

- Production logs showed repeated connection limit failures
- Failures correlated with concurrent traffic rather than a specific endpoint
- Reusing a shared Prisma client removed the connection spike

# Reuse signal

Likely recurring. This is a recognizable deployment pattern worth retaining as memory and maybe promoting later.
