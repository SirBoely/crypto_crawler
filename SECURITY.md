# Security Policy

## Credential handling

Never commit or publish real Telegram bot tokens, exchange API keys/secrets, wallet recovery material, private keys, SSH keys, database passwords, cloud credentials, production hostnames, or other sensitive deployment configuration.

Use environment injection or a managed secret store for runtime credentials. Documentation and example files must use placeholders only.

If a credential appears in Git, an issue, a pull request, an artifact, a log, or documentation, treat it as compromised. Revoke or rotate it at the provider first; deleting the current file is not sufficient because Git history, forks and existing clones may still contain the value.

## Reporting

Do not report live credentials in public issues. Use a private security-reporting channel when available and provide reproduction details without copying secret values.

## Incident response

For a suspected credential leak:

1. stop relying on the exposed credential;
2. revoke/rotate it from a trusted administrative environment;
3. update legitimate consumers through a secret manager or protected runtime configuration;
4. scan the current tree and repository history for additional secrets;
5. review related infrastructure access and logs;
6. purge historical secret material when appropriate under a documented incident process;
7. re-scan after remediation.

Making a repository private does not revoke a leaked credential and does not invalidate existing clones or forks.
