# Claude Code Marketplace

> A personal Claude Code plugin marketplace for custom development workflows and tooling

## Overview

This repository serves as a personal Claude Code plugin marketplace designed to enhance development efficiency. It provides custom toolsets for knowledge management, automation, and streamlined development workflows.

Claude Code plugin marketplaces support centralized plugin discovery, version tracking, automatic updates, and multiple source types (Git repositories, local paths, etc.).

## Features

- **Efficient Knowledge Management**: Dedicated commands for memo creation and document management
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
/memo "Test memo"  # Run a command from the base plugin
```

### Validating the Marketplace

Validate JSON syntax and marketplace structure:

```bash
claude plugin validate .
```

Or from within Claude Code:

```shell
/plugin validate .
```

### Adding New Plugins

1. **Create plugin directory**:
   ```bash
   mkdir -p plugins/your-plugin/.claude-plugin
   mkdir -p plugins/your-plugin/commands
   ```

2. **Create plugin manifest** (`plugins/your-plugin/.claude-plugin/plugin.json`):
   ```json
   {
     "name": "your-plugin",
     "description": "Description of your plugin",
     "version": "1.0.0",
     "author": {
       "name": "Your Name",
       "email": "your.email@example.com"
     }
   }
   ```

3. **Add to marketplace** (`.claude-plugin/marketplace.json`):
   ```json
   {
     "plugins": [
       {
         "name": "your-plugin",
         "source": "./plugins/your-plugin",
         "description": "Brief description of your plugin"
       }
     ]
   }
   ```

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

## License

This marketplace and its included plugins are intended for personal use.
