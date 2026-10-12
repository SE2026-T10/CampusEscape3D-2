# Expanded Library — Human Playtest Protocol

The automated playtester (`tools/expanded/playtest_bot.gd`) measures what a bot can: timing, captures, where guards notice the player, softlocks. It can't tell how long a **person** needs the first time, or what confuses them. Those need people, and this form is for them.

**Who:** someone who has not seen the Expanded Library (ideally also not the tutorial), plus one person who knows the tutorial.
**Build:** the exported Windows build (`CampusEscape3D.exe`) or F5 in Godot 4.7.2.

## Before starting

- Don't explain the map, the objectives or the stealth rules. Say only: "Choose Expanded Library and try to finish it. Think aloud if you can."
- Have a stopwatch, or read the time from the win screen. Write down every capture.
- **Don't help.** If the player is stuck for more than 3 minutes, note it, and only then give the smallest hint.

## Record

| Field | Value |
|---|---|
| Date, tester (initials), build / commit | |
| Played the tutorial before? (yes / no) | |
| Completed? Time on the win screen | |
| Captures (win screen) | |
| Time at each objective (O1 … O5) | |
| Where each capture happened, and why (in the player's words) | |
| Moments of confusion (where, how long, what they were looking for) | |
| Guards or places that felt unfair (why) | |
| Navigation or interaction problems (stuck, missed a prompt, a door didn't open) | |
| Did they understand when they were seen? When they were hidden? | |
| Did they find the back gate shortcut? Did they understand why the exit was sealed? | |
| Did they use crouch? A hiding spot? A different stair? | |
| After a capture, did they understand where they were and what had been undone? | |
| Anything else | |

## Afterwards

Ask three questions:
1. "What was the hardest part?"
2. "When did you feel lost?"
3. "Was getting caught ever not your fault?"

Add the row to the table in `docs/expanded/phase-5-balance.md` ("Human playtests"). One result is an anecdote; three or more show a pattern.

## What the results decide

- **First completion under 20 minutes for most testers:** the level is shorter than the target. See "Pacing" in `phase-5-balance.md` for the adjustment plan.
- **Over 30 minutes, or more than about 8 captures:** look at where the captures cluster. The coverage maps in `docs/expanded/v3/coverage/` show which guard covers that spot.
- **Confusion at the same place for two or more testers:** fix the sign or hint there before touching any guard.
