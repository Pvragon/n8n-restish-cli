# n8n-restish-cli

A lightweight n8n CLI setup using [Restish](https://rest.sh/) and n8n's official OpenAPI spec. Covers the **full public API surface** — workflows, executions, credentials, tags, users, variables, data tables, projects, and security audits.

No code generation. No build step. No MCP server. Restish reads the bundled OpenAPI spec and gives you named subcommands for every endpoint.

## Why this exists

n8n's built-in CLI (`n8n execute`, `n8n export:workflow`, etc.) operates directly on the database — it requires local access to the n8n data directory and doesn't work remotely. Community MCP servers exist (33 tools) but add unnecessary overhead for what is fundamentally REST API access.

This setup gives you full remote API access in ~0.6s per call:

| Capability | n8n Built-in CLI | n8n MCP Server | This |
|---|---|---|---|
| Remote access | No (local DB only) | Yes | **Yes** |
| Workflow CRUD | Export/import only | Yes | **Yes** |
| Executions (list/retry/stop) | Execute only | List/get/delete | **Full (list/get/delete/retry/stop)** |
| Credentials | Export/import | Partial | **Full CRUD** |
| Tags | No | Yes | **Yes** |
| Users | No | Yes | **Yes** |
| Data Tables | No | No | **Yes** |
| Projects | No | Yes (enterprise) | **Yes (enterprise)** |
| Security Audit | Yes | Yes | **Yes** |
| Speed | Instant (local) | ~2-5s (MCP overhead) | **~0.6s per call** |
| Token cost (AI agents) | N/A | High (schema in context) | **Low (JSON in/out)** |
| Dependencies | n8n installation | Node.js + MCP server | **Single binary** |

## Setup

### 1. Install Restish

```bash
# Linux (amd64)
gh release download --repo rest-sh/restish --pattern 'restish-*-linux-amd64.tar.gz' --dir /tmp
tar -xzf /tmp/restish-*-linux-amd64.tar.gz -C /tmp
mv /tmp/restish ~/.local/bin/restish
chmod +x ~/.local/bin/restish

# macOS (Apple Silicon)
gh release download --repo rest-sh/restish --pattern 'restish-*-darwin-arm64.tar.gz' --dir /tmp
tar -xzf /tmp/restish-*-darwin-arm64.tar.gz -C /tmp
mv /tmp/restish /usr/local/bin/restish

# Or via Homebrew
brew install restish
```

### 2. Get your n8n API key

In your n8n instance: **Settings → API → Create API Key**

### 3. Run setup

```bash
git clone https://github.com/Pvragon/n8n-restish-cli.git
cd n8n-restish-cli
./setup.sh https://your-n8n-instance.com YOUR_API_KEY
```

Or configure manually — copy `apis-template.json` into `~/.config/restish/apis.json`, replace the placeholders, and copy `n8n-openapi.json` to `~/.config/restish/`.

### 4. Verify

```bash
restish n8n                          # List all available commands
restish n8n get-api-v1-workflows     # List your workflows
```

## Usage

### Workflows

```bash
# List all workflows
restish n8n get-api-v1-workflows

# Get a specific workflow
restish n8n get-api-v1-workflows-id WORKFLOW_ID

# Create a workflow from JSON
restish n8n post-api-v1-workflows <workflow.json

# Update a workflow
restish n8n put-api-v1-workflows-id WORKFLOW_ID <updated.json

# Activate / deactivate
restish n8n post-api-v1-workflows-id-activate WORKFLOW_ID
restish n8n post-api-v1-workflows-id-deactivate WORKFLOW_ID

# Delete a workflow
restish n8n delete-api-v1-workflows-id WORKFLOW_ID
```

### Executions

```bash
# List recent executions
restish n8n get-api-v1-executions

# Get a specific execution
restish n8n get-api-v1-executions-id EXECUTION_ID

# Retry a failed execution
restish n8n post-api-v1-executions-id-retry EXECUTION_ID

# Stop a running execution
restish n8n post-api-v1-executions-id-stop EXECUTION_ID

# Delete an execution
restish n8n delete-api-v1-executions-id EXECUTION_ID
```

### Credentials

```bash
# List all credentials
restish n8n get-credentials

# Get credential schema for a type
restish n8n get-api-v1-credentials-schema-credential-type-name httpHeaderAuth

# Create a credential
restish n8n create-credential <credential.json

# Delete a credential
restish n8n delete-credential CREDENTIAL_ID
```

### Tags

```bash
# List tags
restish n8n get-api-v1-tags

# Create a tag
echo '{"name": "production"}' | restish n8n post-api-v1-tags

# Tag a workflow
echo '{"tags": [{"id": "TAG_ID"}]}' | restish n8n put-api-v1-workflows-id-tags WORKFLOW_ID
```

### Triggering Workflows

The n8n public API doesn't have a "run workflow" endpoint. Use webhooks instead:

```bash
# If your workflow has a Webhook trigger node:
curl -X POST https://your-n8n.com/webhook/YOUR_WEBHOOK_PATH \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
```

### Users & Admin

```bash
# List users
restish n8n get-api-v1-users

# Run security audit
restish n8n post-api-v1-audit
```

### Data Tables

```bash
# List data tables
restish n8n list-data-tables

# Get rows
restish n8n get-data-table-rows DATA_TABLE_ID

# Insert rows
echo '{"data": [{"column1": "value1"}]}' | restish n8n insert-data-table-rows DATA_TABLE_ID
```

## How it works

Restish is a generic REST client that reads OpenAPI specs. This repo bundles n8n's official OpenAPI v3 spec (from `n8n-io/n8n` on GitHub), pre-resolved into a single JSON file so Restish can load it without chasing `$ref` links across multiple YAML files.

The spec covers 37 endpoints across 10 API domains. When n8n adds new public API endpoints, re-bundle the spec to pick them up:

```bash
npx @redocly/cli bundle \
  https://raw.githubusercontent.com/n8n-io/n8n/master/packages/cli/src/public-api/v1/openapi.yml \
  -o n8n-openapi.json
```

## For AI agents (Claude Code, etc.)

This CLI is designed to work well with AI coding agents:

- **Low token cost**: Restish returns clean JSON, not verbose MCP tool schemas
- **No context pollution**: No MCP server means no tool definitions loaded into the agent's context window
- **Composable**: Pipe JSON in/out, combine with `jq`, wrap in scripts
- **Use Context7 for docs**: Instead of installing an n8n MCP knowledge base, query n8n docs via Context7 (23K+ code snippets available)

## Known limitations

- **No "run workflow" endpoint** in the public API. Trigger workflows via webhooks or the internal API.
- **Execution details are limited.** The public API returns execution status but not detailed error messages or node-level output. Check the n8n UI for debugging.
- **Enterprise endpoints** (variables, projects) require an n8n Enterprise license.

## License

MIT
