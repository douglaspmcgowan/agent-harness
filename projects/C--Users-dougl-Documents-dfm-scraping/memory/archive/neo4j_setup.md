---
name: Neo4j Setup and Troubleshooting
description: Neo4j Desktop config, connection defaults, push scripts, CSV import, and common issues (orphan process, port conflicts)
type: reference
---

## Neo4j Desktop Installation
- Installed at `C:\Users\dougl\.Neo4jDesktop2\`
- Java runtime: `...\Cache\runtime\zulu21.44.17-ca-jdk21.0.8-win_x64\bin\java.exe`

## Connection Defaults (used by push scripts)
- URI: `bolt://localhost:7687`
- User: `neo4j`
- Password: `password` (default -- change via NEO4J_PASSWORD env var)
- Database: `neo4j`
- Set via env vars: `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD`, `NEO4J_DATABASE`

## Push Scripts
- `push_to_neo4j.py` -- pushes provenance_graph.gpickle (nodes + structural edges)
  - `--clear` wipes database first
  - `--verify-only` runs count queries only
- `push_semantic_edges.py` -- pushes semantic_edges.json (CAUSAL_LINK, SPECIFIES, MITIGATES, CONTRADICTS)
  - `--clear-semantic` deletes semantic edges before reimport
  - `--verify-only` checks counts only
  - Requires structural graph already loaded
- Both use batched transactions (BATCH_SIZE=500 default)

## CSV Import Alternative
- `export_neo4j_csv.py` -- exports graph to CSV files in `neo4j_import/` directory
- `neo4j_import/neo4j_import.cypher` -- Cypher script to import CSVs
- CSV files must be copied to Neo4j's `import/` directory (In Desktop: three dots on DBMS -> Open folder -> Import)
- Constraints: Thread, Post, Author, Frame nodes all have unique `id`

## Graph Contents (after full push)
- Node types: Thread, Post, Author, Frame
- Structural edges: CONTAINS_POST, CONTAINS_FRAME, AUTHORED_BY, SE_ANSWERS
- Semantic edges: CAUSAL_LINK (625), SPECIFIES (2111), MITIGATES (1206), CONTRADICTS (330)
- Total: 7,864 nodes, 8,776 structural edges, 4,272 semantic edges

## Known Issues

### "Start Instance" Immediately Stops
- **Cause**: Orphan Java process already holding port 7687
- **Diagnosis**: `powershell.exe -Command "Get-NetTCPConnection -LocalPort 7687"` then `Get-Process -Id <PID>`
- **Fix**: Kill the orphan process, then restart from Desktop
- **Note**: The Bolt connection (localhost:7687) works fine with the orphan -- Python scripts connect successfully even when Desktop shows "Stopped"

### Port Already in Use
- Neo4j uses ports 7687 (Bolt) and 7474 (HTTP/Browser)
- Check: `powershell.exe -Command "Get-NetTCPConnection -LocalPort 7687 -ErrorAction SilentlyContinue"`
- Neo4j Browser accessible at `http://localhost:7474`

## Running Push Pipeline
```bash
# Set password if not default
[Environment]::SetEnvironmentVariable('NEO4J_PASSWORD','your_password','Process')

# Push structural graph (wipe first if needed)
./venv/Scripts/python.exe push_to_neo4j.py --clear

# Push semantic edges
./venv/Scripts/python.exe push_semantic_edges.py

# Verify counts
./venv/Scripts/python.exe push_to_neo4j.py --verify-only
./venv/Scripts/python.exe push_semantic_edges.py --verify-only
```
