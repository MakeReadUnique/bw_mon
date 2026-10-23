# Issue tracker: GitHub

Issues, specs, and Wayfinder maps for this repo live in [MakeReadUnique/bw_mon GitHub Issues](https://github.com/MakeReadUnique/bw_mon/issues). Use the `gh` CLI. GitHub is the canonical tracker; migrated local Markdown records are read-only archives.

## Conventions

- Use `--repo MakeReadUnique/bw_mon` for `gh issue` and `gh label` operations when repository inference is ambiguous.
- Create: `gh issue create --repo MakeReadUnique/bw_mon --title "..." --body-file /path/to/body.md`.
- Read: `gh issue view <number> --repo MakeReadUnique/bw_mon --json number,title,body,labels,comments,assignees,state`.
- List: `gh issue list --repo MakeReadUnique/bw_mon --state open --limit 100 --json number,title,labels,assignees` with the appropriate label/state filters. Paginate REST queries when listing the full tracker.
- Comment: `gh issue comment <number> --repo MakeReadUnique/bw_mon --body-file /path/to/comment.md`.
- Label: `gh issue edit <number> --repo MakeReadUnique/bw_mon --add-label "..."` or `--remove-label "..."`.
- Close: `gh issue close <number> --repo MakeReadUnique/bw_mon --reason completed` after posting the resolution.
- Write multiline bodies/comments to UTF-8 files and pass `--body-file`; do not interpolate them into shell command text.
- Refer to a ticket by its linked title in human-facing text, never by a bare issue number.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## When a skill says "publish to the issue tracker"

Create a GitHub issue. Do not create a new local `.scratch/` ticket.

## When a skill says "fetch the relevant ticket"

Read the GitHub issue and relevant comments; archived local files are not live state.

## Wayfinding operations

- **Map**: one issue labelled `wayfinder:map`, with Destination, Notes, Decisions so far, Not yet specified, and Out of scope. Keep it an index; detailed resolutions live in child-ticket comments. Do not list open tickets in the map body.
- **Child ticket**: a native GitHub sub-issue of the map, labelled only `wayfinder:<type>` (`research`, `prototype`, `grilling`, or `task`). The body holds the question. Do not add triage labels to maps or decision tickets.
- **Parent relation**: with the installed `gh` 2.95+, use `gh issue create --parent <map> ...` or `gh issue edit <map> --add-sub-issue <child> ...`. REST equivalent: POST `repos/MakeReadUnique/bw_mon/issues/<map>/sub_issues` with numeric `sub_issue_id`.
- **Blocking**: use GitHub native issue dependencies. With the installed CLI, `gh issue edit <child> --add-blocked-by <blocker> --repo MakeReadUnique/bw_mon`. REST equivalent: POST `repos/MakeReadUnique/bw_mon/issues/<child>/dependencies/blocked_by` with numeric `issue_id`.
- REST relationship payloads use an issue's numeric database `id`, obtained with `gh api repos/MakeReadUnique/bw_mon/issues/<number> --jq .id`; it is neither the issue number nor the GraphQL node ID.
- **Frontier**: query the map's native sub-issues, keep open/unassigned children whose blockers are all closed, and choose the first in map order. Fetch children with `gh api --paginate repos/MakeReadUnique/bw_mon/issues/<map>/sub_issues`; inspect native dependencies, not stale body text. If using a dependency summary, verify its count semantics before treating it as the open-blocker gate.
- **Claim**: before working on a ticket, assign it to the driving dev (`gh issue edit <number> --repo MakeReadUnique/bw_mon --add-assignee @me`). An assignee is the claim.
- **Resolve**: post an answer as a resolution comment, close the ticket, and append one linked-title gist to the map's Decisions so far. Link research/prototype assets from the resolution, rather than copying them into the map.
- Only if the tracker demonstrably lacks native relationships may a documented body convention be used. Native sub-issues and dependencies are available for this migration.

## Migrated local records

The existing `.scratch/bw-mon-architecture/` records are retained as an archive with links to their GitHub replacements. Continue all claims, resolutions, comments, and dependencies on GitHub.
