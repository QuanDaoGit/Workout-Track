# Adventure Home Loader Incident - 2026-06-13

## Symptom

Home stayed on the centered `PixelLoader` forever, while other tabs/pages still worked normally.
The page was not visually frozen; the Home data load failed before it could flip `_loading` to
`false`.

## Runtime Evidence

Chrome DevTools on the running Flutter web tab showed:

```text
RangeError: max must be in range 0 < max <= 2^32, was 0
```

The stack pointed through:

```text
AdventureService.bootId
AdventureService.new
HomePage._loadData
```

## Source

`AdventureService.bootId` used:

```dart
Random().nextInt(1 << 32)
```

That is a desktop/VM-style integer expression. In the Flutter web build it reached `nextInt` as
`0`, so constructing `AdventureService()` threw before `loadState()` could run.

## How The Approach Led Here

The Adventure implementation mostly tested service behavior with an explicit `bootIdOverride`.
That is useful for deterministic settlement tests, but it skipped the default constructor path
Home uses in production. The risky part was also platform-sensitive: Dart VM tolerated the shape,
but the compiled web runtime did not.

The Home loader amplified the problem. `_loadData()` awaited many services in sequence and only
set `_loading = false` at the end. Adventure is an optional Home module, but its read sat on the
critical path, so a non-critical constructor error blocked the whole dashboard.

## Improvements

- Avoid large bit-shift RNG bounds in app code that runs on Flutter web. Prefer simple, explicit
  positive bounds for decorative/session ids.
- Test default constructors, especially when production UI uses them and tests usually inject
  overrides.
- Keep optional Home modules fail-soft. One feature card should disappear or skip its ceremony
  rather than prevent Home from rendering.
- Add regression coverage for "fresh state, default service, Home renders" paths, not only the
  successful feature-specific flow.
