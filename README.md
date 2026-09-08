# OptMemo

A fork of [OptMem](https://github.com/VictorTaelin/OptMem) that changes the
**record and compression rules**: what an agent writes into a memory, and
what a compression may keep or drop. A short prompt, a script, plug and play.

![how OptMem works](anim/optmem.gif)

> **Status: not deployed.** This is an independent, uninstalled fork. It does
> not change any running memory: an existing `~/.optmem/memo`, its `memory/`,
> and the `## Memory` block already pasted into your `AGENTS.md` (or
> `CLAUDE.md`) keep behaving exactly as before. Nothing here installs itself,
> and an external `AGENTS.md` may still override these rules. See
> [Adopting this fork](#adopting-this-fork).

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Moeblack/OptMemo/main/install.sh | sh
```

It prints a `## Memory` block. Paste that at the top of your agent's
`AGENTS.md` (or `CLAUDE.md`), and you are done. Run the same line again to
update.

The tool lands at `~/.optmem/memo`; put `~/.optmem` on `PATH` to type `memo`.

## What this fork changes

Upstream leaves two prompts generic: `note` fires on "anything new / worth
keeping", and `nap` says only "keep what has lasting effect, drop what does
not". In practice that yields event one-liners and vague pointers instead of
enough clues to find the detail again. OptMemo makes the pointer-first
contract explicit, in the text the tool actually prints.

- **Detail first, pointer after** (the `memo init` block). Parameters,
  decisions, attempts and why they failed, project history go into the file
  that owns them *before* `memo note`. The note carries the identifying
  topic, the exact file or section (never a bare directory), the conditions
  under which it applies, and any lesson, preference or hard rule.
- **A note is not a progress feed.** It records a durable entry or a
  standalone hard rule — not every event or step. A detail already covered by
  the same entry is not re-noted; a new or moved entry, a substantive change
  in its identifying clues, or a genuinely new long-term rule may be.
- **No pointer without the detail.** An agent must not write a pointer, or
  say a detail is saved, before the detail is actually written.
- **Compression rules** (the `memo nap` prompt) state that a compressed line
  is a pointer, not a retelling: it keeps each memory's topic, the exact file
  or section that holds the detail, its applicability and any lesson,
  preference or hard rule, and points to the detail instead of restating it.
  They merge pointers to one target, drop repeated progress, preserve
  correction / supersession precedence, and forbid dropping a unique detail
  unless the input shows the entry already holds it. Inventing facts stays
  forbidden and the byte limit is unchanged.

The agent keeps files and pointers in step; the user is not asked to file or
classify memories.

## Limits

- This is a **prompt change, not lossless compression and not a recall
  guarantee**. It cannot recover detail the agent never wrote down.
- The underlying detail exists only if the agent really writes it to a real
  file; a pointer is a clue, not storage.
- It does **not** retroactively shrink existing history. Old memories keep
  the text they were written with; the new rules apply to new notes and new
  compressions.
- Paging (`PART_CHARS` / `PART_LINES`) is a transport limit for the harness,
  not a token-saving metric and not a compression result.
- Storage format, the append-only `LOG.txt`, the binary `TREE`, the
  fixed-width records, and command compatibility are unchanged from upstream.

## Adopting this fork

Nothing below happens automatically.

1. Install this fork's tool (the `curl` line above) or copy its `memo` over
   `~/.optmem/memo`.
2. Run `~/.optmem/memo init` and replace the existing `## Memory` block in
   your `AGENTS.md` / `CLAUDE.md` with the one it prints.
3. If your `AGENTS.md` (or another rule file) already says when to note,
   remove or reconcile that text — otherwise it wins over the pasted block.

Until you do that, your current memory and behavior are unchanged.

## Commands

| | |
|---|---|
| `memo wake` | read the memory — the first command of every session |
| `memo note "..."` | record one memory: one line, up to 280 bytes |
| `memo nap` | answer the merges that came due |
| `memo recall <regex>` | search every memory ever recorded, word for word |
| `memo zoom <lo>-<hi>` | open a tree node into its two halves |
| `memo forget <lo>-<hi>` | drop a bad summary; the next nap rebuilds it |

Merges arrive one at a time, in the output of `note`. Nothing ever runs in the
background.

## Files

```
~/.optmem/
  memo          the tool: one file of Python 3, no dependencies
  memory/
    LOG.txt     every memory, one per line, append-only, never edited
    TREE/       the summaries: a cache, rebuildable from the log alone
    config      the sizes, written by `memo config`
```

```sh
memo config                  # show the sizes
memo config WAKE_LINES=300   # how many lines wake prints (96 ≈ 8k tokens)
memo config WAKE_LINES=      # back to the default
```

`WAKE_LINES` is the only size worth touching, and it is a reading budget, not
a storage budget: change it whenever, in either direction, and nothing is
recomputed.

Records are fixed width, so position *is* identity and every lookup is one
seek. At a million memories (608 MB), `wake` takes 0.03s.

Set `$MEMORY_DIR` to keep `memory/` elsewhere — a synced folder, a git repo.

## The prompt

This is what the installer prints, and the whole of the integration.

```markdown
## Memory

Your memory is OptMem:
- The tool is `~/.optmem/memo`
- Your memories are in `~/.optmem/memory`

OptMem outlives every session, compaction, model and vendor change.
Without it you do not know who you are, or what was decided and tried.

### At startup: activating OptMem (mandatory)

Run `~/.optmem/memo wake` before any other tool call, in every session, and
then do exactly what it prints, to the end of its output.

### While working: record memories (mandatory)

Write the detail first, then the pointer. Parameters, decisions, attempts
and why they failed, project history: put them in the file that owns them.
Then call `~/.optmem/memo note "<1 line, max 280 bytes>"` with what will find
that detail again: its topic, the exact file or section that holds it
(never a bare directory), when it applies, and any lesson, preference or
hard rule the session needs.

A note is not a progress feed: do not note every event, step or update.
Note a durable entry, or a hard rule that stands on its own. If a note
already points to the same entry, do not note it again unless the entry is
new or moved, its identifying clues changed, or it is a new long-term rule.
Never write a pointer, or say a detail is saved, before it is.

You keep files and pointers in step; the user does not file memories for
you.

If `~/.optmem/memo note` asks a compression: do it before your next action.

Never edit or delete anything under `~/.optmem/memory`: the tool manages it.

### When you need an old memory: search, or navigate

`~/.optmem/memo recall <regex>` searches every memory, word for word.

Your memories also form a binary tree: #0-1, #2-3 ... exist as one-line
summaries, pairs of those as #0-3, and so on -- every `#a-b` line wake
prints is one node of it. `~/.optmem/memo zoom <a-b>` opens a node into its
two halves, down to the raw memories.

### If you're a subagent: skip everything above

Parallel sessions on this machine are all you, and may all write memories.
A subagent is not: it must never run `memo`, because it cannot judge what
is already known, and its notes would arrive duplicated and incorrectly.
When you spawn one, write: `You are a subagent. Don't run memo.`
```
