# The plain-English test case format

## Contents
- Where test cases live
- The template
- The rules
- Why Setup completeness matters
- Worked example: a web application
- Worked example: a command-line tool
- Bad examples, and what is wrong with each

## Where test cases live

`docs/test-cases/<ticket-id>-<slug>.md` in the repository being worked on.

They are committed. They are a durable asset: the same file proves the failure before
the fix and proves the fix after, and it keeps working as a regression check for every
release that follows.

## The template

```markdown
# <short title, what the case checks>

## Setup
How to start the application. Exact commands. The URL to open.
Any account to sign in with. Everything needed to reach the starting screen.

## Steps
1. <one action a person could do>
2. <the next action>

## Expected
What should be seen after the last step. One observable outcome.
```

All three sections are required. A case missing any of them returns BLOCKED.

## The rules

**Plain English only.** No CSS selectors, no element IDs, no function names, no file
paths into the source. Write what a person would do, in the words they would use.

**Expected describes what a person sees.** Never what the code does. "The total reads
$0.00" is correct. "The `calculateTotal` function returns zero" is not.

**Never mention the bug, the ticket, or the fix.** The agent running this case must not
know which way the answer is supposed to fall. The moment it knows, it steers, and the
verdict stops meaning anything.

**One observable outcome.** If the case needs to check three things, it is three cases.
A case with three Expected outcomes cannot return a clean verdict.

**Steps are actions, not intentions.** "Click Save" is a step. "Save the record so it
persists" is two things: an action and a claim about what should happen. The claim
belongs in Expected, if anywhere.

## Why Setup completeness matters

An incomplete Setup produces BLOCKED. BLOCKED costs a whole round: the case comes back,
gets repaired, and gets rerun. Three BLOCKED verdicts on the same case stops the chain
and goes to a human.

Setup is complete when a stranger with access to the machine and no other knowledge
could reach the starting screen from it. Test it by reading it as that stranger. If you
find yourself supplying anything from memory, that thing belongs in Setup.

Common omissions: the port, the branch or build to run, which account to sign in with,
seed or fixture data the case depends on, and whether a service other than the app
itself has to be running.

## Worked example: a web application

```markdown
# A saved draft survives a page reload

## Setup
1. From the repository root, run: npm install
2. Start the application: npm run dev
3. Wait for the line "ready on http://localhost:3000".
4. Open http://localhost:3000 in a browser.
5. Sign in with email demo@example.com and password demo1234.

## Steps
1. Click "New note" in the left sidebar.
2. Type "grocery list" into the title field.
3. Type "apples and bread" into the body field.
4. Wait five seconds.
5. Reload the page in the browser.
6. Click "grocery list" in the left sidebar.

## Expected
The body field reads "apples and bread".
```

## Worked example: a command-line tool

```markdown
# The export command writes a file for an empty project

## Setup
1. From the repository root, run: npm install
2. Create an empty working directory: mkdir -p /tmp/export-case && cd /tmp/export-case
3. Initialise an empty project: npx myproject init

## Steps
1. Run: npx myproject export --out report.csv

## Expected
The command exits without an error message, and a file named report.csv exists in
/tmp/export-case containing a single header line and no data rows.
```

## Bad examples, and what is wrong with each

### Names a selector

```markdown
## Steps
1. Click the element matching button.btn-primary[data-testid="save"].
```

The agent is being driven through the DOM, not through the product. When the markup
changes, the case breaks even though the behavior did not. Write "Click Save".

### States the bug

```markdown
## Expected
The total does not show the wrong value any more.
```

Two faults. It tells the agent a bug exists, which is exactly the knowledge blindness
exists to withhold. And "not wrong" is not observable — there is nothing to look at.
Write what the screen should say: "The total reads $24.00".

### Setup omits the sign-in

```markdown
## Setup
Start the app and open http://localhost:3000.

## Steps
1. Open the billing page.
```

The billing page needs an account. The agent reaches a sign-in screen, has no
credentials, and returns BLOCKED. A whole round spent on a line that should have said
which account to use.
