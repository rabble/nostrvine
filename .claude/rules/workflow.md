# Workflow Orchestration

Rules governing how Claude Code approaches tasks in this project.

---

## 1. Plan Mode Default

- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions).
- If an approach goes sideways, STOP and re-plan immediately. Do not keep pushing a failing strategy.
- Use plan mode for verification steps, not just building.
- Write detailed specs upfront to reduce ambiguity.

## 2. Subagent Strategy

- Use subagents liberally to keep the main context window clean.
- Offload research, exploration, and parallel analysis to subagents.
- For complex problems, throw more compute at it via subagents.
- One task per subagent for focused execution.

## 3. Self-Improvement Loop

- After ANY correction from the user, update `tasks/lessons.md` with the pattern.
- Write rules that prevent the same mistake from recurring.
- Review `tasks/lessons.md` at the start of relevant sessions.
- This complements the memory system: memory stores preferences, lessons stores operational mistake-prevention rules.

## 4. Verification Before Done

- Never mark a task complete without proving it works.
- Diff behavior between main and your changes when relevant.
- Ask: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness.
- A task is not done until verification passes.

## 5. Demand Elegance (Balanced)

- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution."
- Skip this for simple, obvious fixes — do not over-engineer.
- Challenge your own work before presenting it.

## 6. Autonomous Bug Fixing

- When given a bug report, just fix it. Do not ask for hand-holding.
- Point at logs, errors, failing tests — then resolve them.
- Zero context switching required from the user.
- Go fix failing CI tests without being told how.

---

## Task Management Process

For non-trivial tasks, follow this sequence:

1. **Plan First**: Use plan mode or write a plan with checkable items.
2. **Verify Plan**: Check in with the user before starting implementation.
3. **Track Progress**: Mark items complete as you go.
4. **Explain Changes**: High-level summary at each step.
5. **Document Results**: Summarize what was done and any open items.
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections.

---

## Investigation Principles

These apply whenever analyzing bugs, issues, or unexpected behavior:

- **Morgan's Law**: AI analysis might be wrong. Acknowledge uncertainty. Rate confidence. Never present speculation as fact.
- **Confidence scoring**: Rate hypotheses on a 0.0-1.0 scale so the user knows where to focus verification.
- **Verify every claim**: Never trust a diagnosis without tracing the code. Read the source.
- **Always provide a workaround**: Even if ugly, give something shippable today.
- **Ask before assuming**: Identify missing information and ask, do not fill gaps with assumptions.

---

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what is necessary. Avoid introducing bugs.
