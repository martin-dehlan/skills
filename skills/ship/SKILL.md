---
name: ship
description: Take a finished change from the working tree to an open pull request without asking in between - checks, commit, pr-reviewer, PR, watching CI. Manual only; run it as /ship when the change is done.
disable-model-invocation: true
---

# Ship a finished change

Run the whole path from "done" to "PR open and CI watched". Stop only when a step fails.
Never merge; merging is the owner's decision.

1. **State.** `git status` and `git branch --show-current`. On `main` or a branch with
   unrelated changes: create `<type>/<name>` first (app-release: Branches and PRs). Several
   unrelated changes become several branches.
2. **Checks** from the app's CLAUDE.md *Commands*: `dart format .`, `flutter analyze`,
   `flutter test`, `build_runner` when annotations changed, `scripts/check_ui_rules.sh`,
   `check_layers.sh`, `check_file_sizes.sh`, `check_claude_helpers.py`, `check_secrets.sh`.
   A failure: fix it, rerun, continue. Do not report green without running them.
3. **Commit** in Conventional Commits, one logical change per commit, never `--no-verify`.
4. **Review.** Run the `pr-reviewer` agent on the branch. Fix every `[blocker]` and `[should]`,
   commit, run the reviewer again. It records the review for this HEAD (the PR hook needs it).
5. **Push and open the PR:** `git push -u origin HEAD`, then `gh pr create` with a title that
   is the squash commit, a body with summary, `Closes #n` for every issue, and a test plan that
   says what ran and what was only checked in a golden shot or on a device.
6. **Watch checks:** `gh pr checks --watch`. A red check: read the log, fix, push, watch again.
7. **Report** in the user's language: PR link, what ran, what did not, any `Skill candidate:`
   from the reviewer (and whether the rule was added).

Stop and ask only for: a failing step you cannot fix, a missing secret, an issue number you
cannot infer, or a change that touches something the user did not ask for.
