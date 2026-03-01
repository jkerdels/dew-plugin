---
name: proc
description: 6D workflow orchestrator. Manages the six-stage development process (Discover → Design → Demonstrate → Develop → Document → Debrief), tracking state, loading artifact context, invoking stage skills, and maintaining git history at stage boundaries.
---

# 6D Workflow Orchestrator

**6D** is a structured engineering process for building software with rigor and measurability. Every stage is an interactive conversation — this orchestrator loads context and hands off to the appropriate stage skill, which runs directly in the current session.

| Stage | Skill | Artifact |
|-------|-------|----------|
| **Discover** | `/6D:discover` | `docs/6D/01-discover.md` |
| **Design** | `/6D:design` | `docs/6D/02-design.md` |
| **Demonstrate** | `/6D:demonstrate` | `design-verification/DESIGN_VERIFICATION.md` |
| **Develop** | `/6D:develop` | production code in repo |
| **Document** | `/6D:document` | `docs/` Hugo site |
| **Debrief** | `/6D:debrief` | `docs/6D/06-debrief.md` |

**Commands:**
- `/6D:proc` — continue from the current active stage
- `/6D:proc new` — start a new 6D project
- `/6D:proc done` — complete the current stage: write artifact, update state, commit, then prompt for `/clear`
- `/6D:proc status` — show current state without entering a stage
- `/6D:proc back <stage>` — backtrack to an earlier stage
- `/6D:<stage-name>` — jump to a named stage (discover / design / demonstrate / develop / document / debrief)

---

## Current Save State

!`cat .claude/6D-state.md 2>/dev/null || echo "6D_STATUS: none — no active project found"`

## Current Repository Status

!`git status --short 2>/dev/null || echo "(not a git repository — commits will be skipped)"`

---

## Instructions

Arguments provided: `$ARGUMENTS`

### Step 1 — Determine Action

| Condition | Action |
|-----------|--------|
| State is "none" **or** ARGUMENTS contains `new` | → **Initialize** a new project (Step 2) |
| ARGUMENTS is `done` | → **Complete** the current stage (Step 4) |
| ARGUMENTS is `status` | → **Report** current state and stop |
| ARGUMENTS starts with `back` | → **Backtrack** to the specified stage |
| ARGUMENTS matches a stage name | → **Jump** to that stage |
| State exists, ARGUMENTS is empty | → **Enter** the current active stage (Step 3) |

---

### Step 2 — Initialize (new project only)

1. Ask the user:
   - "What are we building? Give it a short slug-friendly name (e.g., `retina-pipeline`, `auth-system`)."
   - "Is this a **new project**, a **major new feature** in an existing codebase, or a **revisit/fix** of something in progress?"

2. Run `mkdir -p docs/6D` to create the artifact directory.

3. Write `.claude/6D-state.md` using the State File Format at the bottom of this file.

4. If in a git repo, commit the state file:
   - Message: `6D(init): begin 6D for <project-name>`

5. Set active stage to `discover` and enter the stage (Step 3).

---

### Step 3 — Enter Stage

Read the `Active Stage` from the save state. Load context for the stage (read any prerequisite artifacts). Then invoke the appropriate stage skill using the Skill tool.

**Context loading per stage:**

- **discover**: No prior artifacts. If revisit, read `docs/6D/01-discover.md` and summarize what changed.
- **design**: Read `docs/6D/01-discover.md` and present its contents to establish context before invoking the skill.
- **demonstrate**: Read `docs/6D/02-design.md` and present its contents before invoking the skill.
- **develop**: Read `docs/6D/02-design.md` and `design-verification/DESIGN_VERIFICATION.md` and present both before invoking the skill.
- **document**: Read `docs/6D/01-discover.md`, `docs/6D/02-design.md`, and `design-verification/DESIGN_VERIFICATION.md` and present all three before invoking the skill.
- **debrief**: Read `.claude/6D-state.md` (full contents including backtrack log) and present it before invoking the skill.

**After loading context**, briefly tell the user:
- Which stage we are entering
- What context was loaded
- That you are now invoking the stage skill

