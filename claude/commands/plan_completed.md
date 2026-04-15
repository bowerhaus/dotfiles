I'm happy that the current changes on this branch fulfil the plan.

## 1. Mark the Plan Complete
Mark the plan as complete and update progress.md in accordance with the rules in CLAUDE.md.

## 2. Documentation Review
Read the plan's Requirements and any Verification sections to understand what changed. Then:

**Coverage check** — for each significant change in the plan, identify whether there is existing documentation that should describe it. Check that the documentation has actually been updated. Flag any gaps.

**Staleness check** — read the docs that touch areas changed by this branch. Look for references to APIs, config keys, commands, file paths, or behaviours that no longer match the code. Flag anything stale.

To find relevant docs: look for a `docs/` folder, a documentation index in CLAUDE.md, a `README.md`, or any `*.md` files alongside the changed source. Use the project's own doc index if one exists — don't guess.

Fix any gaps or stale content you find before proceeding.

## 3. Linting
Check CLAUDE.md for documented lint commands first. If not there, look for lint scripts in the project's build/task files and CI workflows.

Run whatever lint tools the project uses. Fix any issues before committing. If no linting is configured, skip this step.

## 4. Tests
Check CLAUDE.md for the project's test commands. If not documented there, look for test scripts in the project's build/task files and CI workflows.

Run the test suite. If any tests fail, fix them before proceeding — do not commit with failing tests. If no test suite is configured, skip this step.

## 5. Commit and PR
Verify you are on the correct branch for this plan. Stage and commit all changes with a succinct commit message.

Then create a PR. If there is a linked GitHub issue, include a closing keyword in the PR body (e.g. `Closes #123`) so the issue is automatically closed when the PR is merged.

Include in the PR description:
- A summary of what changed
- Confirmation that documentation has been reviewed and updated
- Details of any tests and linting that were run
