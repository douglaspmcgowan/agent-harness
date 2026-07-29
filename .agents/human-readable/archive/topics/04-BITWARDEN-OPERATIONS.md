# Bitwarden and secrets operations

Last verified: 2026-07-27

Bitwarden Secrets Manager's free subscription currently includes unlimited secret storage, two users, three projects, and three machine accounts. Docket uses one project and one machine account, so no paid subscription is required. The complete click-by-click setup is in [20 — Free secrets management](20-FREE-SECRETS-MANAGEMENT.md).

## Current installation

- Bitwarden Password Manager CLI (`bw`) is installed.
- Bitwarden Secrets Manager CLI 2.1.0 is installed at `C:\Users\dougl\Tools\bws\bws.exe`.
- The official release asset’s SHA-256 digest was verified during installation.
- No `BWS_ACCESS_TOKEN` is present in Process, User, or Machine environment scope.

## Installed Secrets Manager broker

`Invoke-WithBitwardenSecret.ps1` is the machine-use path for Bitwarden Secrets Manager. It accepts a secret ID, destination environment-variable name, executable, and argument list. It requires all four fields to match one record in `bws-command-allowlist.json`, fetches one value through `bws`, removes `BWS_ACCESS_TOKEN` from the child environment, injects the requested value, runs the exact command, restores the parent environment, and clears its references in `finally`.

The current allowlist contains one credential-dependent operation: run Docket’s `sync-cloud.js` with `REVIEW_SECRET`. The child receives the Docket credential and cannot inherit the Secrets Manager bootstrap token.

Douglas’s setup steps:

1. In the Bitwarden web app, open Secrets Manager and create or select a Docket project.
2. Create a `REVIEW_SECRET` secret in that project. Enter or rotate the value in the web interface.
3. Create a read-only machine account scoped to that project.
4. Generate its access token and inject it into the current trusted PowerShell process as `BWS_ACCESS_TOKEN`. Keep it out of chat, command history, files, and screenshots.
5. Record the value-free Bitwarden secret ID in Docket’s `secret-manifest.json`.
6. Add the same value-free ID to the Docket entry's `secretIds` array in `bws-command-allowlist.json`.
7. Run the broker with that secret ID from a dedicated `powershell.exe -File` process. The broker retrieves and injects the Docket value without displaying it.

The production allowlist deliberately has an empty `secretIds` array until Douglas completes step 6, so the broker currently fails closed. The broker regression test proves the approved child receives the requested value, the child cannot see `BWS_ACCESS_TOKEN`, the parent bootstrap token survives, and unapproved arguments, destination variables, secret IDs, and bootstrap-token destinations are blocked.
- Douglas must create a Secrets Manager organization/project and a narrowly scoped machine account before `bws` can retrieve or inject project secrets.

## Recommended division

Use Bitwarden Password Manager for Douglas's human logins, recovery codes, and credentials used interactively. Use Bitwarden Secrets Manager for repeatable application, CI, and agent-consumed development secrets.

Password Manager unlocks a broad human vault. Secrets Manager can scope machine accounts to selected projects, assign read-only access, and revoke or expire individual access tokens. [Bitwarden CLI](https://bitwarden.com/help/cli/), [machine accounts](https://bitwarden.com/help/machine-accounts/), [access tokens](https://bitwarden.com/help/access-tokens/).

## Interactive boundary

Credential-dependent work is any action that needs authority outside the repository: deployment, cloud provisioning, authenticated API use, private package access, remote database migration, or production-like testing.

Before execution, Douglas should see:

1. requesting product and project;
2. credential identifier, with the value hidden;
3. exact executable and arguments;
4. target environment;
5. one-command lifetime or expiration.

Douglas performs:

- first login;
- each unlock;
- approval of credential identifier and exact command;
- creation and revocation of machine tokens;
- high-impact rotation;
- final lock.

The agent performs:

- prepares the command without the secret value;
- names the required environment variable;
- requests a trusted allowed executable;
- reads ordinary success or failure output;
- updates `.env.example` and secret inventories using names and purposes;
- avoids vault enumeration, export, display, and environment dumps.

## Password Manager CLI commands

Run these yourself in the PowerShell terminal that will launch the approved command:

```powershell
bw login
$env:BW_SESSION = bw unlock --raw
bw sync
```

`bw login` authenticates the CLI account. `bw unlock --raw` decrypts the vault and returns a session key to that PowerShell process. `bw sync` refreshes the local encrypted vault state.

After the credential-dependent block:

```powershell
bw lock
Remove-Item Env:BW_SESSION -ErrorAction SilentlyContinue
```

`bw lock` closes decrypted access. The environment cleanup removes the process variable from that terminal. A separately running Claude, Codex, or Cursor process does not receive variables added later to another terminal. [PowerShell environment variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables).

## Local broker

The broker invocation shape is:

```powershell
C:\Users\dougl\.agents\tools\Invoke-WithBitwardenItem.cmd `
  -Item <item-id-or-exact-name> `
  -Field password `
  -EnvironmentVariable SERVICE_API_KEY `
  <approved-executable> <arguments>
```

The broker retrieves one field, verifies the exact executable path against `credential-command-allowlist.json`, removes `BW_SESSION` before launching the child, injects the selected value, and restores the previous environment in `finally`.

The allowlist starts empty. Add an exact executable only after reviewing its origin and the command it will run. Shell interpreters and arbitrary scripting runtimes create a broad execution surface and should stay absent.

Every child receiving a secret can read or transmit it. Bitwarden gives the same warning for `bws run`; `--no-inherit-env` reduces inherited variables and does not create a sandbox. [Secrets Manager CLI](https://bitwarden.com/help/secrets-manager-cli/).

## Secrets Manager operating model

1. Create one Secrets Manager project per application and environment trust boundary.
2. Create separate read-only machine accounts for local development, CI, and other consumers.
3. Issue expiring access tokens.
4. Record owner, consumer, scope, issue date, expiration, and rotation procedure without recording the value.
5. Inject secrets at runtime.
6. Revoke old tokens after rotation and verify the new credential.

Keep `secret-manifest.json` as the canonical value-free inventory and generate `secret-manifest.md`. See brief 09 for the full trust-boundary and migration model.

The Secrets Manager `bws` CLI is currently absent on this computer. Installing it does not complete setup: Douglas must create the project, machine account, token scope, and expiration interactively.

## CI and deployment

- Use GitHub Actions OIDC for cloud providers that support it; jobs receive short-lived credentials. [GitHub OIDC](https://docs.github.com/en/actions/concepts/security/openid-connect).
- Use GitHub environment-scoped secrets when a stored secret is required.
- Give `GITHUB_TOKEN` read access by default and elevate individual jobs.
- Use separate development, preview, and production credentials.
- Store hosted runtime secrets in that hosting platform's secret store.

OWASP recommends centralized storage, least privilege, auditing, rotation, revocation, and expiration as one lifecycle. [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html).

## Leak response

1. Revoke or rotate the credential.
2. Identify every consumer and update authorized copies.
3. Verify the replacement.
4. Remove the old value from code and history where appropriate.
5. document the incident without copying the secret.

Deleting Git history does not invalidate an exposed credential. [GitHub exposure response](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

## Future evaluation

Bitwarden's Agent Access SDK targets just-in-time agent credential requests and human approval. Bitwarden currently labels it early alpha, so evaluate it with sample data before production use. [Bitwarden Agent Access SDK](https://bitwarden.com/de-de/blog/introducing-agent-access-sdk/).