Then invoke the stage skill via the Skill tool:
- discover → `Skill("6D:discover")`
- design → `Skill("6D:design")`
- demonstrate → `Skill("6D:demonstrate")`
- develop → `Skill("6D:develop")`
- document → `Skill("6D:document")`
- debrief → `Skill("6D:debrief")`

**If this is a revisit** (backtrack log is non-empty for this stage), prepend a brief summary of why we are back here before invoking the skill, so the stage skill has the backtrack context.

---

### Step 4 — Complete Stage (triggered by `/6D:proc done`)

When the user invokes `/6D:proc done`:

1. **Write the stage artifact** by synthesizing the conversation:
   - discover → write `docs/6D/01-discover.md`
   - design → write `docs/6D/02-design.md`
   - demonstrate → finalize `design-verification/DESIGN_VERIFICATION.md` (test programs were written during the stage)
   - develop → no additional artifact; code is already in the repo
   - document → finalize the Hugo site files
   - debrief → write `docs/6D/06-debrief.md`

2. **Update `.claude/6D-state.md`**:
   - Mark the completed stage with today's date
   - Advance `Active Stage` to the next stage (or `complete` if debrief is done)
   - Mark the artifact as complete in the Artifacts table

3. **Git commit** (if in a git repo):
   - Stage `.claude/6D-state.md` and any new/changed files in `docs/6D/` or `design-verification/`
   - Message: `6D(<stage>): complete <stage-name> for <project-name>`
   - Example: `6D(discover): complete discovery for retina-pipeline`
   - Do **not** push unless explicitly asked

4. **Show a summary** and prompt for context reset:
   - What artifact was written
   - What stage is next and what it will focus on
   - Flag anything from the conversation that might warrant backtracking before proceeding
   - Then say: **"Run `/clear` and then `/6D:proc` to begin the next stage with a clean context."**

---

### Backtrack Protocol

When the user invokes `/6D:proc back <stage>`:

1. Ask for the reason if not provided: "What did you find that requires going back to [stage]?"

2. Update `.claude/6D-state.md`:
   - Add an entry to the Backtrack Log
   - Set `Active Stage` to the target stage
   - Mark all intermediate stages as `needs-revisit`

3. Commit the state update:
   - Message: `6D(backtrack): return to <stage> — <brief reason>`

4. Enter the stage (Step 3) with the backtrack context loaded.

---

### Status Report

When `/6D:proc status` is invoked:

```
6D: <project-name> (<type>)
─────────────────────────────────────────
  [✓] Discover      completed <date>
  [✓] Design        completed <date>
  [→] Demonstrate   in progress
  [ ] Develop       pending
  [ ] Document      pending
  [ ] Debrief       pending

Backtracks:  0
Artifacts:
  docs/6D/01-discover.md               ✓
  docs/6D/02-design.md                 ✓
  design-verification/DESIGN_VERIFICATION.md   in progress
```

Then stop — do not invoke any stage skill.

---

## State File Format

`.claude/6D-state.md`:

```markdown
# 6D Save State

## Project
- **Name**: <project-name>
- **Type**: new-project | major-feature | revisit-fix
- **Started**: <ISO date>
- **Last Updated**: <ISO date>

## Active Stage
**Stage**: discover | design | demonstrate | develop | document | debrief | complete
**Status**: in-progress | complete

## Artifacts
| Artifact | Path | Status |
|----------|------|--------|
| Discover | docs/6D/01-discover.md | pending |
| Design (IDD) | docs/6D/02-design.md | pending |
| Demonstrate | design-verification/DESIGN_VERIFICATION.md | pending |
| Develop | (codebase) | pending |
| Document | docs/ | pending |
| Debrief | docs/6D/06-debrief.md | pending |

## Stage Log
| Stage | Started | Completed | Visits | Notes |
|-------|---------|-----------|--------|-------|
| discover | — | — | 0 | |
| design | — | — | 0 | |
| demonstrate | — | — | 0 | |
| develop | — | — | 0 | |
| document | — | — | 0 | |
| debrief | — | — | 0 | |

## Backtrack Log
<!-- Format: | <date> | from: <stage> → to: <stage> | reason: <why> | resolved: yes/no | -->
(none yet)
```
