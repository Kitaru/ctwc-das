# CTWC DAS Limit
This is the source code for the DAS Limit rules used in the CTWC Jonas Cup 2024. It is adapted from the DAS mode in Kirjava's Tetris Gym which was used in CTWC DAS 2022-2024 events held in Germany.

The same general philosophy is shared between the previous Tetris Gym DAS mode and this version used in Jonas Cup. In the unmodified game of NES Tetris, the built-in Delayed AutoShift (DAS) is able to move pieces at a rate of ~10 times per second. The goal of DAS Mode is to enforce a "speed limit" by counting the number of times the player has tapped the d-pad, and locking out movement if a new tap in the input string is "ahead of schedule" for when the piece would be able to move that distance if DAS were used instead. A tap is measured as being part of the same string if it happens soon enough after the last, or as part of a new string after enough time has passed, a left/right direction change, or the appearance of a new piece.

The DAS mode used in Jonas Cup also features a few rules updates:

## Count Movement Taps, Not Raw Taps
The original Tetris Gym DAS Mode used the same tap counting code as the Hz count display, which is focused on the raw d-pad tapping speed. The Jonas Cup ruleset instead limits tapping speed based on the number of observed movements.

A potential issue with the previous method of counting raw taps is that a piece would likely dead drop in place if any one tap exceeds DAS limit; the player likely won't be allowed to make another attempt to move a piece, as the new tap would _also_ be further ahead of the raw tapping schedule. This would be particularly punishing if the fast taps were accidental (e.g., a d-pad misfire causing a normal tap to be read as an ultra fast double tap, which would prevent any further taps for a reason invisible to the player). This issue would be further compounded by taps counted at "negative delay" just before a new piece appears, as it would penalize the player for raw taps that did not actually move an active piece.

## DAS Movements Are Considered Implicit "First Taps"
The Jonas Cup ruleset counts any DAS shift as the potential "first tap" in a string. This ensures that tap strings that start after DAS usage are still limited to the appropriate schedule. This rule prevents double quicktaps. It also ensures the "Count Movements" rule change still appropriately counts "DAS buffered" first frame taps.

## Double Tap Speed is Unlimited
In order to allow single quicktaps under the new movement counting rules, the double tap speed cap was removed. I believe this change should not have undue negative impact on other game situations.

## Taps "Across the Border" of Schedule Are Given Leniency
If the player taps exactly one frame ahead of schedule, it is buffered out to the next frame if the d-pad direction is still held. The goal of this mechanic is to credit the player for inputs that average out to the allowed schedule. Without this rule, tapping exactly one frame early would be paradoxically punished harder than any other locked-out tap; it's physically impossible to release and re-tap on the next frame when the input would have been allowed.

## Simultaneous Left+Right is Considered Pressing Right
Although this is an highly unlikely scenario that should not occur on a well-maintained controller, the unmodified game of NES Tetris has a bug where tapping Left when Right is held will still move the piece to the right. This would hypothetically allow breaking the speed limit if alternating Right and Left+Right inputs were misread as a change in direction rather than continued rightward movement. As such, the tap string logic was updated to consider this the same as tapping Right alone.

# Related Works
* [kirjavascript's Tetris Gym](https://github.com/kirjavascript/TetrisGYM) - Tetris Gym's DAS Mode code served as the foundation for this project. Many thanks to Kirjava for discussion, code review, and feedback!  
* [ejona86's TAUS](https://github.com/ejona86/taus) - The toolchain in TAUS for building .ips patches are used by this project. The disassembly and debugging labels produced by TAUS were also important resources for ease of development.

# Appendix
**Tap String Timeout (frames)**: 16 (i.e., a tap is grouped into the existing string if it comes before the time it takes for DAS to charge if the direction were held)

**DAS Limit Schedule**:
The table below is defined such that the first movement is considered the frame #1 of the input string. Another way of expressing this information is that a that a tap should be locked out if it occurs before frame `1 + 6*(tap-1)` (if it is subject to limitation).
| taps | frames |
|------|--------|
|    1 |      - |
|    2 |     -\* |
|    3 |   13\*\* |
|    4 |     19 |
|    5 |     25 |
|    6 |     31 |
|    7 |     37 |
|    8 |     43 |
|    9 |     49 |

\* In Tetris Gym v6, a double tap is locked out if it is input before the 5th frame (15.02 Hz).  
\*\* In Tetris Gym v6, a triple tap is still allowed if it is input on the 12th frame (10.92 Hz).
