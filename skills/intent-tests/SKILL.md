---
name: intent-tests
description: >
  Write tests for EXISTING code based on its INTENDED functionality (what the code was
  meant to do), not a mirror of what it currently does. The test is a specification of
  intent: on buggy code it should fail, exposing the gap. Use this skill whenever the
  user asks to write tests, unit tests, or test coverage for a function, method, or file;
  to "cover this with tests", "add tests for this", "write unit tests for X", or when they
  want tests that catch regressions/bugs in already-written functions. Trigger even if the
  user just says "add tests" or "test this function" without naming a framework — infer the
  stack and proceed. Also use when the user suspects a function behaves wrong and wants
  tests that pin down the correct behavior.
---

# Intent-Driven Tests

The point of this skill is the word **intent**. A test you write must encode what the
function *should* do, derived from its intended functionality. It must NOT be bent to make
the current (possibly buggy) implementation pass. When code is wrong, the test fails — that
failure is the bug signal, not a problem to paper over.

The flow has two human-interaction gates that make this safe:

1. **Clarify on doubt** — if you can't confidently recover the intended behavior, or you
   suspect the code doesn't do what was planned, ask the user *before* writing tests.
2. **Review then choose** — after the intent is clear, a read-only reviewer subagent checks
   the implementation. If it finds definite errors or suspicious spots, you report them and
   let the user pick: skip, accept the current behavior as intended, or launch a fixer
   subagent (possibly several variants when more than one correct fix exists).

## When to use

- User asks to write tests / unit tests / coverage for an existing function, method, or file.
- User wants tests that pin down *correct* behavior, especially when they suspect a bug.
- Do NOT use for: writing the implementation itself, or generating tests for code that
  doesn't exist yet (no target function to read). For brand-new code, write the function
  first, then run this.

## Workflow

### Step 1 — Scope and stack detection

1. **Decide the target.** This skill supports two scopes; let the user choose if not stated:
   - a single function/method the user names, or
   - a whole file/module (review every testable function in it).
   If the request is ambiguous, ask which.
2. **Detect language and test framework** by inspecting the project, not by assuming:
   - Python → pytest or unittest (`pyproject.toml`, `setup.cfg`, `requirements.txt`,
     `conftest.py`)
   - JS/TS → jest / vitest / mocha (`package.json` `"scripts.test"`, `jest.config.*`,
     `vitest.config.*`)
   - Go → `testing` (`go.mod`, `_test.go` neighbours)
   - Rust → `cargo test`
   - Java/Kotlin → JUnit (`build.gradle`, `pom.xml`)
   - others → match whatever the repo already uses.
3. **Detect test placement and import style.** Match an existing convention if one exists:
   co-located (`foo.test.js`, `test_foo.py`) vs a `tests/` directory; how tests import the
   target; fixture/helper patterns already in the repo. Reuse them — don't invent a new
   layout.
4. Read the target function(s) fully, plus their callers if reachable, to ground intent.

### Step 2 — Extract intended functionality

For each function, recover the intent from evidence, in this order of reliability:
signature and types → docstring/comments → how callers actually use it → naming → the
control flow itself (least reliable for *intent*, since it may encode a bug).

State the inferred intent explicitly as:
- a one-to-three sentence **spec** of what the function is for, and
- a bullet list of **behavior points**: inputs/contract (valid ranges, required state),
  outputs, side effects, and error/exception conditions.

Crucially, **separate intended from actual**. If the code does something that looks off,
write it down as a discrepancy, e.g. "code returns -1 on negative input, but intent appears
to be raising ValueError." That discrepancy is your cue for Step 3 and Step 4.

### Step 3 — Clarify on doubt

Ask the user when:
- the inferred intent is ambiguous or under-specified, OR
- you suspect the function does **not** do what was planned when it was written (the code
  looks like a bug, not a deliberate choice).

Use `ask_user_question` with concrete, decision-shaped options. Example (Russian end-users):
> Функция `safe_divide` при делении на 0 возвращает `None`, но в вызывающем коде результат
> используется в арифметике без проверки. Какое поведение задумывалось?
> - бросать `ZeroDivisionError`
> - возвращать `None` (текущее)
> - возвращать `float('inf')`

