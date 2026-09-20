---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git status:*), Bash(gh issue view:*), Bash(gh issue list:*), Bash(gh issue comment:*), Bash(grep:*), Bash(date:*), Bash(cat:*)
description: Review code changes on the current branch
---

Review the current branch's changes by launching two fresh review agents in parallel. Follow these steps precisely.

**CRITICAL: The main session must do MINIMAL work.** Your job is to discover paths and names, then delegate. Do NOT read the diff, the plan file, the issue body, any source files, any test files, or any CLAUDE.md files. All reading must be done by the fresh review agents so they have uncontaminated context. If you find yourself about to use the Read tool, stop — delegate to the agents instead.

## Step 1 — Minimal discovery (paths and names only)

1. Get the current branch name: `git rev-parse --abbrev-ref HEAD`
2. Check if there is any diff at all. If `git diff main...HEAD --name-only` AND `git diff --name-only` AND `git diff --cached --name-only` are all empty, report "Nothing to review — branch is identical to main." and stop.
3. Get the list of modified file paths (from the commands above). Keep this list — you'll pass it to the agents. Do NOT read the files themselves.
4. Find the plan file path: use Glob with pattern `plans/*<branch-name>*.md`. Note the path (or `none`). Do NOT read it.
5. Find the linked GitHub issue number. **This is wanted whether or not a plan file exists** — the plan is where the findings are recorded, the issue is where they are seen.
   - If a plan file was found, take the number from the plan's own `Closes` line *without reading the file*: `grep -m1 -oE 'Closes \[?#[0-9]+' <plan path>`. That is a name, not content — it does not count as reading the plan.
   - Otherwise, if the branch name starts with a number (e.g. `123-fix-thing`), that's the issue number
   - Otherwise run `gh issue list --search "<branch-name>" --state open --limit 3` and note the most relevant issue number (or `none`). Do NOT call `gh issue view`.
6. Derive the list of CLAUDE.md paths to check: always include `CLAUDE.md` at the repo root. For each directory containing a modified file, include `<dir>/CLAUDE.md` if it exists (check with Glob, do NOT read). Pass the final list of paths to the agents.
7. Get today's date, for dating the record in Step 3: `date +%Y-%m-%d`.

## Step 2 — Launch two review agents in parallel

Launch both agents in a single message using the Agent tool. Both must be fresh agents (not subagent_type Explore — use general-purpose so they get a clean context).

### Agent 1 — Code Review

Provide this agent with the branch name, base branch, the plan file path OR issue number (if found), and the list of CLAUDE.md file paths. Include these instructions in the agent prompt:

```
You are performing a code review of branch "<BRANCH>" against base branch "main".

SPEC ANCHOR (use for requirements review):
- Plan file: <PATH or "none">
- GitHub issue: <NUMBER or "none">

If a plan file exists, read its Context, Requirements, and Verification sections. IGNORE the implementation steps — judge outcomes, not process. If a GitHub issue exists instead, read it with `gh issue view <NUMBER>`.

CLAUDE.md files to read: <LIST OF PATHS>

STEPS:
1. Read the spec anchor (plan or issue) if one exists
2. Read all listed CLAUDE.md files
3. Gather the full diff:
   - git diff main...HEAD (committed changes)
   - git diff (unstaged changes)
   - git diff --cached (staged changes)
4. Review the diff for:
   a. REQUIREMENTS — does the implementation fulfil the stated goals/acceptance criteria from the plan or issue? (Skip if no spec anchor)
   b. BUGS — obvious bugs introduced by this branch. Not nitpicks, not pre-existing issues, not things a linter/typechecker would catch.
   c. CLAUDE.md COMPLIANCE — do the changes follow the project guidance in CLAUDE.md?
   d. DRY & BEST PRACTICES — is the code free of unnecessary repetition? Are there opportunities to reuse existing functions or utilities already in the codebase? Does it follow established patterns?
   e. BUILD INTEGRITY — do the changes look like they would break the build? Do NOT run tests or builds.

DO NOT FLAG:
- Pre-existing issues not introduced by this branch
- Nitpicks a senior engineer wouldn't call out
- Things a linter/typechecker/compiler would catch (imports, types, formatting)
- General code quality opinions unless CLAUDE.md explicitly requires them
- Issues on lines not modified in this branch

OUTPUT FORMAT:
Return a numbered list of findings ordered by severity (most severe first). For each finding:
- Severity label: CRITICAL, WARNING, or SUGGESTION
- Brief description
- File path and line number(s)

If no issues found, return: "No issues found."
```

### Agent 2 — Test Review

Provide this agent with the branch name, base branch, and the list of modified source files. Include these instructions in the agent prompt:

```
You are reviewing the test changes on branch "<BRANCH>" against base branch "main".

Modified source files: <LIST>

STEPS:
1. Gather the test diff: git diff main...HEAD -- tests/
2. Also check for unstaged/staged test changes: git diff -- tests/ and git diff --cached -- tests/
3. Read the modified test files in full to understand the complete test context
4. Read the corresponding source files that are being tested to understand what the tests should cover

Review for:
a. COVERAGE GAPS — are new or changed code paths covered by tests? Flag important paths that lack tests.
b. TEST SIMPLICITY — are the tests straightforward and well-focused? Flag over-engineered, unnecessarily complex, or hard-to-follow tests.
c. RATIONALISATION — could existing tests be simplified or consolidated without reducing coverage? Flag redundant or overlapping tests that test the same thing in different ways.
d. PROPORTIONALITY — is the volume of tests appropriate for the changes? Too many tests are a maintenance burden. Prefer fewer, clearer tests that cover the important paths.

GUIDING PRINCIPLE: Prefer fewer, clearer tests that cover the important code paths over exhaustive test suites that are expensive to maintain. Tests should be rationalised wherever possible without reducing actual coverage.

DO NOT FLAG:
- Pre-existing test issues not introduced by this branch
- Minor style nitpicks
- Missing tests for trivial code (simple getters, pass-through wrappers)

OUTPUT FORMAT:
Return a numbered list of findings ordered by severity (most severe first). For each finding:
- Severity label: CRITICAL, WARNING, or SUGGESTION
- Brief description
- File path and line number(s)

If no issues found, return: "No issues found."
```

## Step 3 — Record the findings in the plan file (APPEND ONLY)

**Skip this step if there is no plan file.** Where there is one, it is the durable home for a
review: the convention is a dated `## Review pass` section at the foot, and recent plans in
these repositories all carry one. A review that exists only in the terminal is a review that
gets lost at the next context reset.

**Append only. Never rewrite, re-order or delete existing text, and never open the plan for
editing** — a plan can run well past a thousand lines and this session has deliberately not
read it. Use one shell append with a **quoted** heredoc (`<<'REVIEW'`), so nothing in the
agents' output is interpolated by the shell:

```bash
cat >> <PLAN PATH> <<'REVIEW'

## Review pass — <YYYY-MM-DD>

Findings from `/review-branch` on branch `<BRANCH>`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact. Work through them and annotate each with
what was done — fixed, or rejected and why. A finding that turns out to be wrong should say so
here rather than be deleted.

### Code

<AGENT 1 FINDINGS, VERBATIM>

### Tests

<AGENT 2 FINDINGS, VERBATIM>
REVIEW
```

Rules for what goes in:

- **Verbatim.** Do not summarise, re-order or soften what the agents returned, and do not
  merge the two lists.
- **No dispositions.** Nothing has been done about these findings yet, so the section must not
  claim anything was fixed. Dispositions are added later, by you or on your explicit
  instruction, as each is handled — never by the review run itself. Note that the "annotate
  each with what was done" line above is part of the text being written *into the plan*,
  addressed to whoever reads it later. It is not a to-do list for this run.
- **Date every pass.** A second run appends a second `## Review pass — <date>` section rather
  than touching the first. Two dated passes are an honest record; an overwritten one is not.
- **Record a clean review too.** If both agents returned "No issues found", still append the
  section saying so. That a review ran on a date and found nothing is worth knowing.

## Step 4 — Report results, then point the issue at the record

Combine both agents' findings and present them to the user in this format. The summary should come from what the agents report (they read the diff; you did not). Do not attempt to write your own summary of the changes.

```
### Branch review: <branch-name>

Reviewed against: <plan file path, issue number, or "no linked spec">

#### Code

<Agent 1 findings — numbered list as returned>

#### Tests

<Agent 2 findings — numbered list as returned>
```

Then tell the user where the durable record went: the plan file path and the
`## Review pass — <date>` heading appended to it, or that there was no plan file to write to.

If a GitHub issue was found in Step 1, post the review as a comment on that issue using
`gh issue comment <NUMBER> --body "..."`. **When a plan file exists, the comment carries the
findings *and* names the plan file and its new `## Review pass — <date>` section** — the
durable home is written first and the issue points at it, not the other way round. Confirm to
the user that the comment was posted, with a link to the issue.
