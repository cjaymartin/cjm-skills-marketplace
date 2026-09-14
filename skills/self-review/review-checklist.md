# Self-review checklist

## Contents
- Legitimacy
- Correctness and edge cases
- Error handling
- Tests
- Security and performance
- Style and accuracy

Each section is one reviewer's whole brief. A reviewer reads its own section and nothing
else, so each section is written to stand alone.

---

## Legitimacy

**Was this really a bug?**

- Which of the four backings applies: a specification line, a version where it worked,
  the commit that broke it, or evidence the old behavior harmed the reporter?
- If none applies, this change is a preference dressed as a fix. Say so.
- Is the code working as designed? A clean fix to intended behavior is still a change
  nobody asked for, and it will surprise whoever relied on that behavior.
- Does the diff fix the reported problem, or a different problem found on the way? Both
  can be worth doing. Only one is this ticket.
- Has the scope grown past what the ticket asked for?

This axis is checked first because a failure here makes every other axis irrelevant.

---

## Correctness and edge cases

- Empty input: empty string, empty list, empty file, zero rows.
- Null and undefined, at every boundary the change touches.
- Boundaries: the first item, the last item, one before, one past. Off-by-one.
- Unusual but legal input: very large values, negative numbers, unicode, whitespace-only
  strings, duplicate keys.
- Concurrency, where two of these can run at once: what happens if they do?
- Time and ordering: does anything assume events arrive in order, or that a clock only
  moves forward?

For each one found: name the input and what happens, not just the category.

---

## Error handling

- Is every failure surfaced, or is one swallowed?
- Any path that still fails silently — a caught exception with an empty handler, a
  return value nobody checks, a promise nobody awaits.
- Messages that mislead: an error that names the wrong cause is worse than no message,
  because it sends the next reader somewhere else.
- Dead or redundant handlers: code that can no longer be reached after this change.
- Does a partial failure leave state half-written?

---

## Tests

- **Do they assert the behavior, or pass for the wrong reason?** An assertion that
  recomputes the expected value the same way the code does can never disagree with the
  code. Expected values must come from an independent source: a known-good literal, a
  worked example, the specification.
- **Were they red-greened?** Would each test have failed before this change? If a test
  passes against the old code, it is not testing this fix.
- **Flaky or brittle?** Does anything depend on timing, ordering, network, the clock, or
  the machine it runs on?
- **Implementation-coupled?** Does it mock internal collaborators, reach into private
  methods, or verify through a side channel such as querying the database instead of
  using the interface? The tell is a test that breaks on refactor when behavior did not
  change.
- **Coverage gaps** on the headline behavior and, more often missed, on its failure
  path.

---

## Security and performance

- New input that reaches a query, a command, a path, or a template without escaping.
- Secrets, tokens, or personal data in logs, error messages, or URLs.
- Authorisation: does the change let a caller reach something it could not reach before?
- A loop that now runs per row where it used to run once. A query inside a loop.
- Unbounded growth: a list, cache, or file that nothing trims.
- Work moved onto a hot path, or onto the first render.

---

## Style and accuracy

- Consistency with the code immediately around it, not with a general preference.
- Comments that no longer match what the code does. A stale comment is a lie with a
  long life.
- Documentation claims: check the ones this change touches against what it now does.
- Names that do not say what the thing is or holds.
- Anything the repository's own documented standards cover — those win over anything
  here.
- Skip anything the tooling already enforces. A linter finding is not a review finding.
