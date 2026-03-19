---
name: dew-deepcall
description: DAG-based recursive agent spawning protocol for the dew workflow. Enables subagents to spawn further subagents by writing callstack nodes into the DAG. Referenced by stage skills (executor role) and dew-metacog (caller role). Not intended for direct user invocation.
---

## Overview

Claude Code does not permit recursive subagent spawning: a subagent cannot call `Agent()` to create another subagent. The deepcall protocol provides a DAG-based call stack that simulates recursive spawning through a single executor.

**Two roles participate:**

- **Caller** — a subagent (e.g. the CCA) that needs to spawn one or more child agents. Creates callstack nodes in the DAG and terminates.
- **Executor** — the stage skill, running in the main conversation. Drains callstack nodes by spawning `Agent()` calls until none remain.

---

## DAG Node Convention

**Node ID prefix**: `callstack.` — all callstack nodes use this prefix so the executor can identify them via filtering.

**Recommended naming**:
- `callstack.<work-node-id>.worker` — a child agent doing a unit of work
- `callstack.<work-node-id>.worker-A`, `.worker-B` — competing child agents
- `callstack.<work-node-id>.restart` — the calling agent's continuation after child(ren) complete

**Fields**:
- `task`: short human-readable label, e.g. `"worker for demonstrate.slug.implement"`
- `context`: the **full, self-contained agent prompt** — this is what the executor passes to `Agent()`
- `priority`: **always 0** — keeps callstack nodes invisible to `dag_next` (which returns the highest-priority actionable node for real work). Only the executor queries for them explicitly via `dag_next_batch`.

**Dependencies**: wire the restart node to depend on all its worker node(s). This guarantees the restart only becomes actionable after all children have completed and been marked done by the executor.

---

## Caller Protocol

Use this when you (a subagent) need to spawn one or more child agents and then resume.

### 1. Create worker node(s)

```
dag_create_nodes([
  {
    "id": "callstack.<work-node-id>.worker",
    "task": "worker for <work-node-id>",
    "context": "<full self-contained worker prompt>",
    "priority": 0
  }
])
```

The worker prompt must be fully self-contained — the spawned agent receives no conversation history. Include:
- The concrete task to perform
- All relevant file paths, interfaces, and constraints
- **Result file instruction**: "Write a result summary to `.dew/callstack/result-<work-node-id>.md` before terminating. Include: what was done, files created/modified, key outcomes."

### 2. Create the restart node

```
dag_create_nodes([
  {
    "id": "callstack.<work-node-id>.restart",
    "task": "restart <your-skill> after worker for <work-node-id>",
    "context": "<full self-contained restart prompt>",
    "priority": 0
  }
])
```

The restart prompt must be fully self-contained and include:
- Everything needed to re-enter your skill's instructions at the correct step
- The result file path(s) to read: `.dew/callstack/result-<work-node-id>.md`
- Any state needed to continue (attempt count, success metric, node ID, DAG path, etc.)

### 3. Wire the dependency

```
dag_add_dependency("callstack.<work-node-id>.restart", "callstack.<work-node-id>.worker")
```

The restart only becomes actionable once the worker is marked done by the executor.

### 4. Terminate

Return a message to the executor: `"Deepcall: queued worker and restart for <work-node-id>. Run the executor loop."`

---

## Competing Strategies (Optional)

To spawn two child agents with different strategies and compare their outputs:

```
dag_create_nodes([
  {"id": "callstack.<id>.worker-A", "task": "worker A for <id>", "context": "<prompt A — writes result-<id>-A.md>", "priority": 0},
  {"id": "callstack.<id>.worker-B", "task": "worker B for <id>", "context": "<prompt B — writes result-<id>-B.md>", "priority": 0},
  {"id": "callstack.<id>.restart",  "task": "restart after A+B for <id>", "context": "<restart prompt — reads both result files, compares>", "priority": 0}
])
dag_add_dependency("callstack.<id>.restart", "callstack.<id>.worker-A")
dag_add_dependency("callstack.<id>.restart", "callstack.<id>.worker-B")
```

The executor processes A and B sequentially (both actionable, no deps between them); the restart fires after both are done.

---

## Executor Protocol

The stage skill is the sole executor. After **every** `Agent()` call (whether an initial CCA spawn or a callstack entry), run the drain loop:

```
loop:
  batch = dag_next_batch()
  callstack_ready = [n for n in batch if n.id starts with "callstack."]
  if callstack_ready is empty: break

  node = callstack_ready[0]          # take one at a time
  prompt = dag_show(node.id).context # read the full prompt
  Agent(prompt)                      # spawn the agent; wait for return
  dag_done(node.id, "executed")      # mark done → unblocks dependents
  # loop: agent may have created new callstack nodes
```

After the drain loop is empty, the executor calls `dag_next` for the next real work node.

**Important**: `dag_next_batch` does not set nodes to in-progress. Process callstack nodes one at a time to avoid ambiguity.

---

## Result Files

Workers write their output summaries to `.dew/callstack/result-<work-node-id>.md`. This file is ephemeral — it exists only for the duration of the callstack round-trip.

The calling agent's restart prompt must reference the exact file path. The restart agent reads it before proceeding with its review or continuation logic.

**Cleanup**: At stage start (before `dag_load`), and on `/dew pause`, scan for any pending (not-done) `callstack.*` nodes and mark them done with summary `"stale: cleared at stage/pause boundary"`. Also delete any `.dew/callstack/result-*.md` files. Stale callstack nodes from an interrupted session represent incomplete work that will be re-driven from DAG state on resume.
