# Writing standard

Everything these skills produce is read by a person under time pressure: a research
brief, a test case, a review finding, a commit message. Write all of it in **Simplified
Technical English** (ASD-STE100), the controlled language aerospace has used since 1983.

## The rules that matter most here

- **Short sentences.** 20 words or fewer for an instruction. 25 for a description.
- **One instruction per sentence.** Two steps means two sentences.
- **Active voice.** "Run the test", not "The test should be run".
- **Start an instruction with the verb.** "Open the file." "Delete the row."
- **One word for one thing.** Do not swap synonyms for variety. Pick "start" and keep it.
- **Simple tenses.** Say "when you run", not "when running".
- **No jargon, idioms, or slang.** If a technical term cannot be avoided, explain it in
  plain words immediately after.
- **Short paragraphs, one topic each.** Use a list for steps.
- **Say the answer first.** Then the detail.

## What stays exact

Paths, commands, filenames, code, identifiers, and numbers are copied exactly and never
reworded. The standard governs the words around them, not the code itself.

## Why this is in a repository about testing

A test case that can be read two ways produces a BLOCKED verdict, and BLOCKED costs a
whole round. A research brief that hides its finding under qualifiers gets skimmed, and
the human gate it feeds gets rubber-stamped. Clear writing is not decoration here. It is
what makes the gates work.

## The full standard

All 53 numbered rules, the approved vocabulary, and a word-choice linter live in the
`simple-english` skill: https://github.com/AminBlg/SimpleEnglish

If that skill is installed, call it with the Skill tool and follow it. This file is the
short form for when it is not.
