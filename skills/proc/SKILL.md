---
name: proc
description: six-d workflow orchestrator. Manages the six-stage development process (Discover → Design → Demonstrate → Develop → Document → Debrief), tracking state, loading artifact context, invoking stage skills, and maintaining git history at stage boundaries.
---

# six-d Workflow Orchestrator

**six-d** is a structured engineering process for building software with rigor and measurability. Every stage is an interactive conversation — this orchestrator loads context and hands off to the appropriate stage skill, which runs directly in the current session.

| Stage | Skill | Artifact |
|-------|-------|----------|
| **Discover** | `/six-d:discover` | `docs/six-d/01-discover.md` |
| **Design** | `/six-d:design` | `docs/six-d/02-design.md` |
| **Demonstrate** | `/six-d:demonstrate` | `design-verification/DESIGN_VERIFICATION.md` |
| **Develop** | `/six-d:develop` | production code in repo |
| **Document** | `/six-d:document` | `docs/` Hugo site |
| **Debrief** | `/six-d:debrief` | `docs/six-d/06-debrief.md` |

**Commands:**
- `/six-d:proc` — continue from the current active stage
- `/six-d:proc new` — start a new six-d project
- `/six-d:proc done` — complete the current stage: write artifact, update state, commit, then prompt for `/clear`
- `/six-d:proc status` — show current state without entering a stage
- `/six-d:proc back <stage>` — backtrack to an earlier stage
- `/six-d:<stage-name>` — jump to a named stage (discover / design / demonstrate / develop / document / debrief)

---

## Current Save State

!`cat .claude/six-d-state.md 2>/dev/null || echo "six-d_STATUS: none — no active project found"`

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

2. Run `mkdir -p docs/six-d` to create the artifact directory.

3. Write `.claude/six-d-state.md` using the State File Format at the bottom of this file.

4. If in a git repo, commit the state file:
   - Message: `six-d(init): begin six-d for <project-name>`

5. Set active stage to `discover` and enter the stage (Step 3).

---

### Step 3 — Enter Stage

Read the `Active Stage` from the save state. Load context for the stage (read any prerequisite artifacts). Then invoke the appropriate stage skill using the Skill tool.

**Context loading per stage:**

- **discover**: No prior artifacts. If revisit, read `docs/six-d/01-discover.md` and summarize what changed.
- **design**: Read `docs/six-d/01-discover.md` and present its contents to establish context before invoking the skill.
- **demonstrate**: Read `docs/six-d/02-design.md` and present its contents before invoking the skill.
- **develop**: Read `docs/six-d/02-design.md` and `design-verification/DESIGN_VERIFICATION.md` and present both before invoking the skill.
- **document**: Read `docs/six-d/01-discover.md`, `docs/six-d/02-design.md`, and `design-verification/DESIGN_VERIFICATION.md` and present all three before invoking the skill.
- **debrief**: Read `.claude/six-d-state.md` (full contents including backtrack log) and present it before invoking the skill.

**After loading context**, briefly tell the user:
- Which stage we are entering
- What context was loaded
- That you are now invoking the stage skill

Then invoke the stage skill via the Skill tool:
- discover → `Skill("six-d:discover")`
- design → `Skill("six-d:design")`
- demonstrate → `Skill("six-d:demonstrate")`
- develop → `Skill("six-d:develop")`
- document → `Skill("six-d:document")`
- debrief → `Skill("six-d:debrief")`

**If this is a revisit** (backtrack log is non-empty for this stage), prepend a brief summary of why we are back here before invoking the skill, so the stage skill has the backtrack context.

---

### Step 4 — Complete Stage (triggered by `/six-d:proc done`)

When the user invokes `/six-d:proc done`:

1. **Write the stage artifact** by synthesizing the conversation:
   - discover → write `docs/six-d/01-discover.md`
   - design → write `docs/six-d/02-design.md`
   - demonstrate → finalize `design-verification/DESIGN_VERIFICATION.md` (test programs were written during the stage)
   - develop → no additional artifact; code is already in the repo
   - document → finalize the Hugo site files
   - debrief → write `docs/six-d/06-debrief.md`

2. **Update `.claude/six-d-state.md`**:
   - Mark the completed stage with today's date
   - Advance `Active Stage` to the next stage (or `complete` if debrief is done)
   - Mark the artifact as complete in the Artifacts table

3. **Git commit** (if in a git repo):
   - Stage `.claude/six-d-state.md` and any new/changed files in `docs/six-d/` or `design-verification/`
   - Message: `six-d(<stage>): complete <stage-name> for <project-name>`
   - Example: `six-d(discover): complete discovery for retina-pipeline`
   - Do **not** push unless explicitly asked

4. **Show a summary** and prompt for context reset:
   - What artifact was written
   - What stage is next and what it will focus on
   - Flag anything from the conversation that might warrant backtracking before proceeding
   - Then say: **"Run `/clear` and then `/six-d:proc` to begin the next stage with a clean context."**

---

### Backtrack Protocol

When the user invokes `/six-d:proc back <stage>`:

1. Ask for the reason if not provided: "What did you find that requires going back to [stage]?"

2. Update `.claude/six-d-state.md`:
   - Add an entry to the Backtrack Log
   - Set `Active Stage` to the target stage
   - Mark all intermediate stages as `needs-revisit`

3. Commit the state update:
   - Message: `six-d(backtrack): return to <stage> — <brief reason>`

4. Enter the stage (Step 3) with the backtrack context loaded.

---

### Status Report

When `/six-d:proc status` is invoked:

```
six-d: <project-name> (<type>)
─────────────────────────────────────────
  [✓] Discover      completed <date>
  [✓] Design        completed <date>
  [→] Demonstrate   in progress
  [ ] Develop       pending
  [ ] Document      pending
  [ ] Debrief       pending

Backtracks:  0
Artifacts:
  docs/six-d/01-discover.md               ✓
  docs/six-d/02-design.md                 ✓
  design-verification/DESIGN_VERIFICATION.md   in progress
```

Then stop — do not invoke any stage skill.

---

## State File Format

`.claude/six-d-state.md`:

```markdown
# six-d Save State

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
| Discover | docs/six-d/01-discover.md | pending |
| Design (IDD) | docs/six-d/02-design.md | pending |
| Demonstrate | design-verification/DESIGN_VERIFICATION.md | pending |
| Develop | (codebase) | pending |
| Document | docs/ | pending |
| Debrief | docs/six-d/06-debrief.md | pending |

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
