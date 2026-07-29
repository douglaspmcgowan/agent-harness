#!/usr/bin/env node
// guard-hooks.test.js — feeds sample Bash commands to guard-env-mutation.js + guard-bulk-delete.js and
// asserts the exit code (2 = block, 0 = allow). Run: node guard-hooks.test.js
const { spawnSync } = require("child_process");
const path = require("path");
const NODE = process.execPath;

function run(hook, command, toolName) {
  const r = spawnSync(NODE, [path.join(__dirname, hook)], {
    input: JSON.stringify({ tool_name: toolName || "Bash", tool_input: { command } }),
    encoding: "utf8",
  });
  return r.status;
}

const cases = [
  // guard-env-mutation
  ["guard-env-mutation.js", "pip install vtk", 2, "pip install -> block"],
  ["guard-env-mutation.js", "python -m pip uninstall -y vtk", 2, "pip uninstall -> block"],
  ["guard-env-mutation.js", "pip install --force-reinstall cadquery-vtk==9.3.1", 2, "force-reinstall -> block"],
  ["guard-env-mutation.js", "scoop install jq", 2, "scoop install -> block"],
  ["guard-env-mutation.js", "conda remove numpy", 2, "conda remove -> block"],
  ["guard-env-mutation.js", "npm install -g typescript", 2, "npm global -> block"],
  ["guard-env-mutation.js", "ALLOW_ENV_MUTATION=1 pip install vtk", 0, "override -> allow"],
  ["guard-env-mutation.js", "pip list", 0, "pip list -> allow"],
  ["guard-env-mutation.js", "pip show vtk", 0, "pip show -> allow"],
  ["guard-env-mutation.js", "python gate.py struct1u", 0, "normal python -> allow"],
  ["guard-env-mutation.js", "npm run build", 0, "npm run (local) -> allow"],
  // guard-bulk-delete
  ["guard-bulk-delete.js", "git rm bill_of_joints.py", 2, "git rm -> block"],
  ["guard-bulk-delete.js", "rm -rf runs/", 2, "rm -rf dir -> block"],
  ["guard-bulk-delete.js", "rm *.py", 2, "rm wildcard -> block"],
  ["guard-bulk-delete.js", "rm -r build", 2, "rm -r -> block"],
  ["guard-bulk-delete.js", "Remove-Item -Recurse -Force build", 2, "Remove-Item -Recurse -> block"],
  ["guard-bulk-delete.js", "find . -name '*.tmp' -delete", 2, "find -delete -> block"],
  ["guard-bulk-delete.js", "git ls-files | xargs rm", 2, "xargs rm -> block"],
  ["guard-bulk-delete.js", "ALLOW_BULK_DELETE=1 rm -rf scratch/", 0, "override -> allow"],
  ["guard-bulk-delete.js", "rm _probe.py", 0, "single rm -> allow"],
  ["guard-bulk-delete.js", "mv old.py new.py", 0, "mv (rename) -> allow"],
  ["guard-bulk-delete.js", "git mv a.py b.py", 0, "git mv -> allow"],
  ["guard-bulk-delete.js", "git ls-files --deleted -z | xargs -0 git checkout --", 0, "git restore -> allow"],
  // PowerShell coverage (tool_name = "PowerShell" must now reach the patterns, not early-exit)
  ["guard-bulk-delete.js", "Remove-Item -Recurse -Force build", 2, "PS Remove-Item -Recurse -> block", "PowerShell"],
  ["guard-bulk-delete.js", "Remove-Item -Recurse build", 2, "PS Remove-Item -Recurse -> block", "PowerShell"],
  ["guard-bulk-delete.js", "git rm bill_of_joints.py", 2, "PS git rm -> block", "PowerShell"],
  ["guard-bulk-delete.js", "Get-ChildItem", 0, "PS Get-ChildItem -> allow", "PowerShell"],
  ["guard-bulk-delete.js", "ALLOW_BULK_DELETE=1 Remove-Item -Recurse -Force scratch", 0, "PS override -> allow", "PowerShell"],
  ["guard-env-mutation.js", "pip install vtk", 2, "PS pip install -> block", "PowerShell"],
  ["guard-env-mutation.js", "scoop install jq", 2, "PS scoop install -> block", "PowerShell"],
  ["guard-env-mutation.js", "ALLOW_ENV_MUTATION=1 pip install vtk", 0, "PS override -> allow", "PowerShell"],
  ["guard-env-mutation.js", "Get-ChildItem", 0, "PS normal cmd -> allow", "PowerShell"],
];

let pass = 0, fail = 0;
for (const [hook, cmd, exp, desc, toolName] of cases) {
  const got = run(hook, cmd, toolName);
  const ok = got === exp;
  console.log(`${ok ? "PASS" : "FAIL"}  ${desc}  (exit ${got}, want ${exp})`);
  ok ? pass++ : fail++;
}
console.log(`\n${pass}/${pass + fail} passed${fail ? "  — FAILURES ABOVE" : ""}`);
process.exit(fail ? 1 : 0);
