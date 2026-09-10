# Issue + PR Driven Development Workflow (SOP)

Development in this repository must follow a strict, chronological **Pre-Code Draft PR -> Single-Item Loop -> Merge** lifecycle.

---

## 1. Dual-Planning Model

To maintain clear separation of concerns between functional task design and toolchain validation, agents must distinguish between two distinct planning phases:

1. **Phase A: Task Planning (Pre-development - BEFORE CODING)**:
   - Defining *what* to build: Issue analysis, module boundaries, architectural design, and opening the Draft PR with an unchecked `- [ ]` checklist.
2. **Phase B: Quality Gate Pre-check (Post-edit - AFTER EDIT)**:
   - Previewing *which* linter and formatter steps will execute on edited files via `mise run check:plan` before committing.

---

## 2. Chronological Lifecycle

```
+------------------------------------------------------------------------+
| 1. Pre-Code Initialization (MANDATORY BEFORE ANY CODE IS WRITTEN)       |
|    gh issue view <id>                                                  |
|    git checkout -b <type>/issue-<id>-<name>                            |
|    git commit --allow-empty -m "chore: initialize draft pr for #<id>"   |
|    git push -u origin <type>/issue-<id>-<name>                         |
|    gh pr create --draft (ALL tasks unchecked: - [ ])                   |
+-----------------------------------+------------------------------------+
                                    |
                +-------------------v-------------------+
                | 2. Single-Item Focused Development    |
                |    Only implement the first - [ ]     |
                +-------------------+-------------------+
                                    |
                +-------------------v-------------------+
                | 3. Local Quality Gate & Pre-check     |
                |    mise run check:plan (preview steps)|
                |    mise run check:changed             |
                |    mise run fix (if needed)           |
                |    Domain validations (Mise/River)    |
                +-------------------+-------------------+
                                    |
                +-------------------v-------------------+
                | 4. Local Atomic Commit                |
                |    git add <files>                    |
                |    git commit -m "<type>(<scope>): ..."|
                |    (Keep commit local)                |
                +-------------------+-------------------+
                                    | (Remaining tasks?)
                                    +-------- Yes -------+
                                    | No                 |
+-----------------------------------v-------------------+|
| 5. Unified Push, Checks & Merge                       ||
|    git push origin <branch>                           ||
|    gh pr edit --body (check all - [x])                ||
|    gh pr checks (verify PR CI status)                 ||
|    gh pr ready (mark as ready for review)             ||
|    gh pr merge --squash --delete-branch               ||
+-------------------------------------------------------+|
                                    ^                    |
                                    +--------------------+
```

---

## 3. Detailed Execution Steps

### Phase 1: Pre-Code Initialization (MANDATORY BEFORE ANY CODE)
```bash
# 1. Inspect issue details and requirements
gh issue view <issue_id>

# 2. Create a standardized feature/fix branch
git checkout -b <type>/issue-<issue_id>-<short-description>
# Examples:
#   git checkout -b feat/issue-1-github-alerts
#   git checkout -b fix/issue-4-thinkpad-fan-perm

# 3. Initialize branch with an empty commit and push to remote
git commit --allow-empty -m "chore: initialize draft pr for issue #<issue_id>"
git push -u origin <type>/issue-<issue_id>-<short-description>

# 4. Open Draft PR with ALL tasks UNCHECKED (- [ ])
gh pr create --draft \
  --title "<type>(<scope>): <concise description> (#<issue_id>)" \
  --body "Closes #<issue_id>

### Implementation Tasks
- [ ] 1. Core script / collector / configuration setup
- [ ] 2. UI / Widget implementation (e.g. QML Panel or Hyprland rules)
- [ ] 3. Quality checks, formatting & shell/bootstrap integration"
```

---

### Phase 2: Single-Item Execution Loop
For each unchecked `- [ ]` task in order:
1. **Code ONLY Task N**: Focus strictly on the topmost unchecked `- [ ]` item. Do not start work on subsequent tasks early.
2. **Quality Gate & Pre-check**:
   ```bash
   # Preview execution plan for modified files
   mise run check:plan

   # Run linters/checkers across changed/staged/untracked files
   mise run check:changed

   # Auto-fix formatting if needed
   mise run fix

   # For structured diagnostics:
   hk run check --safe --format jsonl
   ```
3. **Domain-Specific Verification**:
   - **Mise tasks (`mise.toml`)**:
     ```bash
     mise tasks validate
     ```
   - **Mise bootstrap plan**:
     ```bash
     mise bootstrap plan
     ```
4. **Local Atomic Commit**:
   Keep commits strictly atomic (one commit per `- [ ]` task) and keep them **local** during intermediate steps:
   ```bash
   git add <modified_files>
   git commit -m "<type>(<scope>): complete task N (#<issue_id>)"
   ```

---

### Phase 3: Finalize, Unified Push & Merge
Once all tasks in the checklist are completed:
```bash
# 1. Push all completed atomic commits in one unified push
git push origin <branch>

# 2. Update Draft PR body to check off all completed tasks (- [x])
gh pr edit --body "Closes #<issue_id>

### Implementation Tasks
- [x] 1. Core script / collector / configuration setup
- [x] 2. UI / Widget implementation
- [x] 3. Quality checks, formatting & shell/bootstrap integration"

# 3. Verify PR CI checks
gh pr checks

# 4. Mark PR ready for review
gh pr ready

# 5. Squash merge and delete remote/local branch
gh pr merge --squash --delete-branch
```
