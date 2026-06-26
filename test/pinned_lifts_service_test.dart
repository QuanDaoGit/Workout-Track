import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/pinned_lifts_service.dart';

/// The pin store: 3-max with block-and-tell, ordered, deduped, and the
/// stale-pin self-heal (so ghost pins can't deadlock the cap).
void main() {
  const service = PinnedLiftsService();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pins up to 3, then blocks the 4th with atCapacity', () async {
    expect(await service.pin('a'), PinResult.pinned);
    expect(await service.pin('b'), PinResult.pinned);
    expect(await service.pin('c'), PinResult.pinned);
    expect(await service.pin('d'), PinResult.atCapacity);
    expect(await service.getPinnedIds(), ['a', 'b', 'c']); // order preserved
  });

  test('unpinning frees a slot', () async {
    await service.pin('a');
    await service.pin('b');
    await service.pin('c');
    expect(await service.unpin('b'), PinResult.unpinned);
    expect(await service.getPinnedIds(), ['a', 'c']);
    expect(await service.pin('d'), PinResult.pinned); // slot freed
    expect(await service.getPinnedIds(), ['a', 'c', 'd']);
  });

  test('pin/unpin edge results', () async {
    expect(await service.pin(''), PinResult.notPinned);
    await service.pin('a');
    expect(await service.pin('a'), PinResult.alreadyPinned);
    expect(await service.unpin('zzz'), PinResult.notPinned);
    expect(await service.isPinned('a'), isTrue);
    expect(await service.isPinned('a'), isTrue);
  });

  test('toggle flips state', () async {
    expect(await service.toggle('a'), PinResult.pinned);
    expect(await service.isPinned('a'), isTrue);
    expect(await service.toggle('a'), PinResult.unpinned);
    expect(await service.isPinned('a'), isFalse);
  });

  test('dedupes + clamps a dirty stored list to 3 in order', () async {
    SharedPreferences.setMockInitialValues({
      'pinned_lift_ids_v1': ['a', '', 'a', 'b', 'c', 'd'],
    });
    expect(await service.getPinnedIds(), ['a', 'b', 'c']);
  });

  test('pruneTo drops ghost pins (no recoverable card) and persists', () async {
    await service.pin('a');
    await service.pin('b');
    await service.pin('c');
    // 'b' lost its trend (sessions deleted) → must not keep consuming a slot.
    final kept = await service.pruneTo({'a', 'c', 'x'});
    expect(kept, ['a', 'c']);
    expect(await service.getPinnedIds(), ['a', 'c']);
    expect(await service.pin('d'), PinResult.pinned); // slot recovered
  });

  test('pruneTo is a no-op when everything still exists', () async {
    await service.pin('a');
    await service.pin('b');
    final kept = await service.pruneTo({'a', 'b', 'c'});
    expect(kept, ['a', 'b']);
  });
}
