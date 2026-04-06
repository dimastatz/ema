---
name: press-release
description: "Use this skill whenever the user asks to write, generate, draft, create, or prepare a press release, release announcement, product announcement, or launch post for a software version, major release, or product update. Trigger even for casual phrasing: we shipped v5, write the announcement for v4.2.0, make the release post, draft something for the new version. Always call get_release_info via MCP first to ground the output in real commit data, then follow this skill exactly. Do not write a press release from memory — always fetch data first."
---

# Press Release

Generates dual-audience press releases for product versions by fetching commits since the last tag, categorizing changes, and formatting for both technical and business audiences.

## Workflow

1. Fetches commit history since last tag
2. Categorizes changes (features, fixes, improvements)
3. Generates executive summary
4. Writes technical details section
5. Formats final press release

## Usage

Invoke with version number or tag name. Provide any specific themes or audiences to emphasize.
