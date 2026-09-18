// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a keyboard-first, anchored selector for a catalog-sized list.
///
/// [options] stays indexed and [ListView.builder] only builds visible rows.
Future<T?> showTypeaheadSelector<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T option) labelOf,
  T? initialValue,
  String Function(T option)? secondaryLabelOf,
  RenderBox? anchor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (dialogContext, _, _) => _TypeaheadSelector<T>(
      title: title,
      options: options,
      labelOf: labelOf,
      initialValue: initialValue,
      secondaryLabelOf: secondaryLabelOf,
      anchor: anchor,
    ),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _TypeaheadSelector<T> extends StatefulWidget {
  const _TypeaheadSelector({
    required this.title,
    required this.options,
    required this.labelOf,
    required this.initialValue,
    required this.secondaryLabelOf,
    required this.anchor,
  });

  final String title;
  final List<T> options;
  final String Function(T option) labelOf;
  final T? initialValue;
  final String Function(T option)? secondaryLabelOf;
  final RenderBox? anchor;

  @override
  State<_TypeaheadSelector<T>> createState() => _TypeaheadSelectorState<T>();
}

class _TypeaheadSelectorState<T> extends State<_TypeaheadSelector<T>> {
  static const _rowExtent = 72.0;
  static const _prefixTimeout = Duration(milliseconds: 800);
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _prefixTimer;
  String _prefix = '';
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    final selected = widget.initialValue == null
        ? -1
        : widget.options.indexOf(widget.initialValue as T);
    _highlight = selected < 0 ? 0 : selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _scrollToHighlight(jump: true);
      }
    });
  }

  @override
  void dispose() {
    _prefixTimer?.cancel();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (widget.options.isNotEmpty) {
        Navigator.of(context).pop(widget.options[_highlight]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) return _move(1);
    if (key == LogicalKeyboardKey.arrowUp) return _move(-1);
    if (key == LogicalKeyboardKey.home) return _setHighlight(0);
    if (key == LogicalKeyboardKey.end) {
      return _setHighlight(widget.options.length - 1);
    }

    final character = event.character;
    if (character == null ||
        character.runes.length != 1 ||
        character.trim().isEmpty) {
      return KeyEventResult.ignored;
    }
    _typeahead(character.toLowerCase());
    return KeyEventResult.handled;
  }

  KeyEventResult _move(int amount) {
    if (widget.options.isEmpty) return KeyEventResult.handled;
    _clearPrefix();
    return _setHighlight((_highlight + amount) % widget.options.length);
  }

  KeyEventResult _setHighlight(int index) {
    if (widget.options.isEmpty) return KeyEventResult.handled;
    _clearPrefix();
    setState(() => _highlight = index.clamp(0, widget.options.length - 1));
    _scrollToHighlight();
    return KeyEventResult.handled;
  }

  void _typeahead(String character) {
    if (widget.options.isEmpty) return;
    final repeatedCharacter = _prefix.length == 1 && _prefix == character;
    final candidate = repeatedCharacter ? character : '$_prefix$character';
    final start = repeatedCharacter
        ? (_highlight + 1) % widget.options.length
        : 0;
    final match = _findMatch(candidate, start);
    if (match == -1) return;
    setState(() {
      _prefix = candidate;
      _highlight = match;
    });
    _prefixTimer?.cancel();
    _prefixTimer = Timer(_prefixTimeout, () {
      if (mounted) _prefix = '';
    });
    _scrollToHighlight();
  }

  void _clearPrefix() {
    _prefixTimer?.cancel();
    _prefix = '';
  }

  int _findMatch(String prefix, int start) {
    if (widget.options.isEmpty) return -1;
    for (var offset = 0; offset < widget.options.length; offset++) {
      final index = (start + offset) % widget.options.length;
      if (widget
          .labelOf(widget.options[index])
          .toLowerCase()
          .startsWith(prefix)) {
        return index;
      }
    }
    return -1;
  }

  void _scrollToHighlight({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final target = (_highlight * _rowExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    if (jump) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final anchor = widget.anchor;
    final origin =
        anchor?.localToGlobal(Offset.zero) ??
        Offset(media.size.width * .5 - 160, media.size.height * .25);
    final anchorSize = anchor?.size ?? const Size(320, 48);
    const maxHeight = 300.0;
    final below = media.size.height - (origin.dy + anchorSize.height);
    final height = maxHeight.clamp(0.0, media.size.height - 16).toDouble();
    final top = below >= height || origin.dy < height
        ? (origin.dy + anchorSize.height)
              .clamp(8.0, media.size.height - height - 8)
              .toDouble()
        : (origin.dy - height)
              .clamp(8.0, media.size.height - height - 8)
              .toDouble();
    final width = anchorSize.width.clamp(220.0, 420.0).toDouble();
    final left = origin.dx.clamp(8.0, media.size.width - width - 8).toDouble();
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: left,
            width: width,
            height: height,
            child: Focus(
              autofocus: true,
              focusNode: _focusNode,
              onKeyEvent: _onKey,
              child: Material(
                key: const ValueKey('typeahead-popup'),
                elevation: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemExtent: _rowExtent,
                        itemCount: widget.options.length,
                        itemBuilder: (context, index) {
                          final option = widget.options[index];
                          final selected = index == _highlight;
                          final secondary = widget.secondaryLabelOf?.call(
                            option,
                          );
                          return Semantics(
                            selected: selected,
                            child: ListTile(
                              key: ValueKey('typeahead-option-$index'),
                              selected: selected,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              selectedColor: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                              dense: secondary == null,
                              title: Text(
                                widget.labelOf(option),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: secondary == null
                                  ? null
                                  : Text(
                                      secondary,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => Navigator.of(context).pop(option),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
