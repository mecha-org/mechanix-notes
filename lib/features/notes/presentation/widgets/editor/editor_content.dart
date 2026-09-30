import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show Attribute, QuillController, QuillEditor, QuillEditorConfig;
import 'package:mechanix_notes/core/utils/quill_editor_styles.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_controller_provider.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_editor_checkbox.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';

class EditorContent extends StatefulWidget {
  const EditorContent({super.key});

  @override
  State<EditorContent> createState() => _EditorContentState();
}

class _EditorContentState extends State<EditorContent> {
  late final ScrollController _scrollController;
  Timer? _autoSaveTimer;
  QuillController? _lastController;

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
          final provider = QuillControllerProvider.maybeOf(context);
          provider?.focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = QuillControllerProvider.of(context).controller;
    if (_lastController != controller) {
      _lastController?.removeListener(_onChanged);
      _lastController = controller;
      _lastController?.addListener(_onChanged);
    }
  }

  void _onChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _lastController == null) return;

      context.read<EditorBloc>().add(
        EditorAutoSaveRequested(
          content: _lastController!.document.toDelta().toJson(),
          plainText: _lastController!.document.toPlainText(),
        ),
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
    final provider = QuillControllerProvider.of(context);

    return BlocListener<EditorBloc, EditorState>(
      listenWhen: (prev, curr) =>
          prev is EditorLoaded &&
          curr is EditorLoaded &&
          prev.title != curr.title,
      listener: (context, state) => _onChanged(),
      child: RepaintBoundary(
        child: QuillEditor(
          controller: provider.controller,
          focusNode: provider.focusNode,
          scrollController: _scrollController,
          config: QuillEditorConfig(
            customShortcuts: const {},
            showCodeBlockLineNumbers: false,
            placeholder: AppLocalizations.of(context)!.startWriting,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            customStyles: quillEditorStyle(context),
            expands: true,
            scrollable: true,
            autoFocus: false,
            // ignore: experimental_member_use
            customLeadingBlockBuilder: (node, config) {
              final attr = config.attribute;
              if (attr.value == Attribute.unchecked.value) {
                return QuillEditorCheckbox(
                  key: ObjectKey(node),
                  controller: provider.controller,
                  node: node,
                  config: config,
                  isChecked: false,
                );
              }
              if (attr.value == Attribute.checked.value) {
                return QuillEditorCheckbox(
                  key: ObjectKey(node),
                  controller: provider.controller,
                  node: node,
                  config: config,
                  isChecked: true,
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}
