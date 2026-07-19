import 'package:flutter/material.dart';
import '../widgets/arcade_filled.dart';
import '../theme/app_fonts.dart';

import '../data/muscle_groups.dart';
import '../models/workout_models.dart';
import '../services/custom_exercise_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_chip.dart';
import '../widgets/motion/arcade_text_field.dart';
import '../widgets/pixel_button.dart';

/// Muscle groups available for custom exercises — same canonical 7-bucket set
/// used everywhere else in the app.
const List<String> customMuscleGroups = canonicalMuscleGroups;

class CreateExercisePage extends StatefulWidget {
  const CreateExercisePage({super.key, this.exercise});

  /// If non-null, page opens in edit mode with fields pre-filled.
  final Exercise? exercise;

  bool get isEditing => exercise != null;

  @override
  State<CreateExercisePage> createState() => _CreateExercisePageState();
}

class _CreateExercisePageState extends State<CreateExercisePage> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _customService = CustomExerciseService();

  String? _selectedMuscleGroup;
  String? _selectedType;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final ex = widget.exercise!;
      _nameController.text = ex.name;
      _noteController.text = ex.userNote ?? '';
      _selectedMuscleGroup = ex.muscleGroup;
      _selectedType = ex.exerciseType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _selectedMuscleGroup != null &&
      _selectedType != null;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'NAME CANNOT BE EMPTY');
      return;
    }

    final isDuplicate = await _customService.isNameDuplicate(
      name,
      excludeId: widget.exercise?.id,
    );
    if (isDuplicate) {
      setState(() => _errorText = 'NAME ALREADY EXISTS');
      return;
    }

    setState(() {
      _errorText = null;
      _saving = true;
    });

    if (widget.isEditing) {
      await _customService.updateCustomExercise(
        widget.exercise!.id,
        name: name,
        muscleGroup: _selectedMuscleGroup!,
        exerciseType: _selectedType!,
        userNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    } else {
      await _customService.saveCustomExercise(
        name: name,
        muscleGroup: _selectedMuscleGroup!,
        exerciseType: _selectedType!,
        userNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'EDIT EXERCISE' : 'CREATE EXERCISE'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // NAME
          Text(
            'NAME',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 8),
          ArcadeTextField(
            controller: _nameController,
            maxLength: 40,
            onChanged: (_) => setState(() => _errorText = null),
            style: AppFonts.shareTechMono(color: kText, fontSize: 14),
            hintText: 'exercise name',
            hintStyle: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
            counterText: '',
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorText!,
              style: AppFonts.shareTechMono(color: kDanger, fontSize: 11),
            ),
          ],

          const SizedBox(height: 20),

          // MUSCLE GROUP
          Text(
            'MUSCLE GROUP',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in customMuscleGroups)
                ArcadeChip(
                  label: group.toUpperCase(),
                  selected: _selectedMuscleGroup == group,
                  onTap: () => setState(() => _selectedMuscleGroup = group),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // TYPE
          Text(
            'TYPE',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ArcadeChip(
                label: 'WEIGHTED',
                selected: _selectedType == 'weighted',
                onTap: () => setState(() => _selectedType = 'weighted'),
              ),
              ArcadeChip(
                label: 'BODYWEIGHT',
                selected: _selectedType == 'bodyweight',
                onTap: () => setState(() => _selectedType = 'bodyweight'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // NOTE
          Text(
            'NOTE',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            'form cues, setup, anything you want to remember',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
          const SizedBox(height: 8),
          ArcadeTextField(
            controller: _noteController,
            maxLength: 200,
            height: null,
            maxLines: 3,
            counterText: null,
            style: AppFonts.shareTechMono(color: kText, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),

          const SizedBox(height: 24),

          // SAVE
          PixelButton(
            label: widget.isEditing ? 'SAVE' : 'SAVE',
            powerOn: true,
            onPressed: _isValid && !_saving ? _save : null,
            isLoading: _saving,
          ),
          const SizedBox(height: 8),
          Center(
            child: ArcadeTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CANCEL',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
