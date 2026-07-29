---
name: MCP Servers — full map
description: All MCP servers in ~/.claude/mcp.json and platform-managed ones, with auth, paths, and capabilities
type: reference
originSessionId: 0a29b488-924b-4d17-9719-1c244969b67a
---

## Local MCP servers (defined in `~/.claude/mcp.json`)

### multi-google (`mcp__multi-google__*`)

- **Type**: Local Node process (ESM)
- **Binary**: `C:/Users/dougl/multi-google-mcp/dist/index.js`
- **Source**: github.com/chaymore/multi-google-mcp
- **Accounts**: `personal` (douglaspmcgowan@gmail.com) + `bhouse` (1636berkeley account) — tokens at `~/.config/multi-google-mcp/config.json`
- **Tools (all take `account` param)**: `gmail_search`, `gmail_read`, `gmail_send`, `gmail_draft`, `gmail_list_labels`, `calendar_list_events`, `calendar_create_event`, `calendar_update_event`, `calendar_delete_event`, `calendar_list_calendars`, `google_list_accounts`
- **Add account**: `cd ~/multi-google-mcp && npm run add-account`
- **Note**: Tools show up as `mcp__multi-google__*`. If missing from session, restart Claude Code.

### filesystem

- **Type**: Local Node process
- **Binary**: `C:/Users/dougl/AppData/Roaming/npm/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js`
- **Roots**: `C:/Users/dougl`, `G:/My Drive`
- **Capabilities**: Full read/write on those two trees. Use for any local file work outside Claude's built-in Read/Write/Edit tools.

### obsidian

- **Type**: Local Node process
- **Binary**: `C:/Users/dougl/AppData/Roaming/npm/node_modules/obsidian-mcp/dist/index.js`
- **Vault**: `G:/My Drive/Obsidian/Metropolis Pt. 1--The Maverick And The Test` (legacy Drive vault — archive)
- **Note**: Active vault is `C:/Users/dougl/Main/Yoga 7 Local_John 14_12` — use Read/Write tools directly for it.

### vercel

- **Type**: HTTP remote
- **URL**: `https://mcp.vercel.com`
- **Auth**: Vercel OAuth (no local install needed)
- **Capabilities**: List deployments, inspect project status, manage domains

---

## Platform-managed MCP servers (authenticated through Claude Code, no mcp.json entry)

### Gmail (`mcp__2d7d2974-cc6a-44de-96c0-a3c5c86f8ca6__*`)

- **Account**: douglaspmcgowan@gmail.com (single account — platform-managed)
- **Tools**: `search_threads`, `get_thread`, `list_labels`, `list_drafts`, `create_draft`, `label_thread`, `unlabel_thread`, `label_message`, `unlabel_message`, `create_label`, `update_label`, `delete_label`
- **Limitation**: `create_draft` does NOT support attachments (as of Jun 2026)

### Google Drive (`mcp__8d2261a9-765d-4f08-91c9-a312ae9d3457__*`)

- **Account**: douglaspmcgowan@gmail.com
- **Tools**: `read_file_content`, `get_file_metadata`, `list_recent_files`, `search_files`, `download_file_content`, `create_file`, `copy_file`, `get_file_permissions`

### DocuSign (`mcp__3ae33ae3-64d6-4972-af61-1391feebb546__*`)

- **Tools**: `sendReminder`, `updateEnvelopeRecipients`

### Claude in Chrome (`mcp__Claude_in_Chrome__*`)

- **Extension**: Must be open and signed in for tools to work
- **Tools**: `navigate`, `get_page_text`, `read_page`, `find`, `read_console_messages`, `read_network_requests`, `tabs_context_mcp`, `tabs_create_mcp`, `tabs_close_mcp`, `list_connected_browsers`, `select_browser`, `switch_browser`, `form_input`, `javascript_tool`, `shortcuts_execute`, `shortcuts_list`, `resize_window`, `computer`, `browser_batch`, `gif_creator`, `file_upload`, `upload_image`

### Claude Preview (`mcp__Claude_Preview__*`)

- **Tools**: `preview_start`, `preview_stop`, `preview_screenshot`, `preview_snapshot`, `preview_click`, `preview_fill`, `preview_eval`, `preview_inspect`, `preview_network`, `preview_console_logs`, `preview_logs`, `preview_list`, `preview_resize`

### MCP Registry (`mcp__mcp-registry__*`)

- **Tools**: `list_connectors`, `search_mcp_registry`, `suggest_connectors`

### Session Management (`mcp__ccd_session_mgmt__*`)

- **Tools**: `list_sessions`, `search_session_transcripts`, `archive_session`

### Scheduled Tasks (`mcp__scheduled-tasks__*`)

- **Tools**: `create_scheduled_task`, `list_scheduled_tasks`, `update_scheduled_task`

### CCD Directory (`mcp__ccd_directory__*`)

- **Tools**: `request_directory`

---

## Permissions pre-approved in settings.json

Read-only MCP tools are in the allowlist (no prompt on use):

- All `filesystem` read tools
- Gmail: `search_threads`, `get_thread`, `list_labels`, `list_drafts`
- Drive: `read_file_content`, `get_file_metadata`, `list_recent_files`, `search_files`
- Chrome: `navigate`, `get_page_text`, `read_page`, `find`, `read_console_messages`, `read_network_requests`, `tabs_context_mcp`, `list_connected_browsers`
- Registry: `list_connectors`, `search_mcp_registry`, `suggest_connectors`
- Session mgmt: `list_sessions`, `search_session_transcripts`
- Scheduled tasks: `list_scheduled_tasks`
- CCD directory: `request_directory`

Mutating tools (create, send, write, delete) require explicit permission each use.
