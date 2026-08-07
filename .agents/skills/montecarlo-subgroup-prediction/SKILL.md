---
name: montecarlo-subgroup-prediction
description: |
  Fix Monte Carlo project completion simulations that give identical dates for all
  sub-groups (milestones, priorities, epics). Use when: (1) All sub-group predictions
  converge to the same date despite different remaining counts, (2) Proportional
  throughput scaling produces flat/identical results, (3) Applying overall scope rate
  to individual sub-groups causes simulations to hit max_weeks cap and never converge,
  (4) Building project forecasting tools that predict completion for sub-groups of
  a larger backlog. Covers hypergeometric draw model for milestones and cumulative
  priority model for sequential priorities.
author: Claude Code
version: 1.0.0
date: 2026-02-16
---

# Monte Carlo Sub-Group Prediction Scaling

## Problem

When running Monte Carlo simulations for project completion, predicting dates for
sub-groups (milestones, priorities, epics) within a larger project produces identical
results for all groups, or simulations diverge and hit the max_weeks cap.

## Context / Trigger Conditions

- Building a project forecasting tool that predicts dates for individual milestones
  or priority groups within a larger project backlog
- All sub-group predictions show the same date despite very different remaining counts
  (e.g., 5-item milestone shows same date as 46-item milestone)
- Simulations hit max_weeks (104) and produce dates 2+ years in the future
- Scope rate applied per-group causes negative net velocity (items grow each week)

## Root Causes

### 1. Proportional Scaling is Mathematically Constant

If you scale throughput proportionally:
```
share = remaining_i / total_remaining
scaled_throughput = overall_throughput * share
weeks = remaining_i / scaled_throughput
      = remaining_i / (overall_throughput * remaining_i / total_remaining)
      = total_remaining / overall_throughput  # CONSTANT for all groups!
```

Every sub-group predicts the same number of weeks regardless of size.

### 2. Overall Scope Rate Overwhelms Sub-Group Throughput

If the project's overall scope rate is 50 items/week and you apply it to a sub-group
with only 5 remaining items (share = 1.6%), the scaled throughput might be ~0.6/week
while scaled scope is ~0.8/week. Net velocity is negative — the simulation never
converges and hits max_weeks.

### 3. GitHub `created_at` ≠ "Added to Board"

Scope rate calculated from `created_at` dates reflects when GitHub issues were created,
not when they were added to the project board. Bulk triaging or importing old issues
inflates the apparent scope rate dramatically.

## Solution

Use **different simulation models** for different sub-group types:

### For Sequential Priorities (P0, P1, P2...): Cumulative Model

Higher priorities are completed first. Each priority's prediction includes all
higher-priority work that must finish before it:

```python
sorted_priorities = sorted(priorities, key=lambda p: p["name"])
cumulative_before = 0

for p in sorted_priorities:
    effective_remaining = cumulative_before + p["remaining"]
    result = simulate(
        remaining=effective_remaining,
        throughput_history=full_project_throughput,  # NOT scaled
        scope_rate=0.0,  # Don't apply scope per-group
    )
    result.remaining = p["remaining"]  # Show actual remaining
    cumulative_before += p["remaining"]
```

### For Milestones/Epics: Hypergeometric Draw Model

Items from each milestone are randomly drawn from the overall work pool. Smaller
milestones finish earlier due to higher variance:

```python
for i in range(n_simulations):
    subset_left = remaining
    pool_left = total_remaining
    weeks = 0
    while subset_left > 0 and weeks < max_weeks:
        throughput = rng.choice(throughput_samples)
        draw_size = min(throughput, pool_left)
        if draw_size > 0 and pool_left > 0:
            other = pool_left - subset_left
            # How many completed items come from this milestone?
            drawn = rng.hypergeometric(subset_left, max(other, 0), draw_size)
            subset_left -= drawn
            pool_left -= draw_size
            pool_left = max(pool_left, subset_left)
        weeks += 1
```

### Key Principles

1. **Don't scale throughput proportionally** — it produces identical results
2. **Don't apply overall scope rate to sub-groups** — it causes divergence
3. **Use the full project throughput** for priority predictions (cumulative model)
4. **Use hypergeometric sampling** for milestone predictions (discrete draws)
5. **Show scope rate as informational** rather than baking it into per-group MC

## Verification

- Sub-groups with fewer remaining items should predict earlier dates
- Smaller sub-groups should have wider confidence intervals (more variance)
- No predictions should hit the max_weeks cap under normal conditions
- Priority predictions should be ordered (P0 < P1 < P2 < P3)

## Example

With throughput of [2, 29, 44, 34, 11, 24, 33, 54, 34, 101, 57, 81, 0] and
303 total remaining items:

**Before fix (proportional scaling):**
```
MVP Rel 1 (5 left):   Apr 13    # All identical!
MVP Rel 2 (46 left):  Apr 13
Release 3 (33 left):  Apr 13
```

**After fix (hypergeometric draws):**
```
MVP Rel 1 (5 left):   Apr 6     # Differentiated by size
MVP Rel 2 (46 left):  Apr 13
Release 3 (33 left):  Apr 13
Zap Store (10 left):  Apr 13
```

## Notes

- The continuous proportional model (`subset_throughput = throughput * share`)
  is mathematically equivalent to "everything finishes when the project finishes"
  because the differential equation d(subset)/dt = -T*(subset/pool) preserves ratios
- The hypergeometric distribution is the correct statistical model for "drawing
  without replacement from a mixed pool"
- For very small sub-groups (< 5 items), the hypergeometric model produces high
  variance — this is correct and reflects genuine uncertainty
- Consider capping scope_rate at `min(scope_rate, throughput * 0.5)` if using it,
  to prevent divergent simulations
