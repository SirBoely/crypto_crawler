# crypto_crawler

Distributed cryptocurrency market-data, arbitrage-monitoring and trading-service project.

## Security notice

Operational credentials, wallet material, Telegram bot tokens, exchange API keys, SSH keys, database passwords, private endpoints and other production configuration **must never be committed to this repository**.

Use environment variables or an external secret manager for runtime credentials. Example configuration files must contain placeholders only.

If you previously cloned a revision containing a real credential, do not reuse that credential. Treat it as compromised and rotate/revoke it through the relevant provider. Removing a value from the current branch does not remove it from Git history, forks or existing clones.

## Architecture overview

The project contains independent services for market-data retrieval, balance monitoring, arbitrage monitoring, order/trade persistence, notifications and operational processing. Redis is used for queue/cache workloads and PostgreSQL for persistence in supported deployments.

## Safe deployment principles

- Keep `.env`, secret directories, wallet material and key files outside Git.
- Use least-privilege service accounts and network allowlists.
- Do not expose Redis/PostgreSQL directly to the public internet.
- Store Telegram/exchange/API credentials in a secret manager or protected runtime environment.
- Use dedicated non-production credentials for local development.
- Do not place real IP addresses, database hosts, private SSH details or access tokens in documentation/examples.
- Rotate credentials immediately if they appear in a commit, log, issue, pull request or artifact.

## Configuration

Create local configuration from sanitized sample files where available. Replace placeholder values only in your local/managed runtime environment. Never commit populated configuration files.

## Incident status

A historical documentation revision contained sensitive operational material. The current README has been sanitized as an immediate containment action. Historical secret review and credential rotation remain required; current-tree redaction alone is not sufficient remediation.
