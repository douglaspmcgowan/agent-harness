# Secrets and Bitwarden operating model

Last consolidated: 2026-07-29

This guide consolidates the former Bitwarden operations and free-secrets briefs. Their dated source text remains under [`archive/topics`](archive/topics/).

## Current decision

Use three coordinated authorities:

- **Bitwarden Password Manager** for human logins, recovery material, and project secrets used by local applications or bounded local agent commands.
- **Deployment-provider secret stores** for the minimum values needed by GitHub Actions, Vercel, hosted databases, cloud agents, and other remote runtimes.
- **Bitwarden Secrets Manager** for a small automation boundary that benefits from projects and machine accounts. Its free-project limit makes it an optional fit for this multi-project harness.

Git contains secret names, purposes, owners, consumers, trust boundaries, rotation triggers, and value-free provider references. Secret values remain in Bitwarden or the runtime provider.

## Bitwarden item types

Bitwarden exposes several item types. Choose the type based on the human record being protected:

| Item type | Use in this harness |
|---|---|
| **Login** | Project account plus local project secrets. Store each environment variable as a **Hidden** custom field. This is the default project item type. |
| **Secure Note** | Sensitive recovery instructions or text that does not fit a login. Keep automation secrets out of free-form note bodies because field selection and policy review become ambiguous. |
| **Identity** | Personal identity fields used for form filling. Keep project credentials in Login items. |
| **Card** | Payment-card data. Keep billing credentials separate from project runtime secrets. |
| **SSH Key** | SSH private/public key material managed through Bitwarden's dedicated SSH-key workflow. Reference the key's purpose in project metadata without copying the key. |

The default project naming pattern is:

```text
project:<project>:<environment>
```

Examples include `project:docket:production` and `project:conference-tracker:development`.

Each project Login item should contain:

- a non-secret username or account identifier when the project has one;
- a URI when a login page or service endpoint applies;
- one **Hidden** custom field per environment-variable name;
- value-free notes for owner, purpose, consumers, rotation trigger, and recovery procedure.

## Placeholder-item workflow

An agent can create value-free project items after Douglas has authenticated and unlocked the Bitwarden CLI in a trusted PowerShell session.

1. Inventory the project names, environments, and required variable names from `.env.example`, `secret-manifest.json`, deployment configuration, and documented consumers.
2. Propose the Login-item name and Hidden custom-field names.
3. Create the Login item with empty **Hidden** fields and the reserved URI `https://replace.invalid`. Empty fields keep the broker fail-closed.
4. Record the returned item ID only in the value-free secret manifest or broker policy.
5. Douglas opens Bitwarden, enters every real value, replaces the reserved URI when a provider page applies, confirms each field type is **Hidden**, and saves.
6. The agent verifies field presence and the approved broker tuple without displaying or summarizing the value.

The agent may create structure and placeholders. Douglas supplies real values, recovery material, master-password input, and high-impact rotation decisions.

## Environment trust boundaries

An environment trust boundary is the set of processes, people, machines, and deployment stages allowed to receive the same secret under the same compromise assumptions.

Typical boundaries include:

- Douglas's local development computer;
- a Cursor or Codex cloud agent;
- GitHub Actions;
- a Vercel preview deployment;
- a Vercel production deployment;
- a production database migration job.

Use separate credentials when compromise, rotation, or audit requirements differ. Every child process receiving a secret can read or transmit it, so executable and argument approval remain security boundaries.

## Human and agent responsibilities

Douglas:

- signs in and unlocks Password Manager;
- enters or replaces real secret values;
- verifies recovery access;
- approves exact credential-dependent commands;
- creates Secrets Manager projects, machine accounts, or tokens when that optional boundary is selected;
- performs high-impact rotation and revocation.

The agent:

- inventories names, purposes, environments, and consumers;
- creates value-free placeholder Login items when the CLI is unlocked and authorized;
- generates `secret-manifest.json`, `secret-manifest.md`, `.env.example`, and broker-policy records;
- validates the requested item, field, environment variable, executable, and arguments;
- consumes ordinary success or failure output;
- records rotation metadata;
- never reads, exports, displays, logs, or summarizes secret values.

## Password Manager CLI boundary