Rules:
- Prefer asking over guessing on any correctness-critical ambiguity.
- If intent is clear and matches the code, proceed without asking.
- A clarification may change the inferred spec — update it before moving on.

### Step 4 — Review via a read-only subagent reviewer

After the intent is established, review the *implementation* against that intent.

Spawn a reviewer subagent (the `agent` tool — `general-purpose` with a tight read-only
prompt, or a `fork` if full context helps). Scope it to the single function under test.
Give it the inferred spec from Step 2 and instruct it to report, read-only, on:

- **definite errors**: logic that contradicts the stated intent (off-by-one, wrong
  operator, inverted condition, wrong return on a branch, swallowed exception, mutation of
  shared state, type mismatch);
- **suspicious spots**: places likely buggy but not certain (unhandled edge input, an
  untested branch, a fragile assumption, an unchecked caller contract);
- for each: `location`, `problem`, `severity` (error / suspicion), and `why`.

The reviewer **must not modify code**. Return a structured findings list. If it reports
nothing, skip to Step 6.

### Step 5 — Report findings and offer choices

If the reviewer found definite errors or suspicious spots, present a concise report to the
user: each finding with location, the problem, and whether it's a definite bug or a
suspicion. Then offer a choice **for each finding (or grouped when related)**:

- **Skip** — leave the code as-is. Still write the test for the *intended* behavior. The
  test will likely fail; that failure is the expected bug signal. Say so explicitly.
- **Accept as correct** — the user confirms the current (maybe surprising) behavior *is* the
  intended one. Adjust the inferred spec to match the code, and write tests for that
  accepted behavior instead. Note the deviation in your summary.
- **Fix** — launch a fixer subagent.

**Fixer subagents and multiple valid approaches.** Enumerate the plausible *correct* ways to
fix the bug. There isn't always one right path.
- Exactly one clear approach → spawn **one** fixer subagent.
- Multiple valid approaches → present them as options. For each approach the user selects,
  spawn a **dedicated fixer subagent** (these can run in parallel). Each fixer must: state
  its approach, apply the minimal change, and explain why it matches the intent. The user
  then picks the resulting code they prefer (or keeps the original).

Every fixer subagent works only on the agreed fix; it reports the diff and a one-line
rationale. Re-read the function after any change before writing tests.

### Step 6 — Write tests for intended behavior

Write tests that assert the **intended** functionality (from Step 2, refined by Step 5):
- normal / representative cases,
- boundary and edge cases (empty, null/None, zero, max, off-by-one),
- error and exception paths the contract specifies,
- any documented side effects or state changes.

Follow the framework's conventions from Step 1. Keep assertions focused — one clear
behavior per test where practical. If the user chose "accept as correct" for a
discrepancy, encode the *accepted* behavior and record the deviation.

### Step 7 — Run and report

1. Run the new tests with the project's test command.
2. Report results with interpretation:
   - **Pass** → intended behavior is met (or accepted behavior, if applicable).
   - **Fail on a skipped bug** → expected; state plainly that the failure means the code
     doesn't meet intended behavior — that is the bug signal, not a test defect.
   - **Unexpected fail** → investigate; the intent inference or the test itself may be wrong.
3. Summarize: what was tested, the decisions taken (skipped / accepted / fixed), and any
   remaining risk the user should know about.

## Anti-patterns to avoid

- Writing tests that just mirror current (possibly buggy) behavior to get a green run.
- Skipping clarification when genuinely unsure — a wrong intent produces wrong tests.
- Letting the reviewer modify code, or applying fixes without the user's choice in Step 5.
- Inventing a new test layout when the repo already has one.
- Treating a failing intent-based test as something to "fix" by weakening the assertion.

## Notes

- Keep the agent's own context current: re-read the function after any fix before testing.
- The reviewer and fixer are separate subagents so the main agent stays the single
  decision-maker that talks to the user.
- This skill is language-agnostic on purpose: detect the stack in Step 1 rather than assuming.
