import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/core/utils/markdown_editor_styles.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:widgets/widgets.dart';

class EditorContent extends StatefulWidget {
  const EditorContent({super.key});

  @override
  State<EditorContent> createState() => _EditorContentState();
}

class _EditorContentState extends State<EditorContent> {
  late final ScrollController _scrollController;
  Timer? _autoSaveTimer;
  MarkdownEditorController? _lastController;
  bool _previousTextWasEmpty = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    initController();
  }

  void initController() {
    final state = context.read<EditorBloc>().state;
    if (state is EditorLoaded && state.isNewNote) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          final provider = MarkdownControllerProvider.maybeOf(context);
          provider?.focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = MarkdownControllerProvider.of(context).controller;
    if (_lastController != controller) {
      _lastController?.removeListener(_onChanged);
      _lastController = controller;
      _previousTextWasEmpty = controller.text.trim().isEmpty;
      _lastController?.addListener(_onChanged);
    }
  }

  void _ensureH1OnEmptyNoteTyping() {
    final controller = _lastController;
    if (controller == null) return;
    final text = controller.text;

    // If document was completely empty and user begins typing, format as H1
    if (_previousTextWasEmpty && text.isNotEmpty && !text.startsWith('#')) {
      final newText = '# $text';
      final newOffset = controller.selection.extentOffset + 2;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newOffset.clamp(0, newText.length),
        ),
      );
    }
    _previousTextWasEmpty = text.trim().isEmpty;
  }

  void _onChanged() {
    _ensureH1OnEmptyNoteTyping();
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _lastController == null) return;

      final markdown = _lastController!.text;

      context.read<EditorBloc>().add(
        EditorAutoSaveRequested(content: markdown),
      );
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _lastController?.removeListener(_onChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = MarkdownControllerProvider.of(context);

    return BlocListener<EditorBloc, EditorState>(
      listenWhen: (prev, curr) =>
          prev is EditorLoaded &&
          curr is EditorLoaded &&
          prev.title != curr.title,
      listener: (context, state) => _onChanged(),
      child: RepaintBoundary(
        child: LiveMarkdownEditor(
          controller: provider.controller,
          focusNode: provider.focusNode,
          scrollController: _scrollController,
          theme: markdownEditorTheme(context),
          behavior: const MarkdownEditingBehavior(
            autoPair: true,
            wrapSelection: true,
            smartLists: true,
            autoCloseFences: true,
          ),
          componentBuilders: MarkdownEditorComponentBuilders(
            taskToggleBuilder: (context, taskContext) =>
                _MechanixTaskToggle(taskContext: taskContext),
          ),
        ),
      ),
    );
  }
}

class _MechanixTaskToggle extends StatelessWidget {
  const _MechanixTaskToggle({required this.taskContext});
  final MarkdownTaskToggleContext taskContext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 20,
        height: 20,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: taskContext.enabled ? taskContext.onToggle : null,
          child: MechanixCheckbox(
            value: taskContext.checked,
            showFocusIndicator: false,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            checkColor: colorScheme.onPrimary,
            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primary;
              }
              return Colors.transparent;
            }),
            side: WidgetStateBorderSide.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const BorderSide(color: Colors.transparent, width: 0);
              }
              return BorderSide(color: colorScheme.onSurfaceVariant, width: 2);
            }),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
            onChanged: taskContext.enabled
                ? (_) => taskContext.onToggle()
                : null,
          ),
        ),
      ),
    );
  }
}
