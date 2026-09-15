# flirt-practice

A single-scene practice conversation for a man learning to talk to women he is
attracted to. A script draws a woman, a place and a situation at random; the
model plays her in character while you play yourself; the scene runs to a real
outcome and then you get a debrief on what you read, what you missed, and what
was against you before you opened your mouth.

Invoke it by asking to practise, or by name: `/flirt-practice`.

## What it is for

Perception, not technique. The model tracks her interest privately on a scale
you never see, moves it according to what you actually say, and plays her
behaviour off that number — so the exercise is learning to infer a hidden
state from behaviour, which is the thing that transfers to a real room.

Two design commitments follow from that, and both are deliberate:

**Roughly half of all draws end with no contact available.** The ceiling is
drawn before you speak. A simulation in which every woman can be unlocked by
the right sequence teaches that women are locks, which is false and is the
belief that makes men worse company. Reading a closed situation and leaving
cleanly is scored as a win.

**She is not always worth wanting.** Every draw carries two limitations —
ordinary ways an adult is narrower, duller or less pleasant than she looked at
forty seconds. They never move her interest, because they are hers and not
yours. They exist so the live question is not only whether she will have you.

## What it is not

Not a source of persuasion tactics, scripts, openers or routines. Not general
dating advice — it needs a scene. The debrief is written to be exact rather
than kind, and the closing rewrite is constrained against the pickup register:
no aloofness, no withheld warmth, nothing you would be embarrassed to have
overheard.

## Defaults, and how to change them

These are one user's settings. Change them; they are all in plain text files.

| Default | Where | To change |
|---|---|---|
| Age 20–40, peaked at 30 | `scripts/roll.sh`, age block | `AGE_MIN=20 AGE_MAX=60 bash scripts/roll.sh` for one draw, or edit the two defaults. The script floors `AGE_MIN` at 18 whatever you pass it. `tables/ages.txt` holds the original 19–68 band distribution, retained unused |
| Locale defaults to where you live | `SKILL.md`, step 1 | Say where you want to practise, or ask for a random one. `bash scripts/roll.sh ""` lists the available regions |
| Children drawn from age and locale | `tables/kids.txt` | Edit the weight rows. Baseline is a low-fertility European population; the `KIDS SHIFT` column in `locales.txt` moves it one step per locale |
| Foreigner rate, 4–40% by locale | `tables/locales.txt`, `FOREIGN %` column | Edit the percentage on any row |
| Two limitations per draw | `scripts/roll.sh`, `pick limitations.txt 2` | Change the count, or edit `tables/limitations.txt` |
| Ceiling: 20% hard-closed, 30% low, 50% open | `tables/tier.txt` | It is a bag of ten tokens; change the mix |
| Turn budget 8–30 exchanges | `scripts/roll.sh` | `TURNS=$(rnd 8 30)` |

A foreign origin is drawn from a different country, never from another row in
the same one — a woman from Lecce is not a foreigner in Bari, and the statuses
in `foreign_status.txt` assume she is not. Every locale row therefore carries
a `COUNTRY` in its last column; a row added without one will never be drawn
against.

Everything else is a table in `tables/` and can be edited without touching the
script: settings, situations, occupations, life stages, appearance, moods,
hooks, turn-offs, and the self-concept tables.

## The draw

`bash scripts/roll.sh [locale]` prints a complete scenario. A region may hold
several rows with different approach norms — `Puglia` matches Bari, Lecce and
the provincial coastal towns, and draws among them; pass the narrower string
to pin one.

The sheet has five layers: what is visible on turn one, what is reachable
through conversation, how she behaves, what she says about herself, and a
hidden layer revealed only in the debrief. The draw is final. Nothing in it
may be re-rolled or nudged toward something easier to write — the constraint
exists because a model given permission to repair a scenario will converge on
the same character every time.

## Files

```
SKILL.md                    instructions to the model
README.md                   this file
scripts/roll.sh             the draw
references/signals.md       how interest maps to behaviour
references/debrief.md       the debrief format
tables/                     everything the draw samples from
```
