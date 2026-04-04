# EMA — Engineering Manager Assistant

> An open-source Claude Code toolkit that gives engineering managers AI-assisted workflows for their most time-consuming recurring tasks.

EMA is a single shared MCP server + a library of skills any team can clone and customise. It connects to GitHub, Jira, Slack, Calendar, and PagerDuty, and can run interactively or as a fully autonomous agent in CI/CD.

---

## What it does

| Invoke | What happens |
|---|---|
| `"write the press release for v4.2.0"` | Fetches commits since last tag, categorises changes, writes dual-audience press release |
| `"review this PR: github.com/org/repo/pull/42"` | Fetches diff, applies team review checklist, outputs structured feedback |
| `"run the retro for this sprint"` | Pulls sprint data from Jira, surfaces blockers, generates action items |
| `"prep my 1-on-1 with Alice"` | Fetches GitHub + Jira activity, builds a data-driven agenda |
| `"write perf review for Bob"` | Evidence-based review from 6 months of activity data |
| `"write postmortem for the outage"` | Blameless RCA with structured timeline |
| `"how is the team doing this week"` | Four-dimension health report: delivery, quality, load, morale |
| `"write interview feedback for candidate X"` | Signal-based evaluation with hire recommendation |

---

## Architecture

```
~/.claude/settings.json          ← MCP server registered globally (once)

your-org/
├── ema/                         ← this repo (shared toolkit)
│   ├── mcp/
│   │   ├── server.py            ← FastMCP entry point
│   │   └── tools/
│   │       ├── github.py        ← PRs, releases, engineer activity
│   │       ├── jira.py          ← sprints, velocity, tickets
│   │       ├── slack.py         ← standups, sentiment  [coming soon]
│   │       ├── calendar.py      ← meeting load, 1-on-1s  [coming soon]
│   │       └── pagerduty.py     ← incidents, MTTR  [coming soon]
│   └── skills/
│       ├── product/
│       │   ├── press-release/
│       │   └── sprint-retro/
│       ├── engineering/
│       │   ├── pr-review/
│       │   └── incident-postmortem/
│       └── people/
│           ├── one-on-one/
│           ├── performance-review/
│           ├── team-health/
│           └── hiring-feedback/
│
├── payments-service/            ← your Java repo
│   ├── CLAUDE.md                ← product context + env vars
│   └── skills/                  ← copy only what you need from ema/skills/
│
└── auth-service/                ← another repo, same pattern
    ├── CLAUDE.md
    └── skills/
```

The MCP server is **repo-agnostic** — it learns which repo to query from the `GITHUB_REPO` env var set in each project's `CLAUDE.md`. Skills live in the consuming repo so each team can customise them for their product, audience, and conventions.

---

## Quickstart

### 1. Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) installed (`npm install -g @anthropic-ai/claude-code`)
- Python 3.10+
- A Claude account with API access

### 2. Clone and install

```bash
git clone https://github.com/your-org/ema
cd ema
python -m venv .venv && source .venv/bin/activate
pip install -r mcp/requirements.txt
```

### 3. Configure tokens

```bash
cp .env.example .env
```

Edit `.env` and fill in the tokens you need:

