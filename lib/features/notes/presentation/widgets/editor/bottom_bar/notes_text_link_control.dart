import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:widgets/widgets.dart';

/// Defines the active mode in [NotesTextLinkControl].
enum NotesBottomBarMode {
  /// Text formatting mode is active.
  text,

  /// Link editing/insertion mode is active.
  link,
}

/// A Notes-specific bottom bar control providing Text/Link toggles
/// and a contextual small square button adjacent to the active mode.
class NotesTextLinkControl extends StatefulWidget {
  const NotesTextLinkControl({
    super.key,
    this.mode,
    this.initialMode = NotesBottomBarMode.text,
    this.onModeChanged,
    this.onTextContextualPressed,
    this.isTextContextualActive = false,
    this.onH2Pressed,
    this.isH2Active = false,
    this.onBodyPressed,
    this.isBodyActive = false,
    this.onBoldPressed,
    this.isBoldActive = false,
    this.onItalicPressed,
    this.isItalicActive = false,
    this.onUnderlinePressed,
    this.isUnderlineActive = false,
    this.onStrikethroughPressed,
    this.isStrikethroughActive = false,
    this.onChecklistPressed,
    this.isChecklistActive = false,
    this.onLinkContextualPressed,
    this.onImagePressed,
    this.onFilePressed,
    this.onCodePressed,
    this.isCodeActive = false,
    this.onMusicPressed,
    this.size = IconButtonSize.small,
    this.spacing = 8.0,
    this.enabled = true,
  });

  /// The active mode when controlled externally (optional).
  final NotesBottomBarMode? mode;

  /// The initial mode when uncontrolled. Defaults to [NotesBottomBarMode.text].
  final NotesBottomBarMode initialMode;

  /// Callback fired when the user toggles between Text and Link modes.
  final ValueChanged<NotesBottomBarMode>? onModeChanged;

  /// Callback when the Text contextual button is tapped.
  final VoidCallback? onTextContextualPressed;

  /// Whether the Text contextual (H1) format is currently active.
  final bool isTextContextualActive;

  /// Callback when the H2 button is tapped.
  final VoidCallback? onH2Pressed;

  /// Whether the H2 format is currently active.
  final bool isH2Active;

  /// Callback when the Body (Normal text) button is tapped.
  final VoidCallback? onBodyPressed;

  /// Whether Normal text / paragraph format is currently active.
  final bool isBodyActive;

  /// Callback when the Bold button is tapped.
  final VoidCallback? onBoldPressed;

  /// Whether Bold formatting is currently active.
  final bool isBoldActive;

  /// Callback when the Italic button is tapped.
  final VoidCallback? onItalicPressed;

  /// Whether Italic formatting is currently active.
  final bool isItalicActive;

  /// Callback when the Underline button is tapped.
  final VoidCallback? onUnderlinePressed;

  /// Whether Underline formatting is currently active.
  final bool isUnderlineActive;

  /// Callback when the Strikethrough button is tapped.
  final VoidCallback? onStrikethroughPressed;

  /// Whether Strikethrough formatting is currently active.
  final bool isStrikethroughActive;

  /// Callback when the Checklist button is tapped.
  final VoidCallback? onChecklistPressed;

  /// Whether Checklist formatting is currently active.
  final bool isChecklistActive;

  /// Callback when the Link contextual button is tapped.
  final VoidCallback? onLinkContextualPressed;

  /// Callback when the Image button is tapped.
  final VoidCallback? onImagePressed;

  /// Callback when the File button is tapped.
  final VoidCallback? onFilePressed;

  /// Callback when the Code block button is tapped.
  final VoidCallback? onCodePressed;

  /// Whether Code block format is currently active.
  final bool isCodeActive;

  /// Callback when the Music button is tapped.
  final VoidCallback? onMusicPressed;

  /// Sizing scale for the icon buttons. Defaults to [IconButtonSize.small].
  final IconButtonSize size;

  /// Horizontal spacing between buttons. Defaults to `8.0`.
  final double spacing;

  /// Whether the controls are enabled. Defaults to `true`.
  final bool enabled;

  @override
  State<NotesTextLinkControl> createState() => _NotesTextLinkControlState();
}

class _NotesTextLinkControlState extends State<NotesTextLinkControl> {
  late NotesBottomBarMode _uncontrolledMode;

  NotesBottomBarMode get _effectiveMode => widget.mode ?? _uncontrolledMode;

