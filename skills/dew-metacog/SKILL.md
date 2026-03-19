---
name: dew-metacog
description: Context Creator Agent (CCA) for the dew workflow. Given a single DAG node, either (a) crafts a focused worker prompt and queues it via deepcall, or (b) reviews completed worker output and calls dag_done. Manages decomposition when tasks are too coarse and predecessor correction when prior work is insufficient. Invoked per-node by stage skills; child agents spawned via the deepcall protocol (skills/dew-deepcall/SKILL.md).
---

## Invocation Modes

This skill handles two distinct invocation modes. **Read your prompt carefully to determine which applies.**

- **Initial mode**: No worker result is mentioned. You are processing a node from scratch. Begin at [Step 1].
- **Restart mode**: Your prompt contains a result file path and says "Proceed: Review the Output". Skip directly to [Review Protocol].

---

## Step 1: Load Context

1. Call `dag_load(<dag-path>)` and `dag_save(<dag-path>, auto_save=true)`.
2. Call `dag_show(<node-id>)` to read the node's full task description, context, and current state.
3. Read `<quality-context-path>`.
4. Read `<cca-log-path>`. If the file does not exist, treat the log as empty. Focus on the **Distilled Principles** section. Check the Instance Records count: if greater than 10, perform [Log Distillation] before proceeding.

---

## Step 2: Can I Define a Success Metric?

**First check**: If the node's `dag_log` shows it was previously decomposed (message like "Decomposed into [sub-node list]") and all listed sub-nodes are done — call `dag_done(<node-id>, "Decomposed into [list]; all sub-tasks completed.")` and exit.

Otherwise, attempt to write — in one or two sentences — a condition that a third party could evaluate without ambiguity, by running code, reading output, or inspecting produced artifacts.

- **If you CAN write this metric**: record it. Proceed to [Worker Protocol].
- **If you CANNOT**: the task is not yet atomic enough. Proceed to [Decomposition Protocol].

The inability to define a metric is diagnostic: the node's task or context lacks the precision required for reliable implementation. Decomposition is the correct response — do not attempt to work around it with a vague prompt.

---

## Worker Protocol

*(Initial mode only. After this section you will terminate — review happens in a restart invocation.)*

### Craft the Prompt

Read `skills/dew-deepcall/SKILL.md` before proceeding. You are the **caller**.

Assemble a focused prompt for a fresh worker agent containing:

