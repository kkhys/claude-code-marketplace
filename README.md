# Claude Code Marketplace

> A personal Claude Code plugin marketplace for custom development workflows and tooling

## Overview

This repository serves as a personal Claude Code plugin marketplace designed to enhance development efficiency. It provides custom toolsets for knowledge management, automation, and streamlined development workflows.

Claude Code plugin marketplaces support centralized plugin discovery, version tracking, automatic updates, and multiple source types (Git repositories, local paths, etc.).

## Plugins

| Plugin | Description |
|---|---|
| `base` | Git/PR workflow skills (commit conventions, PR creation, review handling, PR babysitting), memo and knowledge management, event hooks, and MCP server configs |
| `writing` | Review agents for blog posts and articles (structure, language, readability, technical accuracy), orchestrated by the `reviewing-content` skill |

## Features

- **Efficient Knowledge Management**: Dedicated skills for memo creation and document management
- **Custom Hooks**: Event-driven automation for development workflows
- **MCP Server Integration**: External tool integrations to extend Claude Code capabilities
- **Version Control**: Safe plugin updates with semantic versioning
- **Easy Installation**: One-command marketplace and plugin installation

## Installation

### 1. Add the Marketplace

Run the following command in Claude Code:

```shell
/plugin marketplace add kkhys/claude-code-marketplace
```

### 2. Install Plugins

```shell
/plugin install base@my-marketplace
/plugin install writing@my-marketplace
```

### 3. Verify Installation

```shell
/plugin list
```

## Usage

### Managing Marketplaces

```shell
# List all marketplaces
/plugin marketplace list

# Update a marketplace
/plugin marketplace update my-marketplace

# Remove a marketplace
/plugin marketplace remove my-marketplace
```

### Managing Plugins

```shell
# List installed plugins
/plugin list

# Enable/disable plugins
/plugin enable base@my-marketplace
/plugin disable base@my-marketplace

# Uninstall a plugin
/plugin uninstall base@my-marketplace
```

## Development

### Testing Locally

To test the marketplace locally:

```shell
# Add the marketplace
/plugin marketplace add ./path/to/claude-code-marketplace

# Install a plugin
/plugin install base@my-marketplace

# Test the plugin
/creating-memo "Test memo"  # Run a skill from the base plugin
```

### Validating the Marketplace

Validate JSON syntax and marketplace structure. The marketplace check does not cover individual plugin manifests, so validate those separately:

```bash
claude plugin validate . --strict
claude plugin validate ./plugins/base --strict
claude plugin validate ./plugins/writing --strict

find plugins -name '*.sh' -print0 | xargs -0 -r shellcheck
python3 -m compileall -q plugins

bash plugins/base/skills/babysitting-pr/scripts/test-pr-watch.sh
bash plugins/base/skills/fixing-review-comments/scripts/test-reply-to-review-threads.sh
```

Or from within Claude Code:

```shell
/plugin validate .
```

These same checks run in CI via `.github/workflows/validate.yml`.

### Adding New Plugins

Custom slash commands are merged into skills, so plugins use `skills/`, not `commands/`.

1. **Create plugin directory**:
   ```bash
   mkdir -p plugins/your-plugin/.claude-plugin
   mkdir -p plugins/your-plugin/skills
   ```

2. **Create plugin manifest** (`plugins/your-plugin/.claude-plugin/plugin.json`):
   ```json
   {
     "$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
     "name": "your-plugin",
     "displayName": "Your Plugin",
     "description": "Description of your plugin",
     "version": "1.0.0",
     "author": {
       "name": "Your Name",
       "email": "your.email@example.com"
     },
     "homepage": "https://github.com/kkhys/claude-code-marketplace",
     "repository": "https://github.com/kkhys/claude-code-marketplace",
     "license": "MIT",
     "keywords": ["example"]
   }
   ```

3. **Add to marketplace** (`.claude-plugin/marketplace.json`):
   ```json
   {
     "plugins": [
       {
         "name": "your-plugin",
         "source": "./plugins/your-plugin",
         "description": "Brief description of your plugin",
         "category": "workflow",
         "tags": ["example"]
       }
     ]
   }
   ```

   When renaming or removing an entry, add the old name to the top-level `renames` map so existing users migrate automatically.

4. **Validate and test**:
   ```shell
   /plugin validate .
   /plugin marketplace update my-marketplace
   /plugin install your-plugin@my-marketplace
   ```

## Auto-Installation in Project Settings

To make this marketplace automatically available for your team, add it to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "my-marketplace": {
      "source": {
        "source": "github",
        "repo": "kkhys/claude-code-marketplace"
      }
    }
  },
  "enabledPlugins": {
    "base@my-marketplace": true
  }
}
```

## Note on claude-plugins-official

For features available in [claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (e.g. MCP servers), prefer the official plugins. Currently installed official plugins:

- `slack@claude-plugins-official`
- `ralph-loop@claude-plugins-official`
- `code-review@claude-plugins-official`
- `code-simplifier@claude-plugins-official`
- `security-guidance@claude-plugins-official`
- `pr-review-toolkit@claude-plugins-official`
- `frontend-design@claude-plugins-official`
- `claude-md-management@claude-plugins-official`

See [settings.json](https://github.com/kkhys/dotfiles/blob/main/.config/claude/settings.json) for the full list of installed plugins.

## License

This marketplace and its included plugins are intended for personal use.
