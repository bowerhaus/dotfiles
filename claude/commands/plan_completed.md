I'm happy that the current changes on this branch fulfil the plan.

## 1. Mark the Plan Complete
Mark the plan as complete and update progress.md in accordance with the rules in CLAUDE.md.

Name the branch and the PR, but **write the status so that merging cannot invert it**. progress.md is committed inside the very PR whose state it would otherwise describe, so a claim like *"PR #N is open"* or *"next action: merge it"* is written at the only moment it is true and is then frozen into the merge commit. The next context reads it as fact and acts on it.

Three rules, in order of importance:

- **State what is true of the work, never what is true of the PR's review state.** "Plan 12 is complete and PR #35 carries it" survives the merge; "PR #35 is open" cannot. Naming the PR is useful provenance — asserting its state is not.
- **Write the next action so it does not depend on whether the PR has merged.** After this skill that is almost always *the next plan*: merging is the user's action, not the session's, and it does not change what the next session should do. If the next action is the same either way, the ambiguity stops mattering. Only "branch off `main`, or not?" differs, and `git status -sb` settles that in one command.
- **Put the disambiguating check on the line beside the status, not in a block further down.** `gh pr view <n> --json state` — `OPEN` means it has not merged, `MERGED` means `main` carries it. A qualifier a hundred lines below the claim it qualifies does not get read; the status block does, because the page says to read it first.

**Do not make the signal "the branch is merged or gone."** Where branches are never deleted — which is the common case — that condition never fires, and it asks the reader to discover the very fact they are trying to establish.

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
