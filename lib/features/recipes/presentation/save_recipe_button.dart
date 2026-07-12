import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../domain/recipe.dart';
import '../providers/saved_recipe_providers.dart';

/// Runder Bookmark-Toggle für den Rezept-Detail-Screen.
/// Lädt selbst den Initial-Status und speichert/entfernt bei Tap.
class SaveRecipeButton extends ConsumerStatefulWidget {
  const SaveRecipeButton({super.key, required this.recipe});
  final Recipe recipe;

  @override
  ConsumerState<SaveRecipeButton> createState() => _SaveRecipeButtonState();
}

class _SaveRecipeButtonState extends ConsumerState<SaveRecipeButton> {
  bool? _saved; // null = lädt noch
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await ref
        .read(savedRecipeRepositoryProvider)
        .isSaved(widget.recipe.title);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _toggle() async {
    if (_busy || _saved == null) return;
    setState(() => _busy = true);
    final repo = ref.read(savedRecipeRepositoryProvider);
    try {
      if (_saved == true) {
        await repo.unsaveByTitle(widget.recipe.title);
        if (mounted) setState(() => _saved = false);
      } else {
        await repo.save(widget.recipe);
        if (mounted) setState(() => _saved = true);
      }
      ref.invalidate(savedRecipesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _saved == true
                  ? 'Rezept gespeichert'
                  : 'Aus Gespeicherten entfernt',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final isSaved = _saved == true;

    return Material(
      color: isSaved ? GSColors.primary : surfaceColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _toggle,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSaved ? GSColors.primary : lineColor,
            ),
          ),
          child: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: isSaved ? GSColors.cream : inkColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}
