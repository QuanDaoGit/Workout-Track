# Avatar Selection — Class Tie-In + Live Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make avatar selection feel like choosing *your* fighter instead of picking a thumbnail. Tie the screen to the class the user just earned: a class-colored selection frame on tiles, a larger live preview of the chosen avatar framed in the class color, and a class-name label. No new art — same 8 faces.

**Architecture:** `lib/pages/onboarding/avatar_select_screen.dart`. The draft carries the class: `widget.draft.calibration.clazz` (a `CharacterClass`), with `.themeColor` / `.displayName` extensions in `lib/models/character_class.dart`. We (1) import that model, (2) compute `accentColor`/`clazz` once in the build, (3) insert a 120×120 live preview (class-framed) + class label between the prompt and the grid, and (4) thread `accentColor` into `_AvatarRow`→`_AvatarTile` so the selected tile border and star use the class color instead of `kNeon`. The preview uses `Image.asset` (an `Image`, not an `ImageIcon`), so the existing test that counts `ImageIcon` (the single selection star) stays valid.

**Tech Stack:** Flutter / Dart. Tests via `flutter test`. Lint via `flutter analyze`.

**Design decision (locked):** "Frame + preview, same 8 faces" — class-colored frame + larger live preview + class label. No reframed copy ("CHOOSE YOUR FACE" prompt stays), no new portrait assets.

---

### Task 1: Class-color the tile selection (border + star)

**Files:**
- Modify: `lib/pages/onboarding/avatar_select_screen.dart` (`_AvatarRow` ~279-309, `_AvatarTile` ~311-372, and the two `_AvatarRow(...)` call sites ~165-183)

- [ ] **Step 1: Add `accentColor` to `_AvatarTile` and use it for border + star**

In `_AvatarTile`, add the field + constructor param:

```dart
class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.option,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.accentColor,
  });

  final AvatarOption option;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;
```

In its `build`, change the border color (~341-344) from `selected ? kNeon : kBorder` to `selected ? accentColor : kBorder`:

```dart
            border: Border.all(
              color: selected ? accentColor : kBorder,
              width: selected ? 2 : 1,
            ),
```

and the star `ImageIcon` color (~356-364) from `color: kNeon` to `color: accentColor`:

```dart
              if (selected)
                Positioned(
                  right: 4,
                  top: 4,
                  child: ImageIcon(
                    const AssetImage('assets/icons/control/icon_star.png'),
                    size: 8,
                    color: accentColor,
                  ),
                ),
```

(Note: the `const` moves off `Positioned` because `accentColor` is now runtime — keep `const` on the inner `AssetImage` only, as shown.)

- [ ] **Step 2: Thread `accentColor` through `_AvatarRow`**

Add the field + param to `_AvatarRow`:

```dart
class _AvatarRow extends StatelessWidget {
  const _AvatarRow({
    required this.options,
    required this.startIndex,
    required this.selectedAvatarId,
    required this.onSelect,
    required this.accentColor,
  });

  final List<AvatarOption> options;
  final int startIndex;
  final String? selectedAvatarId;
  final void Function(AvatarOption option, int index) onSelect;
  final Color accentColor;
```

and forward it in the `_AvatarTile(...)` it builds (~298-303):

```dart
          _AvatarTile(
            option: options[i],
            index: startIndex + i,
            selected: selectedAvatarId == options[i].id,
            onTap: () => onSelect(options[i], startIndex + i),
            accentColor: accentColor,
          ),
```

- [ ] **Step 3: Pass the class color at the two call sites**

At the top of the `AnimatedBuilder` `builder` in `_AvatarSelectScreenState.build` (just after `bottomRowProgress` is computed, ~137), add:

```dart
            final accentColor = widget.draft.calibration.clazz.themeColor;
```

Then in both `_AvatarRow(...)` calls (inside the two `_AvatarRowReveal`s, ~166-182), add `accentColor: accentColor,` to each, e.g.:

```dart
                          child: _AvatarRow(
                            options: onboardingAvatarOptions.sublist(0, 4),
                            startIndex: 0,
                            selectedAvatarId: _selectedAvatarId,
                            onSelect: _selectAvatar,
                            accentColor: accentColor,
                          ),
```

and identically for the bottom row (`sublist(4, 8)`, `startIndex: 4`).

- [ ] **Step 4: Add the import**

At the top of the file, add (after the existing model import on ~line 5):

```dart
import '../../models/character_class.dart';
```

- [ ] **Step 5: Verify compile + existing tests still pass**

