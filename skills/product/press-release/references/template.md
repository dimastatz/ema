# Press Release Template

Use this structure exactly. Replace every `[placeholder]` with real content.
No placeholder may appear in the final output.

---
FOR IMMEDIATE RELEASE

──────────────────────────────────────────────────────────────────

[PRODUCT NAME] [VERSION] [Headline: top 1–2 benefits in plain English]

[CITY, DATE] — [Company Name] today announced [Product] [Version],
[one sentence: what it is and why it matters to the business].

WHY IT MATTERS

[2–3 sentences. Who benefits? What problem does this solve?
What can customers do now that they couldn't do before?
No jargon. Write for a VP of Engineering or a CFO.]

WHAT'S NEW IN [VERSION]

[4–6 bullets. Format: **Bold technical label** — plain-English benefit.
Each bullet is one line. Benefits are specific, not vague.]

• **[Feature name]** — [What it means for the user or business]
• **[Feature name]** — [What it means for the user or business]
• **[Feature name]** — [What it means for the user or business]
• **[Feature name]** — [What it means for the user or business]

QUOTE

"[2–3 sentences. Focus on customer impact or team achievement.
Sound like a real person — opinionated, specific, grounded.
No buzzwords.]"
— [Name], [Title], [Company Name]

TECHNICAL DETAILS

• Requires Java [version]+
• Breaking changes: [list specific changes, or "None"]
• Migration guide: [URL]
• Full changelog: [URL]
• [X] commits · [N] contributors · since [previous version]

AVAILABILITY

[Product] [Version] is available today via [distribution channel].
Visit [URL] to download or update.

ABOUT [COMPANY NAME]

[2 sentences. What the company does, who it serves. Factual, not marketing.]

###

Media contact: [Name] | [email] | [phone]
---

## Placeholder reference

| Placeholder | Source |
|---|---|
| `[PRODUCT NAME]` | `CLAUDE.md` → product name, or ask user |
| `[VERSION]` | User input |
| `[CITY, DATE]` | City from `CLAUDE.md`, date from MCP `release_date` |
| `[Company Name]` | `CLAUDE.md` → company name, or ask user |
| `[Name], [Title]` | `CLAUDE.md` → CTO/VP name and title, or use placeholder |
| `[X] commits · [N] contributors` | MCP `total_commits`, `contributor_count` |
| `[previous version]` | MCP `previous_version` |
| `[URL]` | Ask user or use `[URL — add before publishing]` |
| `[distribution channel]` | `CLAUDE.md` → e.g. "Maven Central", "GitHub Releases" |