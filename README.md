# 6D — A Structured Engineering Workflow for Claude Code

**6D** is a Claude Code skill plugin that implements a rigorous, six-stage software development process. Each stage is an interactive conversation with a specialized AI assistant, producing a concrete artifact that feeds the next stage. The workflow enforces engineering discipline: explicit assumptions, measurable goals, empirical validation before implementation, and structured retrospectives.

```
Discover → Design → Demonstrate → Develop → Document → Debrief
```

---

## The Six Stages

| # | Stage | What Happens | Artifact |
|---|-------|-------------|----------|
| 1 | **Discover** | Deep problem domain exploration. Surfaces assumptions, defines measurable success criteria, maps constraints and stakeholders. No implementation talk. | `docs/6D/01-discover.md` |
| 2 | **Design** | Hardware-aware implementation design. Data layouts, compute kernels, module structure — driven by the hardware's capabilities, not the problem's semantics. | `docs/6D/02-design.md` |
| 3 | **Demonstrate** | Empirical validation of critical design assumptions. Minimal isolated test programs, measured against theoretical hardware limits. Failures caught here, not in production. | `design-verification/DESIGN_VERIFICATION.md` |
| 4 | **Develop** | Production code implementation. Structure defined and agreed before a single line is written. Incremental validation throughout. | (codebase) |
| 5 | **Document** | Developer-facing Hugo documentation site. Synthesizes all upstream artifacts into architecture docs, design decisions, internals, and codebase map. | `docs/` Hugo site |
| 6 | **Debrief** | Structured retrospective. Root-cause analysis of what worked and what didn't, with findings written back into the skill configurations for the next cycle. | `docs/6D/06-debrief.md` |

---

## Installation

### Requirements

- [Claude Code](https://github.com/anthropics/claude-code) CLI installed

### Install

Clone this repository into your Claude Code skills directory:

```bash
git clone https://github.com/YOUR_USERNAME/6D-plugin.git ~/.claude/skills-repos/6D-plugin
```

Then symlink (or copy) each skill into `~/.claude/skills/`:

```bash
for skill in 6D 6D-discover 6D-design 6D-demonstrate 6D-develop 6D-document 6D-debrief; do
  ln -sf ~/.claude/skills-repos/6D-plugin/skills/$skill ~/.claude/skills/$skill
done
```

Or use the included install script:

```bash
bash ~/.claude/skills-repos/6D-plugin/install.sh
```

---

## Usage

### Start a new project

```
/6D new
```

The orchestrator will ask for a project name and type, create the state file, and drop you into the **Discover** stage.

### Continue from where you left off

```
/6D
```

### Check current status

```
/6D status
```

### Complete the current stage and advance

```
/6D done
```

This writes the stage artifact, commits it to git, and tells you to `/clear` before starting the next stage (necessary to keep each stage's context focused).

### Jump to a specific stage

```
/6D discover
/6D design
/6D demonstrate
/6D develop
/6D document
/6D debrief
```

### Backtrack to an earlier stage

```
/6D back design
```

The orchestrator records the reason in the state file and loads the backtrack context for the target stage.

---

## Workflow Design Principles

**Explicit assumptions.** The primary cause of project failure is implicit assumptions. Every stage is designed to surface and challenge them.

**Measure, never guess.** Goals must be quantifiable. Performance claims must be benchmarked against hardware limits. "Fast" is not a result; "23 ms at 67% of theoretical peak" is.

**Hardware drives structure.** The Design stage shapes code around what CPUs and memory hierarchies can do efficiently — not around domain semantics or class hierarchies.

**Validate before implementing.** The Demonstrate stage exists specifically to catch design flaws before they are baked into production code.

**Honest retrospectives.** The Debrief stage writes findings back into the skill configurations themselves, so the process improves with every cycle.

**Loose coupling.** Functional interfaces over OOP. Flat data structures over pointer-chasing. Templates over inheritance.

---

## Repository Structure

```
skills/
  6D/              # Orchestrator — manages state, context loading, stage transitions
  6D-discover/     # Domain exploration and planning specialist
  6D-design/       # Hardware-aware implementation designer
  6D-demonstrate/  # Empirical design validation engineer
  6D-develop/      # Production code implementer
  6D-document/     # Technical documentation architect
  6D-debrief/      # Retrospective facilitator
install.sh         # Install script
```

---

## State File

The workflow maintains state in `.claude/6D-state.md` inside your project repository. This file tracks:
- Current active stage and status
- Artifact completion status
- Stage log with visit counts and dates
- Backtrack log with reasons

This file is committed to git at each stage transition, giving you a full history of the development cycle.

---

## License

MIT
