import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show QuillController, Document;
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_bottom_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_content.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_top_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_controller_provider.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';

class EditorView extends StatefulWidget {
  const EditorView({super.key});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  QuillController? _quillController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _quillController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initQuillController(Document document) {
    setState(() {
      _quillController?.dispose();
      _quillController = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditorBloc, EditorState>(
      // listener for states
      listener: (context, state) {
        if (state is EditorLoaded &&
            !state.isContentLoading &&
            _quillController == null) {
          _initQuillController(state.quillDocument!);
        }
        if (state is EditorDiscarded) {
          if (state.noteId != null) {
            context.read<NotesBloc>().add(RefreshNote(noteId: state.noteId!));
          }
          Navigator.of(context).pop();
        }
        if (state is EditorSaveSuccess) {
          context.read<NotesBloc>().add(RefreshNote(noteId: state.noteId));
          Navigator.of(context).pop();
        }
        if (state is EditorDeleteRequest) {
          context.read<NotesBloc>().add(DeleteNotes(noteIds: [state.noteId]));
          Navigator.of(context).pop();
        }
        if (state is EditorFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizeError(context, state.error))),
          );
        }
      },
      // builder
      builder: (context, state) {
        if (state is EditorInitial) {
          return Scaffold(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,

            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is EditorLoaded ||
            state is EditorSaveSuccess ||
            state is EditorDiscarded ||
            state is EditorDeleteRequest) {
          final shell = Scaffold(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,

            appBar: const EditorTopBar(),
            body: _quillController == null
                ? const Center(child: CircularProgressIndicator())
                : const Stack(
                    children: [
                      Positioned.fill(child: EditorContent()),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: SafeArea(
                          top: false,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: EditorBottomBar(),
                          ),
                        ),
                      ),
                    ],
                  ),
          );

          if (_quillController != null) {
            return QuillControllerProvider(
              controller: _quillController!,
              focusNode: _focusNode,
              child: shell,
            );
          }

          return shell;
        }

        if (state is EditorFailure) {
          return Scaffold(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    localizeError(context, state.error),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.goBack,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
