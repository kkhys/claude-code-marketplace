# Claude Code Marketplace

> A personal Claude Code plugin marketplace for custom development workflows and tooling

## Plugins

| Plugin | Description |
|---|---|
| `base` | Git/PR workflow skills (commit conventions, PR creation, review handling, PR babysitting), norms for Japanese technical prose with four specialist audit agents, memo and knowledge management, a terse Japanese output style, event hooks, and MCP server configs |

## Installation

```shell
/plugin marketplace add kkhys/claude-code-marketplace
/plugin install base@my-marketplace
```

To share the marketplace with a project, add it to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "my-marketplace": {
      "source": { "source": "github", "repo": "kkhys/claude-code-marketplace" }
    }
  },
  "enabledPlugins": { "base@my-marketplace": true }
}
```

## Development

Validate and test locally. The marketplace check does not cover individual plugin manifests, so validate those separately:

```bash
claude plugin validate . --strict
claude plugin validate ./plugins/base --strict

find plugins -name '*.sh' -print0 | xargs -0 -r shellcheck
python3 -m compileall -q plugins

bash plugins/base/skills/babysitting-pr/scripts/test-pr-watch.sh
bash plugins/base/skills/fixing-review-comments/scripts/test-reply-to-review-threads.sh
```

The same checks run in CI via `.github/workflows/validate.yml`.

See [CLAUDE.md](./CLAUDE.md) for the repository layout, plugin anatomy, and conventions for adding skills, hooks, agents, output styles, and new plugins.

## License

This marketplace and its included plugins are intended for personal use.

Some `base` skills are adapted from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT), [openai/codex](https://github.com/openai/codex) (Apache-2.0), and [k16shikano's gists](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d) (Unlicense) — see [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md).