Run: `flutter analyze`
Expected: no new issues.
Run: `flutter test test/avatar_select_screen_test.dart`
Expected: PASS — the star is still exactly one `ImageIcon`; only its color changed (assassin cyan for the `_draft`, whose class is `CharacterClass.assassin`).

- [ ] **Step 6: Commit**

```bash
git add lib/pages/onboarding/avatar_select_screen.dart
git commit -m "feat(onboarding): class-color the avatar tile selection

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Add the live class-framed preview + class label

**Files:**
- Modify: `lib/pages/onboarding/avatar_select_screen.dart` (`_AvatarSelectScreenState.build`, between the prompt and the grid)
- Test: `test/avatar_select_screen_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/avatar_select_screen_test.dart`, add this test (after the `'selecting an avatar enables commit and shows star indicator'` test):

```dart
  testWidgets('selecting an avatar shows the class preview label', (
    tester,
  ) async {
    await _pumpAvatarScreen(tester);

    // Nothing chosen yet → preview prompts the user.
    expect(find.text('PICK ONE'), findsOneWidget);
    expect(find.text('ASSASSIN'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Avatar 3 of eight'));
    await tester.pumpAndSettle();

    // Preview now names the class derived earlier (draft class = assassin).
    expect(find.text('ASSASSIN'), findsOneWidget);
    expect(find.text('PICK ONE'), findsNothing);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/avatar_select_screen_test.dart --plain-name "class preview label"`
Expected: FAIL — `Found 0 widgets with text "PICK ONE"` (no preview exists yet).

- [ ] **Step 3: Compute the selected option in the builder**

In `_AvatarSelectScreenState.build`, directly below the `final accentColor = ...` line added in Task 1 Step 3, add:

```dart
            final clazz = widget.draft.calibration.clazz;
            final selectedOption = _selectedAvatarId == null
                ? null
                : onboardingAvatarOptions.firstWhere(
                    (o) => o.id == _selectedAvatarId,
                    orElse: () => onboardingAvatarOptions.first,
                  );
```

- [ ] **Step 4: Insert the preview between prompt and grid**

Find the `SizedBox(height: 32)` that sits *after* the prompt `Padding` and *before* the `Center(child: SizedBox(width: 356, ...))` grid (~159). Replace that single `const SizedBox(height: 32),` with the preview block:

```dart
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: kCard,
                          border: Border.all(
                            color: selectedOption != null ? accentColor : kBorder,
                            width: selectedOption != null ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(kCardRadius),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: selectedOption == null
                            ? null
                            : Image.asset(
                                selectedOption.assetPath,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedOption == null ? 'PICK ONE' : clazz.displayName,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                          color: selectedOption == null
                              ? kMutedText
                              : accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/avatar_select_screen_test.dart --plain-name "class preview label"`
Expected: PASS.

- [ ] **Step 6: Run the full avatar test file (regression)**

Run: `flutter test test/avatar_select_screen_test.dart`
Expected: PASS — every test. Confirm the `ImageIcon` count test still passes: the preview uses `Image.asset` (`Image`), the star remains the only `ImageIcon`.

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 8: Commit**

```bash
git add lib/pages/onboarding/avatar_select_screen.dart test/avatar_select_screen_test.dart
git commit -m "feat(onboarding): live class-framed avatar preview with class label

A 120px preview of the chosen face, framed in the class identity color
with the class name beneath, ties avatar selection to the earned class.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** class-colored tile frame + star (Task 1) ✓; larger live preview framed in class color (Task 2) ✓; class-name label / "copy that names the class" (Task 2 label) ✓; same 8 faces / no new art ✓; "CHOOSE YOUR FACE" prompt unchanged ✓.
- **Placeholder scan:** none.
- **Type consistency:** `accentColor` is `Color` everywhere (`_AvatarRow`, `_AvatarTile`, builder local). `selectedOption` is `AvatarOption?`; `.assetPath` is `String`. `clazz.displayName` → `String`, `clazz.themeColor` → `Color`. The `Image.asset` preview is an `Image` widget — the avatar test counts `ImageIcon`, so no collision.
- **Layout note (manual check):** the preview adds ~120 + 8 + ~14 (label) + 48 (two 24px gaps) ≈ 190px between prompt and grid. The screen uses a `Spacer()` before the button, so it absorbs the difference on tall phones. On a 375×667 device the `Spacer` may shrink to near-zero; verify on a small-screen screenshot that the grid + button aren't clipped. If clipped, reduce the two preview gaps from 24→16 (no other change). No code change unless the screenshot shows clipping.
