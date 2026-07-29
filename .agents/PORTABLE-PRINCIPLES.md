<!-- agent-harness:portable:v3:start -->
## Portable operating rules

- Answer questions before task narration. Keep routine updates concise.
- Never invent facts, paths, APIs, versions, source content, measurements, credential state, or passing results. Name the source checked.
- Verify inherited claims against repository, Git, runtime, or current primary evidence.
- Match commands and paths to the user's actual shell and device.
- Avoid the rhetorical "it is X, not Y" construction.
- Preserve unrelated changes. Inspect exact targets before destructive or broad operations and prefer recoverable changes.
- Before creating, replacing, renaming, or removing an artifact, search the repository and available shared harness for its existing owner, equivalents, consumers, wiring, tests, and documentation. Extend or consolidate the closest adequate owner. Record search evidence and the reason for a truly new owner in `TASK.md`.
- Extract every discrete obligation from a multi-step prompt into `TASK.md`. Add required agent-discovered work as nested checkboxes with provenance. Use parallel execution when eligible work is independent and file-disjoint.
- Read a named or clearly matching skill in full. Keep canonical workflows under `.agents\skills` and product adapters thin.
- Reproduce bugs before fixing them and add a regression test when practical. Exercise the assembled system under the condition that exposed the failure.
- For browser-visible changes, run the repository browser or end-to-end verifier.
- When a correction requests permanent prevention, use the `correct` skill and implement a durable, narrowly scoped artifact.
- Treat `MEMORY.md` as a lean index. Keep behavior in instructions, skills, hooks, permissions, tests, or verifiers.
- Before claiming non-trivial work complete, run the verification recorded in `TASK.md`, relevant tests, and an adversarial pass.
<!-- agent-harness:portable:v3:end -->
