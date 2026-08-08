---
name: creating-task-summary
description: Create a personal activity summary across all GitHub repositories for weekly reports and reflection.
argument-hint: "[period]"
context: fork
background: false
allowed-tools:
  - Bash(gh:*)
  - Bash(date:*)
disable-model-invocation: true
---

# Task Summary

Generate a personal activity summary across all GitHub repositories.

The purpose is reflection — helping the user see the bigger picture of their work, not just producing a mechanical list of links. Synthesize what they focused on, what they accomplished, and what's still in flight.

Today's date: !`date +%Y-%m-%d`

## Workflow

### 1. Determine Time Range

Requested period: $ARGUMENTS

Default: past 7 days if no period is given above. If a different period is specified (e.g., "this month", "last 2 weeks", "3/1 ~ 3/14"), calculate the start date accordingly.

```bash
START_DATE=$(date -v-7d +%Y-%m-%d)
END_DATE=$(date +%Y-%m-%d)
```

### 2. Gather Activity

Run these in parallel across all repositories. Using `--sort updated` with `--updated` captures items that were active during the period — a PR created two weeks ago but merged this week should appear.

```bash
# PRs authored
gh search prs --author "@me" --sort updated \
  --updated ">=${START_DATE}" --limit 100 \
  --json repository,title,url,state,createdAt,mergedAt,number

# Issues authored or assigned
gh search issues --author "@me" --sort updated \
  --updated ">=${START_DATE}" --limit 100 \
  --json repository,title,url,state,createdAt,closedAt,number

# PR reviews given to others
gh search prs --reviewed-by "@me" --sort updated \
  --updated ">=${START_DATE}" --limit 100 \
  --json repository,title,url,state,number,repository,author
```

Dedup: if a PR appears in both "authored" and "reviewed", keep it under "authored" only.

### 3. Daily Activity Chart (for periods of 7+ days)

When the period covers a week or more, fetch daily contribution counts to visualize activity trends. This gives a quick sense of busy vs. quiet days.

```bash
USERNAME=$(gh api user --jq '.login')
gh api graphql \
  -f login="${USERNAME}" \
  -f from="${START_DATE}T00:00:00Z" \
  -f to="${END_DATE}T23:59:59Z" \
  -f query='
query($login: String!, $from: DateTime!, $to: DateTime!) {
  user(login: $login) {
    contributionsCollection(from: $from, to: $to) {
      contributionCalendar {
        weeks { contributionDays { date contributionCount } }
      }
    }
  }
}' --jq '.data.user.contributionsCollection.contributionCalendar.weeks[].contributionDays[] | "\(.date) \(.contributionCount)"'
```

If the query fails, approximate from the PR/issue data by counting items per day based on `createdAt` / `mergedAt` dates.

Render as a simple ASCII bar chart:

```
03/01  ███              3
03/02  █████████        9
03/03  ████████████    12
```

Scale the bars relative to the most active day. Place the chart near the top of the output, right after the heading — it gives an immediate visual overview before the detailed breakdown.

### 4. Synthesize

This is where the summary becomes useful for reflection.

- Identify cross-repo themes (e.g., "infrastructure work" spanning multiple repos is one coherent story, not three separate items)
- Use PR title conventions (conventional commits, scope prefixes) as grouping hints when available, but don't force items into categories that don't fit
- Separate completed work (merged PRs, closed issues) from in-progress work
- Summarize review activity — volume and whose work was reviewed

### 5. PR Title Formatting

Clean up PR titles before including them in the output:

- Strip branch prefixes like `[main]`, `[develop]`, `[release]` — these are merge artifacts, not meaningful content
- Keep conventional commit prefixes (`feat:`, `fix:`, etc.) as they convey intent
- Remove ticket-only titles (e.g., `[develop] #9793 feature/PDQ-1578/TECM-3648`) — replace with the actual PR title or a human-readable description from the PR body
- For release merge PRs like `main -> release`, keep as-is since they describe the action

### 6. Output

```markdown
## Activity Summary (YYYY-MM-DD ~ YYYY-MM-DD)

### Daily Activity

\```
MM/DD  ████████████████  16
MM/DD  ████████          8
MM/DD  ██████████████    14
\```

### [Theme / Feature Area]

[1-2 sentence narrative describing what was accomplished and why it matters]

- [Title](url) — repo-name (merged/open/closed)
- [Title](url) — repo-name (closed)

### [Another Theme]

[Narrative]

- [Title](url) — repo-name (merged)

### Reviews

- [PR Title](url) — repo-name (@author)
- [PR Title](url) — repo-name (@author)

---

**Totals**: X PRs (Y merged), Z issues (W closed), V reviews
**Active repos**: repo-a, repo-b, repo-c
```

### Adapting the Structure

The output structure should match the shape of the data, not a rigid template:

- Single repo with many items → group by feature area, omit repo labels
- Many repos with few items each → repo becomes the primary grouping
- Only a handful of items total → flat list, no forced categorization
- No activity in the period → say so plainly
