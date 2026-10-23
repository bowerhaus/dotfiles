---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git status:*), Bash(git ls-files:*), Bash(gh issue view:*), Bash(gh issue list:*), Bash(gh issue comment:*), Bash(gh issue create:*), Bash(grep:*), Bash(date:*), Bash(cat:*)
description: Review code changes on the current branch
---

Review the current branch's changes by launching two fresh review agents in parallel. Follow these steps precisely.

**CRITICAL: Until both agents have returned, the main session must do MINIMAL work.** Your job in Steps 1 and 2 is to discover paths and names, then delegate. Do NOT read the diff, the plan file, the issue body, any source files, any test files, or any CLAUDE.md files. All reading must be done by the fresh review agents so they have uncontaminated context. If you find yourself about to use the Read tool before they return, stop — delegate to the agents instead.

**Once they have returned, the main session reviews the review (Step 3).** The rule above exists to keep the *reviewers'* context clean, and by then it has done its job. Their findings are claims, and some do not survive a look at the code; checking them, and recommending which to fix, is this session's work, not theirs. An agent asked to judge its own findings defends them.

## Step 1 — Minimal discovery (paths and names only)

1. Get the current branch name: `git rev-parse --abbrev-ref HEAD`
2. Check if there is anything to review at all. A branch's changes are **four** lists, not three:
   `git diff main...HEAD --name-only` (committed), `git diff --name-only` (unstaged),
   `git diff --cached --name-only` (staged), and `git ls-files --others --exclude-standard`
   (**untracked**). If all four are empty, report "Nothing to review — branch is identical to main."
   and stop.

   **Untracked files are the easiest way to review a fifth of a branch without noticing.** No form
   of `git diff` reports them, so a branch whose new services, controllers and test files have not
   been staged yet is invisible to all three diff commands. Nothing signals the absence: both agents
   return confident findings on the remainder, and a test-review agent that cannot see four new test
   files will report the new code as untested — the exact opposite of the truth. New files are also
   where the *new* code is, so they are the part least safe to skip.
3. Get the list of changed file paths from all four commands above, untracked included. Keep this
   list — you'll pass it to the agents, marking which paths are untracked. Do NOT read the files
   themselves.
4. Find the plan file path: use Glob with pattern `plans/*<branch-name>*.md`. Note the path (or `none`). Do NOT read it.
5. Find the linked GitHub issue number. **This is wanted whether or not a plan file exists** — the plan is where the findings are recorded, the issue is where they are seen.
   - If a plan file was found, take the number from the plan's own **`Issue:` header** *without reading the file*:
     `grep -m1 -oE '^\*{0,2}(GitHub )?Issue:?\*{0,2} *\[?#[0-9]+' <plan path> | grep -oE '[0-9]+$'`.
     That is a name, not content — it does not count as reading the plan.
   - **Anchor on `Issue:`, never on `Closes`.** They are different fields. A plan's `Issue:` line is its
     reference to the issue; a `Closes #NN` in a plan is prose reminding you what the *PR body* must say,
     and GitHub only acts on it there. Grepping for `Closes` catches it inside longer sentences — one plan's
     only occurrence is a conditional, "in which case `Closes #40`" — so it returns a number that happens to
     be right rather than one that is structurally the plan's. Measured over 38 plans in one repository, the
     `Closes` grep found the issue for 4 of the last 9 plans; the anchored `Issue:` grep found 9 of 9.
     The regex deliberately requires the `#` to follow the label directly, so a loose line such as
     `Issue: see audit §7 — #100` returns nothing rather than a guess.
   - Otherwise, if the branch name starts with a number (e.g. `123-fix-thing`), that's the issue number
   - Otherwise run `gh issue list --search "<branch-name>" --state open --limit 3` and note the most relevant issue number (or `none`). Do NOT call `gh issue view`.