1. **The task** (from the node's `task` field) — the imperative directive.
2. **The context** (from the node's `context` field) — constraints, preconditions, design rationale, acceptance criteria.
3. **Quality context reference**: "Read `<quality-context-path>` before starting and adhere to all requirements and principles defined there."
4. **Stage-specific standards reference**:
   - If the node ID starts with `demonstrate.`: "For verification standards and test program conventions, read `skills/dew-demonstrate/SKILL.md`."
   - If the node ID starts with `develop.`: "For implementation standards and code quality requirements, read `skills/dew-develop/SKILL.md`."
   - If the node ID starts with `fast.build.`: "For implementation standards, read `skills/dew-fast/SKILL.md` (Phase 2: Build)."
5. **The success metric**: state it explicitly — "You are done when: [metric]."
6. **Existing repo context**: briefly describe relevant files, interfaces, or prior implementations the worker must respect. Read the repo state before crafting this section.
7. **Output requirements**: specify exactly what the worker must produce — which files to write, which functions to implement, which tests to run.
8. **Result file instruction**: "Write a result summary to `.dew/callstack/result-<node-id>.md` before terminating. Include: what was done, files created or modified, key outcomes, and whether the success metric was met."

Keep the prompt focused. Every element of context must be load-bearing.

### Deepcall the Worker

Create the callstack nodes following the Caller Protocol in `skills/dew-deepcall/SKILL.md`:

```
dag_create_nodes([
  {
    "id": "callstack.<node-id>.worker",
    "task": "worker for <node-id>",
    "context": "<the crafted prompt above>",
    "priority": 0
  },
  {
    "id": "callstack.<node-id>.restart",
    "task": "CCA restart for <node-id> — attempt 1",
    "context": "Read skills/dew-metacog/SKILL.md. Node ID: <node-id>. DAG path: <dag-path>. Quality context: <quality-context-path>. CCA log: <cca-log-path>. Worker result: .dew/callstack/result-<node-id>.md. Success metric: <M>. Attempt: 1 of 2. Proceed: Review the Output.",
    "priority": 0
  }
])
dag_add_dependency("callstack.<node-id>.restart", "callstack.<node-id>.worker")
```

Terminate: `"Deepcall: queued worker and restart for <node-id>. Run the executor loop."`

### Optional: Competing Strategies

For genuinely ambiguous tasks where two distinct prompt strategies may yield meaningfully different results, spawn two workers in parallel (executed sequentially by the executor):

```
dag_create_nodes([
  {"id": "callstack.<node-id>.worker-A", "task": "worker A for <node-id>", "context": "<prompt strategy A — writes result-<node-id>-A.md>", "priority": 0},
  {"id": "callstack.<node-id>.worker-B", "task": "worker B for <node-id>", "context": "<prompt strategy B — writes result-<node-id>-B.md>", "priority": 0},
  {"id": "callstack.<node-id>.restart",  "task": "CCA restart for <node-id> — compare A+B", "priority": 0,
   "context": "Read skills/dew-metacog/SKILL.md. Node ID: <node-id>. DAG path: <dag-path>. Quality context: <quality-context-path>. CCA log: <cca-log-path>. Worker A result: .dew/callstack/result-<node-id>-A.md. Worker B result: .dew/callstack/result-<node-id>-B.md. Success metric: <M>. Compare both results. Proceed: Review the Output (Competing Strategy)."}
])
dag_add_dependency("callstack.<node-id>.restart", "callstack.<node-id>.worker-A")
dag_add_dependency("callstack.<node-id>.restart", "callstack.<node-id>.worker-B")
```

Terminate: `"Deepcall: queued workers A+B and restart for <node-id>. Run the executor loop."`

---

## Review Protocol

*(Restart mode only. Your prompt specifies the result file(s) and success metric.)*

### Load Results

Read the result file(s) specified in your prompt. If a result file is missing, treat it as a failed execution — proceed to the BAD path with diagnosis "execution failure: no result written."

### Evaluate Output

1. **Metric satisfied?** Yes / No / Partial — with specific, verifiable evidence from the result file and produced artifacts.
2. **Node context constraints respected?** Check each constraint in the node's context field explicitly.
3. **Quality context requirements met?** Spot-check the key standards from `<quality-context-path>`.

**If GOOD** (metric met, constraints respected, quality satisfied):
- Call `dag_done(<node-id>, "<one concrete sentence describing what was produced>")`.
- Append an Instance Record to `<cca-log-path>` (see [Metacognitive Log]).
- Exit.

**If BAD** — diagnose and respond:

| Diagnosis | Signal | Response |
|-----------|--------|----------|
| Bad prompt | Wrong direction taken; constraints present in prompt were ignored or misapplied | Revise prompt, deepcall new worker (see below). |
| Task too large | Partial satisfaction; worker could not coordinate across full scope | [Decomposition Protocol] |
| Predecessor insufficient | Worker needed output from a prior node that is missing or incorrect | [Predecessor Correction Protocol] |
| Metric underdefined | Worker satisfied the literal metric but missed the intent | Refine the metric, deepcall new worker with corrected metric (see below). |

### Reprompt via Deepcall

Check your attempt count (from your invocation prompt). If this is **attempt 1**, you may spawn a revised worker:

```
dag_create_nodes([
  {
    "id": "callstack.<node-id>.worker-2",
    "task": "worker 2 (reprompt) for <node-id>",
    "context": "<revised prompt — writes result-<node-id>-2.md>",
    "priority": 0
  },
  {
    "id": "callstack.<node-id>.restart-2",
    "task": "CCA restart for <node-id> — attempt 2",
    "context": "Read skills/dew-metacog/SKILL.md. Node ID: <node-id>. DAG path: <dag-path>. Quality context: <quality-context-path>. CCA log: <cca-log-path>. Worker result: .dew/callstack/result-<node-id>-2.md. Success metric: <M>. Attempt: 2 of 2. Proceed: Review the Output.",
    "priority": 0
  }
])
dag_add_dependency("callstack.<node-id>.restart-2", "callstack.<node-id>.worker-2")
```

Terminate: `"Deepcall: queued reprompt worker and restart for <node-id>. Run the executor loop."`

If this is **attempt 2** and the result is still bad, escalate:
```
dag_log(<node-id>, "CCA escalation: 2 attempts exhausted. Diagnosis: [reason]. Manual review required.")
```
Append an Instance Record. Exit without calling `dag_done`.

---

## Decomposition Protocol

The node is too coarse for a reliable single-worker attempt.

1. Identify 2–5 sub-tasks such that each independently admits a concrete success metric and together they cover the full scope.

2. Create sub-nodes:
   ```
   dag_create_nodes([
     {"id": "<node-id>.1", "task": "...", "context": "...", "priority": <p>},
     {"id": "<node-id>.2", "task": "...", "context": "...", "priority": <p>},
     ...
   ])
   ```
   Write rich context fields — each sub-node must be self-contained.

3. Wire sub-node dependencies:
   ```
   dag_add_dependencies([...])
   ```

4. Make the parent node depend on the final sub-node(s):
   ```
   dag_add_dependency("<node-id>", "<node-id>.last")
   ```

5. Log the decomposition on the parent node:
   ```
   dag_log("<node-id>", "Decomposed into [list of sub-node IDs] because: [reason]. Mark done once all sub-nodes are complete.")
   ```

6. Terminate. The stage skill's `dag_next` loop will naturally pick up the new sub-nodes in dependency order and spawn a CCA for each. When all sub-nodes are done, `dag_next` will return the parent node — a fresh CCA will read the log note and call `dag_done` (handled in [Step 2] shortcut).

---

## Predecessor Correction Protocol

The current node's work revealed that a prerequisite node's output is incomplete or incorrect.

1. Identify the specific predecessor node.
2. Assess the blast radius: call `dag_show(<predecessor-id>)` to understand how many dependents will be invalidated.
3. Log the issue on the predecessor:
   ```
   dag_log("<predecessor-id>", "CCA flagged from [current-node-id]: output insufficient because [specific reason]. Missing: [what was needed]. Blast radius: approx. [N] dependents will be invalidated.")
   ```
4. Reopen the predecessor:
   ```
   dag_start("<predecessor-id>")
   ```
   This cascade-invalidates all transitive dependents, including the current node.
5. Append an Instance Record to the CCA log noting what was missing and why.
6. Exit without calling `dag_done` — the current node is now invalidated and will be re-queued by the stage skill's `dag_next` loop.

---

## Metacognitive Log

### Format

```markdown
# CCA Metacognitive Log

## Distilled Principles
<!-- General rules derived from experience. Updated during log distillation. -->
(none yet)

## Instance Records
<!-- One entry per node processed. Most recent first. -->
```

### Writing an Instance Record

After every node completion, escalation, decomposition, or predecessor correction:

```markdown
### [node-id] — [GOOD / BAD→reprompted / BAD→decomposed / BAD→predecessor / ESCALATED]
**Task**: [one-sentence task description]
**Strategy**: [what the prompt emphasized; what approach was taken]
**Outcome**: [what happened; was the metric met?]
**Lesson**: [specific and actionable — what to do differently, or what worked well]
```

### Log Distillation

When Instance Records exceed 10 entries:

1. Read all records.
2. Identify recurring patterns.
3. Rewrite the **Distilled Principles** section as a short bulleted list of general rules.
4. Retain the 3 most recent Instance Records; archive or remove the rest.

---

## Constraints

- **One node at a time.** Do not process multiple nodes in a single invocation.
- **No optimistic completion.** The success metric must be verifiably satisfied before calling `dag_done`.
- **Do not silently resolve ambiguities.** If the node context is ambiguous, log the ambiguity via `dag_log` before crafting the prompt.
- **Never call `Agent()` directly.** All child agent spawning goes through the deepcall protocol (`skills/dew-deepcall/SKILL.md`). You are a caller, not an executor.
- **Blast radius before reopening.** Always check the invalidation scope before calling `dag_start` on a predecessor.
