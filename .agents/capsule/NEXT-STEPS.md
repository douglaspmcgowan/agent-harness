# Remaining setup checklist

## Bitwarden Secrets Manager

These steps create the durable, unattended credential route used by local agents:

1. In the Bitwarden web app, open the `Agents` organization.
2. Enable **Secrets Manager** for that organization.
3. Create one project named `Agent Runtime`. The harness uses one project so the Free plan's project limit can cover many repositories.
4. Create the secret `docket.REVIEW_SECRET`. Paste the current Docket review credential as its value. The prefix identifies the application; the suffix identifies the environment variable delivered to the approved process.
5. Create one read-only machine account for each computer.
6. Give each machine account read access to `Agent Runtime`.
7. Generate an access token for the current computer.
8. On that computer, run:

```powershell
& "$env:USERPROFILE\.agents\tools\Set-BwsMachineToken.ps1"
```

9. Paste the access token into the secure prompt. Do not send it through chat or save it in Capsule.
10. Tell the agent that the project and secret now exist. The agent records their non-secret IDs in `%USERPROFILE%\.agents\tools\bws-command-allowlist.json`, runs the broker tests, and invokes only the approved command ID.

The stored machine token lets the exact-command broker retrieve approved secrets without an interactive Bitwarden login for every run.

## Receiving computer

1. Open the Drive folder:
   <https://drive.google.com/drive/folders/197x4O5pCj5cuXETXuv72zeCdvkVSDJSj>
2. Make `My Drive\Capsule` available offline.
3. Copy Capsule to a local staging folder outside all sync roots.
4. Clone or update the known `ai-consulting-1/doug-harness` repository.
5. Run that checkout's `.agents\capsule\Verify-Capsule.ps1` against staged Capsule with `-TrustedHarnessRepository` pointing to the checkout.
6. After the external proof passes, run staged `Harness.ps1 -Action install -HarnessRepository <trusted checkout>`.
7. Complete account-owner sign-ins when prompted.
8. Complete the Bitwarden machine-account steps above for this computer.
9. Discover and clone GitHub repositories carrying the `agent-project` topic.
10. Run each repository's verifier.
11. Run only the external-data adapters declared by that repository's `data-manifest.yaml`.
12. Confirm Quick Access pins after the GitHub project paths exist.

## Source computer

1. When approved Obsidian settings changed, run `Capture-ApprovedObsidianConfig.ps1`.
2. Review the tracked snapshot and digest diff, then commit and push it with shared-harness changes.
3. Run the source harness with `-Action sync` against `My Drive\Capsule`.
4. Run the verifier from the trusted harness checkout against the refreshed Capsule.
5. Wait for Google Drive to report **Up to date**.
6. Commit and push durable work in every active project repository.
7. Run project-specific data adapters for external data that changed.

## Web access

- Share GitHub links for project source, task state, maps, and handoffs.
- Share Google Drive links for Capsule and reviewed external-data artifacts.
- Share deployed application links for phone access to live data.

## Already automated

- Guarded stale-agent cleanup runs four times daily and records an audit log.
- Capsule refresh reconstructs the global harness and approved Obsidian snapshot from one authenticated Git revision.
- Capsule verification rejects workspace/project payloads, undeclared files, and any harness payload that differs from the separately checked-out canonical Git revision.
- Bootstrap configures the standard local and Google Drive project-data roots.
