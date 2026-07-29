# Free secrets management for Douglas's agent workflow

Last verified: 2026-07-27

## Decision

Use **Bitwarden Password Manager Free** as the recoverable source of truth for Douglas's local-development secrets. Its personal free plan allows unlimited vault items and works across devices. Store one item per project and one hidden custom field per environment-variable name.

Use platform-native secret stores at deployment boundaries:

- Vercel environment variables for Vercel runtimes;
- GitHub repository, environment, or agent secrets for GitHub-hosted work;
- a separate deployment token for each external service and environment.

Use `C:\Users\dougl\.agents\tools\Invoke-WithBitwardenItem.cmd` for local credential-dependent commands. It retrieves one named field, injects it into one approved child executable, removes `BW_SESSION` from the child, and restores the parent process state afterward.

The broker policy binds the complete tuple: Bitwarden item, custom field, destination environment variable, resolved executable, and exact argument list. Every tuple mismatch is rejected before the broker contacts Bitwarden. The production policy remains empty and fail-closed until Douglas creates `project:docket:production` with its hidden `REVIEW_SECRET` field.

Bitwarden Secrets Manager Free remains available for up to three projects and three machine accounts. Douglas expects more than three projects, so it is an optional small-project tool.

## Why this model

The vault is the recoverable human authority. Each runtime receives only the credentials it needs. Project count stays independent of a vendor's machine-secrets free tier, and a compromised preview deployment cannot automatically read local-development or production credentials.

The ordinary Bitwarden vault requires an interactive unlock before local use. A newly opened agent session cannot silently enumerate the vault. The broker receives a specific item and field and passes the value to a bounded child process without printing it.

Cloud agents cannot use Douglas's unlocked desktop vault. Give each cloud surface its own scoped platform secret, and commit only the value-free `secret-manifest.json` that names the requirement.

## Per-project Bitwarden layout

Create a Secure Note or Login item named:

```text
project:<repository>:<environment>
```

Examples:

```text
project:docket:local
project:docket:production
project:fellowship-tracker:local
```

Add one **Hidden** custom field for each secret using the application's exact variable name:

```text
REVIEW_SECRET
DATABASE_URL
OPENAI_API_KEY
```

Keep public configuration such as `PORT`, `REVIEW_URL`, and ordinary data paths in `.env.example`, application configuration, or the repository's value-free manifest.

## Douglas's local operating procedure

1. Open Bitwarden and create or update the project item.
2. Put each secret in a Hidden custom field. The field name matches the environment variable consumed by the app.
3. Open a trusted PowerShell window.
4. Sign in to the CLI when required:

   ```powershell
   bw.cmd login
   ```

5. Unlock the vault for that PowerShell process:

   ```powershell
   $env:BW_SESSION = bw.cmd unlock --raw
   ```

   Bitwarden prompts for the master password. Do not paste the resulting session value into chat, files, screenshots, command arguments, or another agent.

6. Run the approved broker command. The project documentation supplies the exact item, field, environment-variable name, and child command.
7. Lock and clear the session when credential-dependent work is finished:

   ```powershell
   bw.cmd lock
   Remove-Item Env:BW_SESSION -ErrorAction SilentlyContinue
   ```

An agent may prepare and execute the value-free broker invocation after Douglas unlocks the current trusted terminal. Douglas performs login, unlock, recovery, high-impact rotation, and final lock.

## Docket

Local Docket binds to `127.0.0.1` and authenticates loopback requests with an in-process marker. Local-only use requires no Docket passcode.

The public Vercel Docket URL requires `APP_SECRET` because internet clients can reach its API. The phone UI and local cloud-sync process use the same value as `REVIEW_SECRET`. Store that value in:

- the Bitwarden item `project:docket:production`, hidden field `REVIEW_SECRET`;
- Vercel production as `APP_SECRET`.

The Docket source repository stores only the variable names and purpose in `secret-manifest.json`.

## Alternatives

| Tool | Current free capacity | Fit |
|---|---:|---|
| Bitwarden Password Manager Free | Unlimited personal vault items | Recommended human/local source of truth; interactive unlock |
| Doppler Developer | 10 projects, 4 environments per project, 5 config syncs | Best hosted free alternative for up to ten active apps |
| GitHub Secrets | 100 repository, 100 per environment, 1,000 organization secrets | GitHub Actions, Codespaces, and supported GitHub agent sessions |
| SOPS + age | Open source; no provider project limit | Encrypted files in Git with deliberate key backup and rotation |
| Infisical Free | 3 projects, 3 environments, 5 identities | Small hosted setup |
| Bitwarden Secrets Manager Free | Unlimited secrets, 3 projects, 3 machine accounts | Small machine-automation setup |
| KeePassXC | Open source local vault | Human/local storage with manual cross-device and automation setup |

Doppler's free Developer plan currently supports ten projects. If Douglas outgrows ten hosted projects, keep Bitwarden as the human authority and use GitHub/Vercel secrets per deployment, or adopt SOPS with a carefully backed-up `age` identity. Self-hosting a secrets server adds patching, availability, encryption-key recovery, and backup work.

## Value-free repository contract

Each repository contains:

- `.env.example` — variable names and safe placeholders;
- `secret-manifest.json` — canonical names, purpose, provider, trust boundary, owner, consumers, rotation trigger, and value-free provider reference;
- `secret-manifest.md` — generated human view;
- `.gitignore` — excludes `.env`, passcode files, credentials, and local secret exports.

Refresh the generated view with:

```powershell
C:\Users\dougl\.agents\tools\Update-SecretManifest.cmd -Repository C:\path\to\repo
```

The updater reads variable names and metadata. Secret values remain outside the repository.

## Operating rules

- Create a different secret for each trust boundary when the provider supports it.
- Prefer short-lived or scoped service tokens over account-wide credentials.
- Never store secret values in persistent user or machine environment variables.
- Never allow an agent to list or export the vault.
- Never send `BW_SESSION` to a child process.
- Keep broker executable approvals narrow and review any allowed executable that can run arbitrary scripts.
- Rotate a credential after confirmed exposure and verify the replacement before revoking the old value.
- Run Gitleaks before commit and in CI.
- Keep Bitwarden recovery material offline and test account recovery.

## Sources

- [Bitwarden Password Manager plans](https://bitwarden.com/help/password-manager-plans/)
- [Bitwarden Password Manager CLI](https://bitwarden.com/help/cli/)
- [Bitwarden custom fields](https://bitwarden.com/help/custom-fields/)
- [Bitwarden Secrets Manager FAQ](https://bitwarden.com/help/secrets-manager-faqs/)
- [Doppler platform limits](https://docs.doppler.com/docs/platform-limits)
- [Doppler secrets setup guide](https://docs.doppler.com/docs/secrets-setup-guide)
- [Infisical pricing](https://infisical.com/pricing)
- [SOPS](https://github.com/getsops/sops)
- [age](https://github.com/FiloSottile/age)
- [GitHub secrets reference](https://docs.github.com/en/actions/reference/security/secrets)
