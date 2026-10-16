# Configuration

For basic configuration instructions, see [this documentation](https://developers.openai.com/codex/config-basic).

For advanced configuration instructions, see [this documentation](https://developers.openai.com/codex/config-advanced).

For a full configuration reference, see [this documentation](https://developers.openai.com/codex/config-reference).

## MS endpoint overrides (patch/0.163.0)

On the first normal config load, Codex creates `${CODEX_HOME}/ms-config.toml`
if it is missing. The generated file lists the built-in addresses as commented
examples. It is never overwritten. Uncomment a setting to activate it. Keep
ordinary top-level settings above any TOML table header:

```toml
chatgpt_base_url = "https://my-chat.example/backend-api/"
openai_base_url = "https://my-api.example/v1"

[ms_endpoints]
oauth_issuer = "https://my-auth.example"
oauth_token_url = "https://my-auth.example/oauth/token"
turn_costs_url = "https://my-analytics.example/v1/analytics/codex/turn-costs"
```

The MS file merges after user, profile, and project `config.toml` files. CLI
session overrides and enforced managed requirements still take precedence.
Restart Codex or create a new session after changing endpoints. Service URLs must use HTTPS without embedded credentials,
query strings, or fragments. Auth token and revoke URLs default to paths under
`oauth_issuer` when only the issuer is set. A custom remote-control URL must
match the configured base URL exactly before saved credentials are used.
For Agent Identity on a custom backend, set both
`auth_accounts_base_url` and `agent_identity_jwks_base_url`; the latter must
match `chatgpt_base_url`. JWT issuer claim names remain fixed.

The `[ms_endpoints]` entries are `oauth_issuer`, `oauth_token_url`,
`oauth_revoke_url`, `auth_accounts_base_url`, `agent_identity_jwks_base_url`, `realtime_sideband_base_url`,
`decisions_url`, `turn_costs_url`, `metrics_url`, `plugins_export_url`,
`remote_control_base_url`, `mcp_client_metadata_base_url`,
`releases_base_url`, and `installer_url`. Existing configuration such as
`experimental_realtime_ws_base_url` and `[otel]` may also be overridden here.
The standalone Unix and PowerShell installers read the quoted
`ms_endpoints.releases_base_url` entry directly.

### Linux amd64 patch build

Pushing `patch/0.163.0` runs the `patch-linux-amd64` GitHub Actions workflow.
Its `codex-cli-linux-amd64` artifact contains a `tar.gz` Codex package and
SHA-256 checksum. Extract the archive and run `bin/codex` from the extracted
package. Keep the `bin`, `codex-resources`, and `codex-path` directories together:
the code mode host, Linux sandbox helper, and ripgrep are required at runtime.
The GNU build targets Ubuntu 24.04 and other compatible Linux amd64 systems;
the workflow checks that no shared libraries are missing on its runner.

## Lifecycle hooks

Admins can set top-level `allow_managed_hooks_only = true` in
`requirements.toml` to ignore user, project, and session hook configs while
still allowing managed hooks from requirements and managed config layers. This
setting is only supported in `requirements.toml`; putting it in `config.toml`
does not enable managed-hooks-only mode.