6. Derive the list of CLAUDE.md paths to check: always include `CLAUDE.md` at the repo root. For each directory containing a modified file, include `<dir>/CLAUDE.md` if it exists (check with Glob, do NOT read). Pass the final list of paths to the agents.
7. Get today's date, for dating the record in Step 4: `date +%Y-%m-%d`.

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
3. Gather the full diff. Four parts — the fourth is not a diff, and is the one that gets missed:
   - git diff main...HEAD (committed changes)
   - git diff (unstaged changes)
   - git diff --cached (staged changes)
   - git ls-files --others --exclude-standard (UNTRACKED files). No git diff form shows these.
     Read each one in full and review it as a wholly new file, because that is what it is. A
     branch's new services, controllers and modules commonly sit here unstaged.
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
Return a list of findings ordered by severity (most severe first), numbered C1, C2, C3 …
For each finding:
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
3. AND untracked test files: git ls-files --others --exclude-standard -- tests/ — no git diff form
   shows these, and a whole new suite often lives here. Read each in full. Missing them would have
   you report thoroughly tested code as untested, which is worse than saying nothing.
4. Read the modified test files in full to understand the complete test context
5. Read the corresponding source files that are being tested to understand what the tests should cover

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
Return a list of findings ordered by severity (most severe first), numbered T1, T2, T3 …
For each finding:
- Severity label: CRITICAL, WARNING, or SUGGESTION
- Brief description
- File path and line number(s)

If no issues found, return: "No issues found."
```

## Step 3 — Check every finding against the code, and recommend

Now read. For **every** finding, C and T alike:

1. Open the cited file and lines, and enough around them to judge the claim yourself: the
   callers, the test said to be missing, the plan requirement or CLAUDE.md rule it cites. Use
   `git diff main...HEAD -- <path>` to confirm this branch introduced it.
2. Give it exactly one verdict:
   - **FIX**: real, introduced by this branch, and worth changing before it merges. If only part
     of it is worth doing, mark it **FIX (part)** and say exactly which part.
   - **FOLLOW-UP**: real and worth doing, but not on this branch (it reaches into code the branch
     did not change, or belongs to a later plan). Give it a draft issue title. This is the
     verdict for anything you would otherwise tuck into a SKIP reason as "worth an issue".
   - **SKIP**: real, but not worth changing now (it costs more than the risk it removes, it is
     outside this branch's scope, it is cosmetic). Say which.
   - **NOT REAL**: wrong on inspection (the code already handles it, the test exists, it
     predates the branch, the rule does not say that). Say what you found, with `path:line`.
3. Give one line of reason. Never "consider", never "either": the user will act on the FIX list
   as written, without re-reading the code, so make it the list you would actually fix.

Severity is the agent's label and is not the verdict: a cheap SUGGESTION can be FIX, and a
WARNING can be SKIP. Be willing to overturn an agent; that is the point of this step. If checking
turns up a real problem neither agent raised, add it as `M1`, `M2` … so its source is plain.

**Do not fix anything, or open any issue, in this step**, however small. The user chooses from
the list in Step 5.

## Step 4 — Record the findings in the plan file (APPEND ONLY)

**Skip this step if there is no plan file.** Where there is one, it is the durable home for a
review: the convention is a dated `## Review pass` section at the foot, and recent plans in
these repositories all carry one. A review that exists only in the terminal is a review that
gets lost at the next context reset.

**Append only. Never rewrite, re-order or delete existing text, and never open the plan for
editing**: a plan can run well past a thousand lines. Use one shell append with a **quoted**
heredoc (`<<'REVIEW'`), so nothing in the agents' output is interpolated by the shell:

```bash
cat >> <PLAN PATH> <<'REVIEW'

## Review pass — <YYYY-MM-DD>

Findings from `/review-branch` on branch `<BRANCH>`, **unresolved as written**. Each is a claim
from a review on that date, not an established fact, and each verdict under *Assessment* is a
recommendation, not a decision. Work through them and annotate each with what was done — fixed,
or rejected and why. A finding that turns out to be wrong should say so here rather than be
deleted.

### Code

<AGENT 1 FINDINGS, VERBATIM>

### Tests

<AGENT 2 FINDINGS, VERBATIM>

### Assessment

<STEP 3 VERDICTS: one bullet per finding, by ID — FIX, FIX (part), FOLLOW-UP, SKIP or NOT REAL, and the reason; then any M findings>
REVIEW
```