`bw` is the Password Manager CLI.

```powershell
bw login
$env:BW_SESSION = bw unlock --raw
bw sync
```

Douglas runs login and unlock in a trusted PowerShell window. The session value stays out of chat, files, screenshots, command arguments, and child-process environments. Run `bw lock` when credential-dependent work finishes.

A sandbox or AppContainer may have a different credential and environment view from the interactive Windows account. Verify identity and CLI status in the owning Windows context before concluding that login is required.

## Full-tuple local broker

Use the Password Manager broker for an approved local command. The policy binds:

1. Bitwarden item ID;
2. Hidden custom-field name;
3. destination environment-variable name;
4. resolved executable path;
5. complete argument list.

Every field must match one approved policy record before retrieval. The broker removes `BW_SESSION` from the child environment, injects the selected value for the approved command, restores parent state, and clears references in its cleanup path.

The value-free manifest records the item ID, label, field name, destination variable, owner, purpose, consumers, environment, and rotation trigger. It never stores a password, API key, access token, recovery code, or session value.

## Cloud and deployment secrets

An unlocked desktop vault does not travel to a cloud agent. Configure a scoped secret in the provider that owns the remote runtime:

- GitHub repository or environment secrets for GitHub Actions;
- Vercel environment variables for preview or production;
- the database provider's scoped credential store;
- the cloud-agent environment's secret settings.

Keep preview, production, CI, migration, and local-development credentials separate when their trust boundaries differ. Prefer short-lived identity federation such as OIDC when the provider supports it.

## Optional Secrets Manager boundary

Bitwarden Secrets Manager remains useful for a small set of machine-consumed secrets when project and machine-account scoping justify its additional bootstrap token.

The Secrets Manager broker binds the secret ID, destination variable, resolved executable, and full argument list. The narrowly scoped machine-account token stays in the parent broker boundary and is removed from the approved child environment.

Use Password Manager Login items for the general multi-project placeholder setup. Adopt Secrets Manager per application only after recording why its project scope, machine account, expiration, and recovery path are preferable.

## Environment discovery

Process, sandbox, User, and Machine scopes are separate evidence boundaries. A variable missing from one process may exist in another scope or in product settings.

Use the metadata-only Windows probe:

```powershell
C:\Users\dougl\.agents\tools\Get-EnvironmentVariableMetadata.cmd -Pattern 'SUPABASE|POSTGRES|DATABASE'
```

The probe reports scope, name, set/unset state, and length without returning values. Product settings, running applications, terminal-local variables, `.env` files, and deployment providers require their own name-only inventories.

## Manifest contract

`secret-manifest.json` is the canonical value-free inventory. `secret-manifest.md` is its generated human view. `.env.example` contains names and safe placeholders.

Each manifest record should identify:

- variable name;
- purpose;
- environment and trust boundary;
- owner;
- consumers;
- Bitwarden item ID or provider reference;
- Hidden custom-field name when Password Manager is used;
- rotation trigger and procedure;
- approved broker-policy identifier.

## Enforcement and incident response

Enforcement layers include:

- `.gitignore` for local secret files;
- Gitleaks pre-commit and pre-push scanning;
- Gitleaks CI;
- hooks that block credential-file reads and secret-shaped command arguments;
- exact broker tuple policies;
- provider-side scoping, expiration, and audit logs.

After a confirmed exposure:

1. revoke or rotate the credential;
2. update every intended consumer;
3. verify the replacement;
4. remove exposed material from code or history where required;
5. record a value-free incident note and rotation date;
6. review the boundary that allowed exposure.

History cleanup does not revoke a credential. Rotation and consumer verification come first.

## Archived sources

- [`04-BITWARDEN-OPERATIONS.md`](archive/topics/04-BITWARDEN-OPERATIONS.md) preserves the earlier dual-CLI operating detail.
- [`05-BITLOCKER-AND-GITLEAKS.md`](archive/topics/05-BITLOCKER-AND-GITLEAKS.md) preserves the dated device-encryption and Gitleaks setup record.
- [`20-FREE-SECRETS-MANAGEMENT.md`](archive/topics/20-FREE-SECRETS-MANAGEMENT.md) preserves the Password Manager decision research and alternatives table.
