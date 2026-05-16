import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/custom_exercise_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Mock the asset bundle for built-in exercises
    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'assets/exercises.json') {
          final json = jsonEncode([
            {'id': 'bench_press', 'name': 'Bench Press', 'level': 'intermediate', 'images': []},
            {'id': 'squat', 'name': 'Squat', 'level': 'intermediate', 'images': []},
          ]);
          return Uint8List.fromList(utf8.encode(json)).buffer.asByteData();
        }
        return null;
      },
    );
  });

  tearDown(() {
    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
  });

  group('saveCustomExercise', () {
    test('creates valid custom exercise', () async {
      final service = CustomExerciseService();
      await service.saveCustomExercise(
        name: 'My Press',
        muscleGroup: 'chest',
        exerciseType: 'weighted',
        userNote: 'A test exercise',
      );

      final exercises = await service.getCustomExercises();
      expect(exercises.length, 1);
      expect(exercises.first.name, 'My Press');
      expect(exercises.first.isCustom, true);
      expect(exercises.first.muscleGroup, 'chest');
      expect(exercises.first.exerciseType, 'weighted');
      expect(exercises.first.primaryMuscle, 'chest');
      expect(exercises.first.userNote, 'A test exercise');
      expect(exercises.first.id, startsWith('custom_'));
    });
  });

  group('isNameDuplicate', () {
    test('rejects duplicate name against custom exercises (case-insensitive)', () async {
      final service = CustomExerciseService();
      await service.saveCustomExercise(
        name: 'My Exercise',
        muscleGroup: 'chest',
        exerciseType: 'weighted',
      );

      expect(await service.isNameDuplicate('my exercise'), true);
      expect(await service.isNameDuplicate('MY EXERCISE'), true);
    });

    test('rejects duplicate name against built-in exercises', () async {
      final service = CustomExerciseService();
      expect(await service.isNameDuplicate('Bench Press'), true);
      expect(await service.isNameDuplicate('bench press'), true);
    });

    test('allows unique name', () async {
      final service = CustomExerciseService();
      expect(await service.isNameDuplicate('Totally New Exercise'), false);
    });

    test('excludeId skips the exercise being edited', () async {
      final service = CustomExerciseService();
      await service.saveCustomExercise(
        name: 'My Exercise',
        muscleGroup: 'chest',
        exerciseType: 'weighted',
      );

      final exercises = await service.getCustomExercises();
      final id = exercises.first.id;

      // Same name should be allowed when editing the same exercise
      expect(await service.isNameDuplicate('My Exercise', excludeId: id), false);
    });
  });

  group('updateCustomExercise', () {
    test('edits custom exercise', () async {
      final service = CustomExerciseService();
      await service.saveCustomExercise(
        name: 'Old Name',
        muscleGroup: 'chest',
        exerciseType: 'weighted',
      );

      final exercises = await service.getCustomExercises();
      final id = exercises.first.id;

      await service.updateCustomExercise(id, name: 'New Name', muscleGroup: 'back');
      final updated = await service.getCustomExercises();
      expect(updated.first.name, 'New Name');
      expect(updated.first.muscleGroup, 'back');
      expect(updated.first.primaryMuscle, 'lats');
    });
  });

  group('deleteCustomExercise', () {
    test('deletes custom exercise', () async {
      final service = CustomExerciseService();
      await service.saveCustomExercise(
        name: 'To Delete',
        muscleGroup: 'legs',
        exerciseType: 'bodyweight',
      );

      final exercises = await service.getCustomExercises();
      expect(exercises.length, 1);

      await service.deleteCustomExercise(exercises.first.id);
      final after = await service.getCustomExercises();
      expect(after, isEmpty);
    });
  });

  group('serialization', () {
    test('round-trip serialization preserves all fields', () async {
      final service = CustomExerciseService();
      await service.saveCustomExercise(
        name: 'Round Trip',
        muscleGroup: 'shoulders',
        exerciseType: 'weighted',
        userNote: 'Test note',
      );

      // Reload from SharedPreferences (simulates app restart)
      final loaded = await service.getCustomExercises();
      expect(loaded.first.name, 'Round Trip');
      expect(loaded.first.muscleGroup, 'shoulders');
      expect(loaded.first.exerciseType, 'weighted');
      expect(loaded.first.userNote, 'Test note');
      expect(loaded.first.primaryMuscle, 'shoulders');
      expect(loaded.first.isCustom, true);
      expect(loaded.first.createdAt, isNotNull);
    });
  });

  group('primaryMuscleFor', () {
    test('maps muscle groups correctly', () {
      expect(CustomExerciseService.primaryMuscleFor('chest'), 'chest');
      expect(CustomExerciseService.primaryMuscleFor('back'), 'lats');
      expect(CustomExerciseService.primaryMuscleFor('legs'), 'quadriceps');
      expect(CustomExerciseService.primaryMuscleFor('shoulders'), 'shoulders');
      expect(CustomExerciseService.primaryMuscleFor('arms'), 'biceps');
      expect(CustomExerciseService.primaryMuscleFor('core'), 'abdominals');
      expect(CustomExerciseService.primaryMuscleFor('full body'), 'chest');
    });
  });
}
