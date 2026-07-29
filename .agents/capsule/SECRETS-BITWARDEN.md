# Bitwarden Secrets Manager setup

Bitwarden Secrets Manager supplies runtime secrets to approved local processes. Capsule carries value-safe IDs and exact-command policy. Each computer holds its own read-only machine-account token in Windows Credential Manager.

## Why this model

- one Secrets Manager project named `Agent Runtime` can hold prefixed secrets for many repositories;
- each computer receives an independently revocable machine account;
- the broker retrieves only allowlisted secret IDs;
- routine commands run without an interactive vault unlock;
- the child process receives only its approved environment variables;
- secret values stay out of Capsule, Git, chat, command arguments, and `.env` files.

## Responsibility boundary

| Douglas does | An agent can do |
|---|---|
| Sign into the Bitwarden web app and retain account-recovery material | Install or verify the `bws` executable |
| Enable Secrets Manager in the `Agents` organization | Resolve approved executable paths, arguments, and working directories |
| Create the `Agent Runtime` project | Prepare value-safe allowlist entries |
| Create or rotate secret values | Record non-secret project and secret IDs |
| Create a read-only machine account and generate its token | Run broker tests and approved command IDs |
| Paste the token into the secure local prompt | Verify isolation, tuple rejection, and output redaction |

Never paste a secret value, machine token, recovery code, or credential export into chat.

## One-time organization setup

In the Bitwarden web app:

1. Open the `Agents` organization.
2. Enable **Secrets Manager**.
3. Create a project named `Agent Runtime`.
4. Create secrets with a project prefix, such as `docket.REVIEW_SECRET`.
5. Create one machine account per computer or automation boundary.
6. Give the machine account read access to `Agent Runtime`.
7. Generate a machine-account access token for the current computer.

For Docket, `docket.REVIEW_SECRET` stores the bearer credential delivered as `REVIEW_SECRET` to the approved sync process.

## One-time computer setup

1. Install the Bitwarden Secrets Manager CLI as `bws.exe`.
2. Keep it at `%USERPROFILE%\Tools\bws\bws.exe` or pass its full path to the broker.
3. Run:

```powershell
& "$env:USERPROFILE\.agents\tools\Set-BwsMachineToken.ps1"
```

4. Paste the current computer's machine-account token into the secure prompt.

The helper stores the token in Windows Credential Manager under `AgentHarness/BitwardenSecretsManager`. Repeat this step only when setting up another computer, rotating the machine token, or replacing the credential-store record.

## Value-safe allowlist

The policy file is:

```text
%USERPROFILE%\.agents\tools\bws-command-allowlist.json
```

Each command record binds:

- `commandId`;
- exact executable path;
- exact argument list;
- exact working directory;
- Bitwarden project ID;
- one or more Bitwarden secret IDs;
- destination environment-variable names.

The repository contains blank `projectId` and `secretId` placeholders for `docket-sync`. After Douglas creates the Bitwarden resources, the agent reads or receives only those non-secret IDs and fills the placeholders.

Example shape:

```json
{
  "commandId": "docket-sync",
  "executable": "%ProgramFiles%\\nodejs\\node.exe",
  "argumentList": [
    "%USERPROFILE%\\projects\\docket\\sync-cloud.js"
  ],
  "workingDirectory": "%USERPROFILE%\\projects\\docket",
  "inheritedEnvironment": [],
  "projectId": "BITWARDEN_PROJECT_ID",
  "secretBindings": [
    {
      "secretId": "BITWARDEN_SECRET_ID",
      "environmentVariable": "REVIEW_SECRET"
    }
  ]
}
```

`inheritedEnvironment` contains only explicitly approved non-secret parent variable names. Leave it empty when the child needs only the normal Windows process baseline and its Bitwarden bindings. Every additional credential belongs in `secretBindings`.

IDs identify the resources and carry no secret value.

## Invoke an approved command

Run:

```powershell
& "$env:USERPROFILE\.agents\tools\Invoke-WithBitwardenSecret.ps1" `
  -CommandId "docket-sync" `
  -BwsPath "$env:USERPROFILE\Tools\bws\bws.exe"
```

The broker:

1. loads exactly one matching command record;
2. resolves the approved executable, arguments, and working directory;
3. retrieves the machine token from Windows Credential Manager;
4. asks BWS for each allowlisted secret ID;
5. verifies that every returned secret belongs to the approved Bitwarden project;
6. injects the values into the approved child process;
7. removes bootstrap and sibling-secret variables from that process;
8. redacts exact secret values from captured output;
9. clears in-memory references after the child exits.

## Rotation and removal

For rotation:

1. rotate the provider credential;
2. update the existing Secrets Manager secret;
3. run the approved command and its verifier;
4. revoke the previous provider credential.

For a machine-token rotation, generate a replacement token and rerun `Set-BwsMachineToken.ps1`.

For removal, delete the allowlist command first, revoke the provider credential or machine account, and then remove the Secrets Manager resource.

## Failure cases

| Message or condition | Action |
|---|---|
| BWS executable missing | Install `bws.exe` and pass its exact path |
| Machine token unavailable | Run `Set-BwsMachineToken.ps1` locally |
| Empty project or secret ID | Create the resource and record its non-secret ID |
| Project mismatch | Correct the allowlist to the intended `Agent Runtime` resource |
| Executable, arguments, or directory rejected | Register the exact intended tuple and rerun broker tests |
| Token revoked | Generate a new machine-account token and store it through the secure prompt |

Official reference: <https://bitwarden.com/help/secrets-manager/>
