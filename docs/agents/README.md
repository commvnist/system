# agentic skills

This directory extends the repository root `AGENTS.md`. It does not replace it.

The root `AGENTS.md` already defines the correct philosophy:

- correctness and safety first;
- clarity and maintainability over cleverness;
- explicit handling of greenfield vs brownfield contexts;
- strong invariants, validation, and error handling;
- observability and debuggability as first-class concerns;
- performance only when measured and justified.

This package exists to operationalize that philosophy in a low-token,
single-agent execution model.

## Design goal

Avoid the common failure mode of modern agent systems: excessive planning,
self-reflection loops, or multi-agent orchestration that increases cost without
improving correctness.

Instead, enforce disciplined execution:

- bounded search;
- minimal plans;
- smallest correct diffs;
- explicit verification;
- evidence-driven debugging.

## Relationship to root `AGENTS.md`

Root file defines:

- engineering philosophy and priority ordering;
- design and correctness standards;
- output structure;
- greenfield vs brownfield reasoning.

This package defines:

- execution pipeline;
- planning constraints;
- verification flow;
- debugging loop.

If any rule here conflicts with the root file, the root file wins.

## Operating model

The pipeline is a constrained execution of the root philosophy:

1. Determine context (greenfield vs brownfield).
2. Extract constraints (interfaces, invariants, integration points).
3. Inspect only relevant code.
4. Form a minimal, concrete plan.
5. Implement the simplest correct solution.
6. Verify using tests or reproducible checks.
7. Perform critical self-review (as defined in root `AGENTS.md`).

This aligns directly with the workflow already defined in the root file, but
adds strict limits on search, planning depth, and iteration.

## Key constraints

- No multi-agent decomposition.
- No open-ended planning loops.
- No large refactors without necessity.
- No claims of correctness without evidence.

## Expected outputs

Outputs must still follow the root format:

- context type;
- context summary;
- assumptions and constraints;
- design;
- code;
- tests;
- risks and gaps.

The difference is that this package ensures those outputs are produced
consistently and efficiently.

## Limits

This package intentionally does not attempt:

- autonomous long-horizon system design;
- speculative architectural refactors;
- exhaustive repository analysis.

Those should be explicitly requested when needed, not the default mode.