Rules for what goes in:

- **Verbatim, layout included.** Paste exactly what the agents returned: their numbering,
  bullets and line breaks. Do not reflow a bullet list into a paragraph, summarise, re-order or
  soften it, and do not merge the two lists. If the text needs escaping for the heredoc, that is
  the only change allowed. Where you disagree with them, say so under *Assessment*, never by
  editing their text.
- **No dispositions.** Nothing has been done about these findings yet, so the section must not
  claim anything was fixed. A verdict is a recommendation, not a disposition. Dispositions are
  added later, by you or on your explicit instruction, as each is handled — never by the review
  run itself. Note that the "annotate each with what was done" line above is part of the text
  being written *into the plan*, addressed to whoever reads it later. It is not a to-do list for
  this run.
- **Date every pass.** A second run appends a second `## Review pass — <date>` section rather
  than touching the first. Two dated passes are an honest record; an overwritten one is not.
- **Record a clean review too.** If both agents returned "No issues found", still append the
  section saying so. That a review ran on a date and found nothing is worth knowing.

## Step 5 — Post to the issue, then report, ending with the question

**First, the issue.** If a GitHub issue was found in Step 1, post the review as a comment on it
using `gh issue comment <NUMBER> --body "..."`, the decision block below included. **When a plan
file exists, the comment carries the findings *and* names the plan file and its new
`## Review pass — <date>` section**: the durable home is written first and the issue points at
it, not the other way round. Do this before reporting, so the report can end on the question.

**Then the report**, in this format. Give the agents' findings exactly as they returned them (do
not write your own summary of the changes). Every finding appears in exactly one section of the
decision block, one bullet each: never a run-on line of several items.

```
### Branch review: <branch-name>

Reviewed against: <plan file path, issue number, or "no linked spec">
Recorded in: <plan path> under `## Review pass — <date>` (or "no plan file"); issue comment <link> (or "no issue")

#### Code

<Agent 1 findings — as returned>

#### Tests

<Agent 2 findings — as returned>

---

#### Recommended fixes
- C1 — <what is wrong> (`path:line`): <the fix>
- C5 (part) — <which part, and what is kept>

#### Follow-up issues
- C4 — "<draft issue title>"

#### Skip
- C3 — <why not worth it>

#### Not real
- T1 — <what the code actually does, `path:line`>

Fix C1 and C5 (part), and open the C4 follow-up issue? Reply **yes**, or name the IDs you want.
```

**The decision block always comes last, always in that shape**, so the user can read only it
and answer. FIX entries are ordered most severe first. Write `- none` under an empty section
rather than dropping the heading; if both agents found nothing, the whole block is
`Nothing to fix.`

**The report's very last line is the closing question**, naming every FIX by ID and every
follow-up issue. Leave out the issue clause when there are no follow-ups, and the fix clause when
there are no fixes; when there is neither, there is no question. Nothing comes after it: no
summary, no offer, no sign-off.

## Step 6 — When the user answers

- **"yes"** means every FIX (each FIX (part) as scoped) and every follow-up issue. **Named IDs**
  mean those only. A reply about fixes alone opens no issues: an issue is visible outside this
  machine, so it is opened only when the user has said so.
- Make the fixes, then run the project's tests and lint (from its `CLAUDE.md` *Commands*) and say
  if anything fails.
- Open each confirmed follow-up with `gh issue create`, its body naming the finding, the files,
  and the branch's review pass.
- **Close the record.** If there is a plan file, append the outcomes below that review pass, one
  bullet per finding by ID: what was fixed, the issue number for each follow-up, and *not done*
  with the reason for the rest. Append only, with the same quoted heredoc as Step 4:

  ```bash
  cat >> <PLAN PATH> <<'REVIEW'

  ### Outcome — <YYYY-MM-DD>

  - C1 — fixed: <one line>
  - C4 — follow-up #<NN>
  - C3 — not done: <reason, from the Skip list or the user's reply>
  REVIEW
  ```
