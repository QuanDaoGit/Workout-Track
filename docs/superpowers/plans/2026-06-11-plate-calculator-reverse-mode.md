# Plate Calculator Reverse Mode — Design Spec

**Date:** 2026-06-11
**Status:** Approved
**Surfaces:** `lib/widgets/plate_calculator_sheet.dart`, `lib/services/plate_calculator.dart`,
`lib/pages/Workout session/exercise_session.dart`

## Problem

The plate calculator answers one question: "I want to lift X — what do I put on the bar?" It
cannot answer the inverse, which is just as common at the gym: "the bar is already loaded — what
am I lifting?" Today the user counts plates in their head and retypes the number into the weight
field.

## Decisions (locked in brainstorming)

1. **Two modes in one sheet**, switched by a segmented toggle at the top:
   - `TARGET → PLATES` — existing behavior, unchanged.
   - `PLATES → TOTAL` — new reverse mode.
2. **Interaction model: tap plate chips.** A row of denomination chips (from `plateSetFor`); each
   tap adds one plate of that denomination *per side*. The existing barbell visual renders the
   stack; tapping a plate on the bar removes that instance. A muted `CLEAR` button resets.
   (Stepper rows were considered and rejected — form-like, duplicates the barbell as passive
   output; chips mirror the physical act and keep the two modes visually symmetric.)
3. **USE WEIGHT button (reverse mode only).** Pops the sheet returning the computed total in
   canonical kg; the set-logging call site fills the weight field. Forward mode stays
   display-only — its target usually came *from* that field.

## Design

### Logic (`PlateCalculator`)

One new pure helper, symmetric with `platesPerSide` and unit-agnostic:

```dart
/// Total bar weight for a per-side stack: bar + 2 × sum(perSide).
static double totalWeight(List<double> perSide, {double barKg = defaultBarKg});
```

### Sheet (`PlateCalculatorSheet`)

- `enum _CalcMode { target, plates }`, defaults to `target` on every open (no persistence —
  YAGNI). Segmented toggle: selected segment = neon fill + `kBg` text, unselected = `kBorder`
  outline + muted text.
- The BAR field is shared between modes (single controller). Forward keeps the TARGET + BAR row;
  reverse shows BAR alone.
- Reverse body:
  - Chip row from `plateSetFor(Units.weight)` — works natively in the active unit, like the rest
    of the sheet. Tap = add one per side; the stack (`List<double>`) stays sorted descending.
  - `_BarbellView` renders the stack. In reverse mode each plate is wrapped in a tap target with
    a **minimum ~28 px hit width** (small plates render 8–14 px wide) that removes that plate.
  - `CLEAR` resets the stack; hidden/disabled when empty.
  - Total readout: large ShareTechMono number + unit label, with a muted breakdown line
    (`bar 20 + (20 + 10) × 2`) mirroring the forward mode's breakdown text.
  - `USE WEIGHT` (`FilledButton`). Empty stack is legal — bar-only warmups are real; total is
    then just the bar.
- `PlateCalculatorSheet.show` return type changes `Future<void>` → `Future<double?>`. USE WEIGHT
  pops with `displayToKg(total, unit)`; every other dismissal yields null.

### Call site (`exercise_session.dart`)

The single launch site awaits the result; non-null → write
`weightValue(kg, Units.weight)` into the row's weight controller and `setState`.

## Out of scope

- Persisting mode or stack across opens.
- Custom plate inventories / plate availability settings.
- Any change to forward-mode behavior or visuals.

## Testing

- Unit: `totalWeight` — empty stack = bar; mixed stack; lb numbers.
- Widget (`test/plate_calculator_sheet_test.dart`): mode toggle; chip adds build the stack and
  the total/breakdown update; bar-tap removes one instance; CLEAR empties; USE WEIGHT returns
  canonical kg through the `show` Future; lb-unit run (pin `Units` in `setUp`) with the lb plate
  set and 45 lb default bar.

## Verification

`flutter analyze` zero issues; `flutter test` full suite green; on-device: build a stack in
reverse mode, remove via bar tap, USE WEIGHT fills the weight field in the active unit.

## Amendments (on-device review, 2026-06-11)

1. The breakdown line under the reverse-mode total (`bar 45 + (25 + 10 + 5) x 2`) was removed —
   the big number stands alone.
2. The reverse-mode bar is the same mirrored two-side barbell as the forward mode (left stack +
   sleeve + right stack), not a single per-side stack. `_BarbellView` grew `onTapPlate` and
   `showWhenEmpty` params; the separate removable-stack widget was deleted.
3. The bar (with sleeve) is always visible in reverse mode, even with zero plates; the
   "Tap plates above to load the bar." placeholder was dropped.
4. The forward mode gained an `APPLY` button — disabled until the target parses, pops the sheet
   with the typed target in canonical kg so the call site fills the weight field (same return
   path as USE WEIGHT).
