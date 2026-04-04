---
name: one-on-one
description: "Prepare data-driven 1-on-1 agendas. Use when: preparing for one-on-one meetings, building agendas with recent activity context."
---

# One-on-One Preparation

Builds data-driven 1-on-1 agendas by fetching GitHub and Jira activity for the team member.

## Workflow

1. Fetches GitHub commits and PR activity
2. Pulls Jira ticket progress and blockers
3. Identifies key discussion points
4. Builds structured agenda
5. Outputs meeting prep document

## Usage

Provide team member name or email. Specify meeting date range (typically last 2 weeks since last 1-on-1).
