# Research basis

Read this reference when explaining the memory model, deciding which evidence identifies a stale tree, or improving lifecycle cleanup in the owning code.

## Primary sources

- [Microsoft RAMMap](https://learn.microsoft.com/en-us/sysinternals/downloads/rammap) — inspect how Windows assigns physical pages across process working sets, standby lists, file cache, drivers, and the kernel.
- [Microsoft Process Explorer](https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer) — inspect process ownership, ancestry, handles, DLLs, and memory in a process-tree view.
- [Microsoft PoolMon guidance](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/poolmon) — attribute paged and nonpaged kernel-pool allocations by tag when process totals do not explain pressure.
- [Microsoft memory performance information](https://learn.microsoft.com/en-us/windows/win32/memory/memory-performance-information) — distinguish physical-memory load, commit limits, and system memory counters.
- [Playwright Browser.close](https://playwright.dev/docs/api/class-browser#browser-close) — close explicit browser contexts and then the browser; a launched browser owns all pages and should be disposed.
- [Playwright BrowserServer.close](https://playwright.dev/docs/api/class-browserserver#browser-server-close) — graceful server close also ensures the browser process terminates.
- [Node.js child_process](https://nodejs.org/api/child_process.html#optionsdetached) — Windows detached children can continue after their parent exits; `unref()` and detached stdio change lifecycle ownership.
- [psutil process-tree documentation](https://psutil.readthedocs.io/en/latest/#psutil.Process.children) — traverse descendants recursively, handle PID disappearance, wait for termination, and avoid assuming a PID still denotes the same process.

## Practitioner evidence

- [Playwright practitioners: close in `finally`](https://www.reddit.com/r/Playwright/comments/1cujv3z/should_i_call_close_methods_after_each_test/) — practitioners report using test fixtures or `finally` cleanup so browser disposal runs on failures.
- [Headless-browser resource exhaustion discussion](https://www.reddit.com/r/Playwright/comments/1d42ko4/fixing_eagain_and_various_other_issues_in/) — a practitioner account shows that repeated launches and incomplete lifecycle cleanup can accumulate dead processes; treat it as field evidence rather than a universal diagnosis.
- [Windows practitioners on working set and private bytes](https://www.reddit.com/r/sysadmin/comments/10p6ebg/can_i_have_some_help_understanding_memory_values/) — practitioners use both counters because physical pressure and process commit answer different questions.

## Mechanisms synthesized

1. Measure physical memory, commit, pools, and cache separately.
2. Bind a process decision to PID plus creation time, path, owner, session, and ancestry so PID reuse or a new owner fails revalidation.
3. Use exact executable locations for Playwright-managed browsers and known runtime paths.
4. Keep ambiguous processes human-gated.
5. Close the owning browser/context/process gracefully and place cleanup in `finally` in the source application.
6. Re-measure after cleanup; memory reclamation is an observed result rather than an assumption.
