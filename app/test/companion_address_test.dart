import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/companion_address.dart';

void main() {
  group('bitAddress', () {
    test('name register returns the trimmed character name', () {
      expect(bitAddress(BitRegister.name, name: 'Nova'), 'Nova');
      expect(bitAddress(BitRegister.name, name: '  Kael  '), 'Kael');
    });

    test('name register falls back to "warrior" when the name is unusable', () {
      expect(bitAddress(BitRegister.name, name: null), 'warrior');
      expect(bitAddress(BitRegister.name, name: ''), 'warrior');
      expect(bitAddress(BitRegister.name, name: '   '), 'warrior');
    });

    test('honorific register is the epic honorific', () {
      expect(bitAddress(BitRegister.honorific), 'warrior');
      expect(bitAddress(BitRegister.honorific, name: 'Nova'), 'warrior');
    });

    test('recruit register is the pre-embodiment form', () {
      expect(bitAddress(BitRegister.recruit), 'recruit');
    });
  });
}