  @override
  void initState() {
    super.initState();
    _uncontrolledMode = widget.initialMode;
  }

  void _handleModeSelected(NotesBottomBarMode newMode) {
    if (!widget.enabled || _effectiveMode == newMode) return;

    if (widget.mode == null) {
      setState(() {
        _uncontrolledMode = newMode;
      });
    }
    widget.onModeChanged?.call(newMode);
  }

  @override
  Widget build(BuildContext context) {
    final isTextMode = _effectiveMode == NotesBottomBarMode.text;
    final spacingWidget = SizedBox(width: widget.spacing);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeToggleGroup(
          key: const Key('notes_mode_toggle_group'),
          isTextMode: isTextMode,
          size: widget.size,
          spacing: widget.spacing,
          enabled: widget.enabled,
          onModeSelected: _handleModeSelected,
        ),
        const SizedBox(width: 12),
        if (isTextMode) ...[
          _ContextualButton(
            buttonKey: const Key('notes_text_contextual_button'),
            isSelected: widget.isTextContextualActive,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.h1Icon)),
            onPressed: widget.onTextContextualPressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_text_h2_button'),
            isSelected: widget.isH2Active,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.h2Icon)),
            onPressed: widget.onH2Pressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_text_body_button'),
            isSelected: widget.isBodyActive,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.textstyleIcon)),
            onPressed: widget.onBodyPressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_text_bold_button'),
            isSelected: widget.isBoldActive,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.boldIcon)),
            onPressed: widget.onBoldPressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_text_italic_button'),
            isSelected: widget.isItalicActive,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.italicIcon)),
            onPressed: widget.onItalicPressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_text_underline_button'),
            isSelected: widget.isUnderlineActive,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.underlineIcon)),
            onPressed: widget.onUnderlinePressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_text_strikethrough_button'),
            isSelected: widget.isStrikethroughActive,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.strikethroughIcon)),
            onPressed: widget.onStrikethroughPressed,
          ),
        ] else ...[
          _ContextualButton(
            buttonKey: const Key('notes_link_image_button'),
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.imageIcon)),
            onPressed: widget.onImagePressed ?? widget.onLinkContextualPressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_link_file_button'),
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.fileIcon)),
            onPressed: widget.onFilePressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_link_code_button'),
            isSelected: widget.isCodeActive,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.codeBlockIcon)),
            onPressed: widget.onCodePressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_link_checklist_button'),
            isSelected: widget.isChecklistActive,
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.todoIcon)),
            onPressed: widget.onChecklistPressed,
          ),
          spacingWidget,
          _ContextualButton(
            buttonKey: const Key('notes_link_music_button'),
            size: widget.size,
            enabled: widget.enabled,
            icon: const ImageIcon(AssetImage(NotesIcon.musicIcon)),
            onPressed: widget.onMusicPressed,
          ),
        ],
      ],
    );
  }
}

class _ModeToggleGroup extends StatelessWidget {
  const _ModeToggleGroup({
    super.key,
    required this.isTextMode,
    required this.size,
    required this.spacing,
    required this.enabled,
    required this.onModeSelected,
  });

  final bool isTextMode;
  final IconButtonSize size;
  final double spacing;
  final bool enabled;
  final ValueChanged<NotesBottomBarMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MechanixIconButton.filled(
            key: const Key('notes_text_toggle'),
            isSelected: isTextMode,
            type: IconButtonType.square,
            size: size,
            icon: const ImageIcon(AssetImage(NotesIcon.textModeIcon)),
            onPressed: enabled
                ? () => onModeSelected(NotesBottomBarMode.text)
                : null,
          ),
          SizedBox(width: spacing),
          MechanixIconButton.filled(
            key: const Key('notes_link_toggle'),
            isSelected: !isTextMode,
            type: IconButtonType.square,
            size: size,
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: enabled
                ? () => onModeSelected(NotesBottomBarMode.link)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ContextualButton extends StatelessWidget {
  const _ContextualButton({
    required this.buttonKey,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
    required this.size,
    required this.enabled,
  });

  final Key buttonKey;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isSelected;
  final IconButtonSize size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return MechanixIconButton.standard(
      key: buttonKey,
      isSelected: isSelected,
      type: IconButtonType.square,
      size: size,
      icon: icon,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurfaceVariant,
      selectedBackgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.08),
      selectedForegroundColor: scheme.onSurface,
      onPressed: enabled ? onPressed : null,
    );
  }
}
