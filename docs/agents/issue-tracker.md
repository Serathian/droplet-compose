# Issue tracker: GitHub

Issues and specs for `droplet-compose` live centrally as GitHub issues in `Serathian/website-stack`. Use the `gh` CLI with `--repo Serathian/website-stack` for all issue operations.

## Conventions

- **Create an issue**: `gh issue create --repo Serathian/website-stack --label app:droplet --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --repo Serathian/website-stack --json number,title,body,labels,comments`.
- **List issues**: `gh issue list --repo Serathian/website-stack --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` (e.g. `--label app:droplet`) and `--state` filters.
- **Make an issue a sub-issue of a parent**: `gh issue create --repo Serathian/website-stack --parent <parent> ...`, or `gh issue edit <parent> --repo Serathian/website-stack --add-sub-issue <child>` afterwards (`gh` 2.94+). Older `gh`: `gh api --method POST repos/Serathian/website-stack/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>` (database id, as in **Blocking** below). Without sub-issues, put `Part of #<parent>` at the top of the child body.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation. Add an edge with `gh issue create --repo Serathian/website-stack --blocked-by <n>,<n> ...` or `gh issue edit <child> --repo Serathian/website-stack --add-blocked-by <blocker>` (`gh` 2.94+). Older `gh`: `gh api --method POST repos/Serathian/website-stack/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/Serathian/website-stack/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Count open blockers**: `gh api repos/Serathian/website-stack/issues/<n> --jq .issue_dependencies_summary.blocked_by` (open blockers only; 0 means startable). `gh issue view <n> --repo Serathian/website-stack --json blockedBy` also lists closed blockers, so filter it: `--jq '[.blockedBy.nodes[] | select(.state == "OPEN")] | length'`.
- **Comment on an issue**: `gh issue comment <number> --repo Serathian/website-stack --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --repo Serathian/website-stack --add-label "..."` / `--remove-label "..."`
- **Close**: post the explanation with `gh issue comment <number> --repo Serathian/website-stack --body "..."`, then `gh issue close <number> --repo Serathian/website-stack`. On an already-closed issue, `gh issue close --comment` drops the comment and still exits 0.

**Do not infer the issue repo from `git remote -v`**: this submodule's `origin` points to `Serathian/droplet-compose`, whereas issues are centralized in `Serathian/website-stack`. Always pass `--repo Serathian/website-stack` (or target `repos/Serathian/website-stack/...` with `gh api`).

File issues only into the user's own repo. Never file into `mattpocock/skills` (the repo these skills come from) unless the user owns it. Before the first `gh issue create` of a session, confirm the target with `gh repo view Serathian/website-stack --json nameWithOwner`.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number>`, then `gh pr view <number> --comments` (off a TTY, `--comments` prints only the comments, not the body), and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh api --paginate 'repos/Serathian/droplet-compose/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`.
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue in `Serathian/website-stack` (typically with `--label app:droplet`).

## When a skill says "fetch the relevant ticket"

Read it from `Serathian/website-stack` as in **Read an issue** above.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue in `Serathian/website-stack` with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --repo Serathian/website-stack --label wayfinder:map --label app:droplet`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (see **Make an issue a sub-issue of a parent**). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: see **Blocking** under Conventions.
- **Frontier query**: list the map's open children (`gh issue list --repo Serathian/website-stack --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (see **Count open blockers**, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --repo Serathian/website-stack --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --repo Serathian/website-stack --body "<answer>"`, then `gh issue close <n> --repo Serathian/website-stack`, then append a context pointer (gist + link) to the map's Decisions-so-far.