| Variable | Where to get it |
|---|---|
| `GITHUB_TOKEN` | [GitHub → Settings → Developer settings → PAT](https://github.com/settings/tokens) — needs `repo` read |
| `GITHUB_ORG` | Your GitHub org name |
| `JIRA_URL` | `https://your-org.atlassian.net` |
| `JIRA_EMAIL` | Your Atlassian login email |
| `JIRA_TOKEN` | [Atlassian API tokens](https://id.atlassian.com/manage-profile/security/api-tokens) |
| `JIRA_PROJECT` | Your project key, e.g. `PAY` |

### 4. Register the MCP server globally

```bash
claude mcp add ema \
  --command python \
  --args $(pwd)/mcp/server.py
```

This makes the EMA tools available in **every repo** on your machine — you only do this once.

### 5. Set up your repo

In each Java (or any) repo you want to use EMA from:

```bash
# Copy the skills you need
cp -r /path/to/ema/skills/product/press-release  my-repo/skills/
cp -r /path/to/ema/skills/engineering/pr-review  my-repo/skills/

# Copy and customise the context file
cp /path/to/ema/CLAUDE.template.md my-repo/CLAUDE.md
```

Edit `CLAUDE.md` in your repo — fill in your product name, Jira project key, team size, and any conventions. This is what makes EMA know it's working on *your* product.

### 6. Use it

```bash
cd my-repo
claude
```

Then just talk to it:

```
write the press release for v5.0.0
review this PR: https://github.com/acme/payments/pull/88
run the retro for this sprint
prep my 1-on-1 with Alice
```

---

## Running as an autonomous agent

EMA can run fully unattended in CI/CD using Claude Code's non-interactive mode.

### Manual invocation

```bash
claude --dangerously-skip-permissions -p \
  "Write the press release for v4.2.0 and save it to press-releases/v4.2.0.md"
```

### GitHub Actions — auto press release on publish

Add this workflow to your Java repo. Every time you publish a GitHub release, it generates a press release draft and opens a PR for your review.

```yaml
# .github/workflows/press-release.yml
name: Generate press release

on:
  release:
    types: [published]

jobs:
  press-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install EMA
        run: |
          git clone https://github.com/your-org/ema /tmp/ema
          pip install -r /tmp/ema/mcp/requirements.txt
          claude mcp add ema --command python --args /tmp/ema/mcp/server.py

      - name: Generate press release
        run: |
          claude --dangerously-skip-permissions -p \
            "Write the press release for ${{ github.event.release.tag_name }} \
             and save it to press-releases/${{ github.event.release.tag_name }}.md"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITHUB_ORG: ${{ github.repository_owner }}
          GITHUB_REPO: ${{ github.repository }}
          JIRA_URL: ${{ secrets.JIRA_URL }}
          JIRA_EMAIL: ${{ secrets.JIRA_EMAIL }}
          JIRA_TOKEN: ${{ secrets.JIRA_TOKEN }}
          JIRA_PROJECT: ${{ vars.JIRA_PROJECT }}

      - name: Open PR with draft
        uses: peter-evans/create-pull-request@v6
        with:
          title: "Press release: ${{ github.event.release.tag_name }}"
          body: "Auto-generated by EMA. Review and edit before publishing."
          branch: "press-release/${{ github.event.release.tag_name }}"
          commit-message: "Add press release for ${{ github.event.release.tag_name }}"
```

> **Note:** `--dangerously-skip-permissions` allows Claude Code to write files without confirmation prompts. Only use it in trusted CI environments with appropriately scoped tokens.

---

## Skills

Each skill is a `SKILL.md` file that encodes a workflow, output template, and checklist. Copy the ones you need into your repo's `skills/` folder and customise the sections marked **Customisation points**.

| Skill | Trigger | Data sources |
|---|---|---|
| `press-release` | "write press release for vX.Y.Z" | GitHub commits + tags |
| `pr-review` | "review this PR: [url]" | GitHub PR diff |
| `sprint-retro` | "run the retro / how did the sprint go" | Jira sprint |
| `one-on-one` | "prep my 1-on-1 with [name]" | GitHub + Jira |
| `performance-review` | "write perf review for [name]" | GitHub + Jira (6 months) |
| `incident-postmortem` | "write postmortem for the outage" | PagerDuty + EM notes |
| `team-health` | "team health report / how is the team" | GitHub + Jira + Slack |
| `hiring-feedback` | "write interview feedback for [name]" | EM notes (no API needed) |

---

## MCP tools reference

| Tool | Source | Description |
|---|---|---|
| `get_pr_details(url)` | GitHub | Diff, changed files, author, description |
| `get_release_info(repo, version)` | GitHub | Commits between tags, categorised, contributors |
| `get_engineer_activity(username, days?)` | GitHub | PRs authored and reviewed |
| `get_sprint_data(sprint_id?)` | Jira | Velocity, completed/incomplete, blockers |
| `get_team_members()` | Jira | Roster with roles |
| `get_engineer_tickets(name, days?)` | Jira | Done and in-progress tickets |
| `get_standup_messages(channel, days?)` | Slack | *(coming in Session 2)* |
| `get_meeting_load(email, weeks?)` | Calendar | *(coming in Session 2)* |
| `get_oneonone_history(email)` | Calendar | *(coming in Session 2)* |
| `get_incidents(days?)` | PagerDuty | *(coming in Session 2)* |

---

## Project structure

```
ema/
├── README.md
├── CLAUDE.md                    ← EMA's own setup guide
├── CLAUDE.template.md           ← copy this into your repos
├── .env.example                 ← all tokens documented
├── mcp/
│   ├── server.py
│   ├── requirements.txt
│   └── tools/
│       ├── __init__.py
│       ├── github.py
│       ├── jira.py
│       ├── slack.py
│       ├── calendar.py
│       └── pagerduty.py
└── skills/
    ├── product/
    │   ├── press-release/SKILL.md
    │   └── sprint-retro/SKILL.md
    ├── engineering/
    │   ├── pr-review/SKILL.md
    │   └── incident-postmortem/SKILL.md
    └── people/
        ├── one-on-one/SKILL.md
        ├── performance-review/SKILL.md
        ├── team-health/SKILL.md
        └── hiring-feedback/SKILL.md
```

---

## Roadmap

**Session 1 — complete**
- [x] MCP server with modular tool registration
- [x] GitHub tools: PR details, release info, engineer activity
- [x] Jira tools: sprint data, team roster, engineer tickets
- [x] All 8 skills
- [x] CLAUDE.md and CLAUDE.template.md

**Session 2 — planned**
- [ ] Slack tools: standup messages, channel sentiment
- [ ] Google Calendar tools: meeting load, 1-on-1 cadence
- [ ] PagerDuty tools: incidents, MTTR, on-call load
- [ ] `Makefile` for install / lint / test
- [ ] GitHub Actions workflow (bundled in repo)

---

## Contributing

Contributions welcome — especially new skills and additional data source integrations.

1. Fork the repo
2. Add your skill under `skills/<name>/SKILL.md`
3. If adding a new MCP tool, add it to the appropriate module in `mcp/tools/` and register it in `server.py`
4. Open a PR with an example invocation and sample output

---

## Security

- Tokens are stored in `.env` — never commit this file (`.gitignore` it)
- The MCP server runs locally; tokens are only sent to the APIs you configure
- Skills and `CLAUDE.md` contain no secrets and are safe to commit
- When using autonomous agent mode, use the minimum required token scopes

---

## License

MIT
