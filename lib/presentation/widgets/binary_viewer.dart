// SPDX-License-Identifier: GPL-3.0-or-later
//
// The layout and virtual-row approach were informed by Mushagaeshi Binary
// Editor (f00daaeb0f51d708cbbd83588207071966509547), GPL-3.0-or-later.
// This is a read-only implementation written for the IC programmer.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Azuki red used consistently for byte and snapshot checksum differences.
Color azukiDifferenceBackground(Brightness brightness) =>
    brightness == Brightness.dark
    ? const Color(0xff743c48)
    : const Color(0xffffd9dd);

/// An immutable byte snapshot to display.  The viewer never mutates [bytes].
enum ViewerImageOrigin { file, readout, postWriteVerification }

class ViewerImage {
  const ViewerImage({
    required this.bytes,
    required this.name,
    required this.origin,
    this.sha1,
    this.capturedAt,
    this.stale = false,
  });

  final Uint8List bytes;
  final String name;
  final ViewerImageOrigin origin;
  final String? sha1;
  final DateTime? capturedAt;
  final bool stale;

  int get length => bytes.length;
}

class BinaryViewer extends StatefulWidget {
  const BinaryViewer({
    super.key,
    this.input,
    this.readout,
    this.initialColumns = 16,
    this.onInputDropRequested,
    this.inputDropEnabled = true,
    this.inputDropRegionKey,
  });

  final ViewerImage? input;
  final ViewerImage? readout;
  final int initialColumns;

  /// Lets the host open a file picker from the empty input region. Native
  /// drops are received by the host, which validates [inputDropRegionKey].
  final VoidCallback? onInputDropRequested;
  final bool inputDropEnabled;

  /// The exact left byte-display (or empty-state) region that accepts drops.
  /// The Input BIN summary header is deliberately outside this key.
  final GlobalKey? inputDropRegionKey;

  @override
  State<BinaryViewer> createState() => _BinaryViewerState();
}

class _BinaryViewerState extends State<BinaryViewer> {
  late final ScrollController _inputVertical;
  late final ScrollController _readoutVertical;
  int _columns = 16;
  int? _selected;
  bool _leftActive = true;
  bool _synchronizingScroll = false;

  ViewerImage? get _active => _leftActive ? widget.input : widget.readout;
  int get _totalLength =>
      math.max(widget.input?.length ?? 0, widget.readout?.length ?? 0);
  int get _rowCount => (_totalLength / _columns).ceil();

  @override
  void initState() {
    super.initState();
    _columns = widget.initialColumns == 8 ? 8 : 16;
    _inputVertical = ScrollController();
    _readoutVertical = ScrollController();
    _inputVertical.addListener(
      () => _syncScroll(_inputVertical, _readoutVertical),
    );
    _readoutVertical.addListener(
      () => _syncScroll(_readoutVertical, _inputVertical),
    );
  }

  @override
  void dispose() {
    _inputVertical.dispose();
    _readoutVertical.dispose();
    super.dispose();
  }

  void _syncScroll(ScrollController source, ScrollController target) {
    if (_synchronizingScroll || !source.hasClients || !target.hasClients) {
      return;
    }
    _synchronizingScroll = true;
    target.jumpTo(source.offset.clamp(0, target.position.maxScrollExtent));
    _synchronizingScroll = false;
  }

  @override
  void didUpdateWidget(covariant BinaryViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input == widget.input &&
        oldWidget.readout == widget.readout) {
      return;
    }
    final active = _active;
    if (active == null || _selected == null || _selected! >= active.length) {
      _selected = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final source = oldWidget.input == null && widget.input != null
          ? _readoutVertical
          : oldWidget.readout == null && widget.readout != null
          ? _inputVertical
          : (_leftActive ? _inputVertical : _readoutVertical);
      final target = identical(source, _inputVertical)
          ? _readoutVertical
          : _inputVertical;
      _syncScroll(source, target);
    });
  }

  void _select(int address, bool left) {
    final image = left ? widget.input : widget.readout;
    if (image == null || address < 0 || address >= image.length) return;
    setState(() {
      _leftActive = left;
      _selected = address;
    });
  }

  void _move(int delta) {
    final image = _active;
    if (image == null || image.length == 0) return;
    _select(((_selected ?? 0) + delta).clamp(0, image.length - 1), _leftActive);
    _scrollSelectionIntoView();
  }

  void _scrollSelectionIntoView() {
    final vertical = _leftActive ? _inputVertical : _readoutVertical;
    if (_selected == null || !vertical.hasClients) return;
    final row = _selected! ~/ _columns;
    const rowHeight = 27.0;
    final target = (row * rowHeight).toDouble();
    if (target < vertical.offset ||
        target >
            vertical.offset + vertical.position.viewportDimension - rowHeight) {
      vertical.animateTo(
        target.clamp(0, vertical.position.maxScrollExtent),
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _jump({bool? isLeft}) async {
    final targetLeft = isLeft ?? _leftActive;
    final controller = TextEditingController(
      text: _selected?.toRadixString(16) ?? '0',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(l10n.viewerJumpToAddress),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.viewerHexadecimalAddress,
              prefixText: '0x',
            ),
            onSubmitted: Navigator.of(context).pop,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.viewerJump),
            ),
          ],
        );
      },
    );
    final rawAddress = value?.trim().replaceFirst(
      RegExp(r'^0x', caseSensitive: false),
      '',
    );
    final address = rawAddress == null
        ? null
        : int.tryParse(rawAddress, radix: 16);
    final image = targetLeft ? widget.input : widget.readout;
    if (!mounted) return;
    if (address != null &&
        image != null &&
        address >= 0 &&
        address < image.length) {
      _select(address, targetLeft);
      _scrollSelectionIntoView();
    } else if (value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.viewerAddressOutsideSnapshot,
          ),
        ),
      );
    }
    // The dialog future resolves before its exit animation removes the field.
    // Dispose after that animation so its editable text state never observes a
    // disposed controller.
    Future<void>.delayed(kThemeAnimationDuration, controller.dispose);
  }

  Future<void> _difference(bool next) async {
    if (widget.input == null || widget.readout == null) return;
    final start = _selected ?? (next ? -1 : _totalLength);
    for (var step = 1; step <= _totalLength; step++) {
      final address = (start + (next ? step : -step)) % _totalLength;
      final normalized = address < 0 ? address + _totalLength : address;
      if (_differentAt(normalized)) {
        final selectLeft = normalized < widget.input!.length;
        _select(normalized, selectLeft);
        _scrollSelectionIntoView();
        return;
      }
      // A long, unequal image can have millions of matching bytes. Yield at a
      // bounded interval so navigation does not monopolise the UI isolate.
      if (step % 4096 == 0) await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.viewerNoDifferencesFound),
        ),
      );
    }
  }

  bool _differentAt(int address) {
    final left = widget.input;
    final right = widget.readout;
    if (left == null || right == null) return false;
    if (address >= left.length || address >= right.length) return true;
    return left.bytes[address] != right.bytes[address];
  }

  @override
  Widget build(BuildContext context) {
    final image = _active;
    final selection =
        _selected != null && image != null && _selected! < image.length
        ? image.bytes[_selected!]
        : null;
    return Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.arrowLeft): const _ViewerIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): const _ViewerIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _ViewerIntent(-_columns),
        SingleActivator(LogicalKeyboardKey.arrowDown): _ViewerIntent(_columns),
        SingleActivator(LogicalKeyboardKey.pageUp): _ViewerIntent(
          -_columns * 12,
        ),
        SingleActivator(LogicalKeyboardKey.pageDown): _ViewerIntent(
          _columns * 12,
        ),
        SingleActivator(LogicalKeyboardKey.home): const _ViewerHomeIntent(
          false,
        ),
        SingleActivator(LogicalKeyboardKey.end): const _ViewerHomeIntent(true),
        SingleActivator(LogicalKeyboardKey.keyG, meta: true):
            const _ViewerJumpIntent(),
      },
      child: Actions(
        actions: {
          _ViewerIntent: CallbackAction<_ViewerIntent>(
            onInvoke: (intent) {
              _move(intent.delta);
              return null;
            },
          ),
          _ViewerHomeIntent: CallbackAction<_ViewerHomeIntent>(
            onInvoke: (intent) {
              final length = _active?.length ?? 0;
              if (length > 0) _select(intent.end ? length - 1 : 0, _leftActive);
              _scrollSelectionIntoView();
              return null;
            },
          ),
          _ViewerJumpIntent: CallbackAction<_ViewerJumpIntent>(
            onInvoke: (_) {
              _jump();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(context),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _snapshotPanel(
                        context,
                        image: widget.input,
                        title: AppLocalizations.of(context)!.viewerInputBin,
                        isLeft: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _snapshotPanel(
                        context,
                        image: widget.readout,
                        title: AppLocalizations.of(context)!.viewerIcReadout,
                        isLeft: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _inspector(selection),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget jump(bool left) => Tooltip(
      message: left ? l10n.viewerInputBin : l10n.viewerIcReadout,
      child: OutlinedButton.icon(
        key: ValueKey(left ? 'input-jump' : 'readout-jump'),
        onPressed: ((left ? widget.input : widget.readout)?.length ?? 0) > 0
            ? () => _jump(isLeft: left)
            : null,
        icon: const Icon(Icons.my_location),
        label: Text(l10n.viewerJump),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('input-open-file'),
                        onPressed: widget.inputDropEnabled
                            ? widget.onInputDropRequested
                            : null,
                        icon: const Icon(Icons.folder_open),
                        label: Text(l10n.openBinButton),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 8,
                            label: Text(l10n.viewerBytesPerRow(8)),
                          ),
                          ButtonSegment(
                            value: 16,
                            label: Text(l10n.viewerBytesPerRow(16)),
                          ),
                        ],
                        selected: {_columns},
                        onSelectionChanged: (value) =>
                            setState(() => _columns = value.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              jump(true),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: l10n.viewerPreviousDifference,
                onPressed: widget.input != null && widget.readout != null
                    ? () => _difference(false)
                    : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: l10n.viewerNextDifference,
                onPressed: widget.input != null && widget.readout != null
                    ? () => _difference(true)
                    : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              jump(false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _snapshotPanel(
    BuildContext context, {
    required ViewerImage? image,
    required String title,
    required bool isLeft,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _imageSummary(image, title, isLeft),
        ),
        const Divider(height: 1),
        Expanded(
          child: KeyedSubtree(
            key: isLeft ? widget.inputDropRegionKey : null,
            child: _byteDisplay(image, isLeft),
          ),
        ),
      ],
    ),
  );

  Widget _byteDisplay(ViewerImage? image, bool isLeft) {
    final l10n = AppLocalizations.of(context)!;
    if (image == null || image.length == 0) {
      final message = isLeft
          ? l10n.viewerDropFileToOpen
          : l10n.viewerReadIcFromProgrammer;
      final canRequestInput =
          isLeft &&
          widget.inputDropEnabled &&
          widget.onInputDropRequested != null;
      return Semantics(
        button: canRequestInput,
        label: isLeft
            ? l10n.viewerInputDropRegion
            : l10n.viewerReadoutEmptyRegion,
        child: InkWell(
          onTap: canRequestInput ? widget.onInputDropRequested : null,
          child: Center(child: Text(message)),
        ),
      );
    }
    return ListView.builder(
      key: ValueKey(isLeft ? 'input-bin-byte-list' : 'ic-readout-byte-list'),
      controller: isLeft ? _inputVertical : _readoutVertical,
      itemCount: _rowCount,
      itemExtent: 27,
      itemBuilder: (context, row) => _HexPaneRow(
        address: row * _columns,
        columns: _columns,
        image: image,
        left: widget.input,
        right: widget.readout,
        isLeft: isLeft,
        selected: _selected,
        onSelect: _select,
      ),
    );
  }

  Widget _imageSummary(ViewerImage? image, String title, bool isLeft) {
    final l10n = AppLocalizations.of(context)!;
    final input = widget.input;
    final readout = widget.readout;
    final hashMismatch =
        input != null &&
        readout != null &&
        input.sha1 != null &&
        readout.sha1 != null &&
        input.sha1 != readout.sha1;
    final background = hashMismatch
        ? azukiDifferenceBackground(Theme.of(context).brightness)
        : null;
    return image == null
        ? Text(
            l10n.viewerNoSnapshot(title),
            style: const TextStyle(fontSize: 12),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.viewerReadOnly(title),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                l10n.viewerImageSize(image.name, image.length),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                image.stale
                    ? l10n.viewerPreviousSuccessfulReadout(
                        _originLabel(l10n, image.origin),
                      )
                    : _originLabel(l10n, image.origin),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              Container(
                key: ValueKey(
                  isLeft ? 'Input BIN-checksum' : 'IC Readout-checksum',
                ),
                color: background,
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    'SHA-1: ${image.sha1 ?? l10n.viewerChecksumCalculating}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  String _originLabel(AppLocalizations l10n, ViewerImageOrigin origin) =>
      switch (origin) {
        ViewerImageOrigin.file => l10n.viewerOriginInputBin,
        ViewerImageOrigin.readout => l10n.viewerOriginIcReadoutSnapshot,
        ViewerImageOrigin.postWriteVerification =>
          l10n.viewerOriginPostWriteVerificationSnapshot,
      };

  Widget _inspector(int? value) {
    final l10n = AppLocalizations.of(context)!;
    final address = _selected;
    final ascii = value == null
        ? '—'
        : (value >= 0x20 && value <= 0x7e ? String.fromCharCode(value) : '.');
    return Semantics(
      label: value == null
          ? l10n.viewerNoByteSelected
          : l10n.viewerByteSelection(
              address!.toRadixString(16),
              value.toRadixString(16),
              value,
              value.toRadixString(2).padLeft(8, '0'),
              ascii,
            ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 22,
            runSpacing: 6,
            children: [
              _detail(
                l10n.viewerAddress,
                address == null
                    ? '—'
                    : '0x${address.toRadixString(16).padLeft(8, '0').toUpperCase()}',
              ),
              _detail(
                l10n.viewerHex,
                value == null
                    ? '—'
                    : value.toRadixString(16).padLeft(2, '0').toUpperCase(),
              ),
              _detail(l10n.viewerDecimal, value?.toString() ?? '—'),
              _detail(
                l10n.viewerBinary,
                value == null ? '—' : value.toRadixString(2).padLeft(8, '0'),
              ),
              _detail(l10n.viewerAscii, ascii),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 11)),
      Text(
        value,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _HexPaneRow extends StatelessWidget {
  const _HexPaneRow({
    required this.address,
    required this.columns,
    required this.image,
    required this.left,
    required this.right,
    required this.isLeft,
    required this.selected,
    required this.onSelect,
  });
  final int address, columns;
  final ViewerImage image;
  final ViewerImage? left, right;
  final bool isLeft;
  final int? selected;
  final void Function(int, bool) onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              address.toRadixString(16).padLeft(8, '0').toUpperCase(),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.blueGrey,
              ),
            ),
          ),
          for (var i = 0; i < columns; i++)
            _cell(context, image, address + i, isLeft),
          const SizedBox(width: 8),
          Text(
            '|${List.generate(columns, (i) => _ascii(image, address + i)).join()}|',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    ),
  );

  String _ascii(ViewerImage image, int position) => position >= image.length
      ? ' '
      : (image.bytes[position] >= 0x20 && image.bytes[position] <= 0x7e
            ? String.fromCharCode(image.bytes[position])
            : '.');

  Widget _cell(
    BuildContext context,
    ViewerImage image,
    int position,
    bool isLeft,
  ) {
    final exists = position < image.length;
    final changed =
        left != null &&
        right != null &&
        ((position >= (left?.length ?? 0)) ||
            (position >= (right?.length ?? 0)) ||
            left!.bytes[position] != right!.bytes[position]);
    final selectedHere = selected == position;
    return InkWell(
      onTap: exists ? () => onSelect(position, isLeft) : null,
      child: Container(
        width: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selectedHere
              ? Theme.of(context).colorScheme.primaryContainer
              : changed
              ? azukiDifferenceBackground(Theme.of(context).brightness)
              : null,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          exists
              ? image.bytes[position]
                    .toRadixString(16)
                    .padLeft(2, '0')
                    .toUpperCase()
              : '--',
          style: TextStyle(
            fontFamily: 'monospace',
            color: exists ? null : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _ViewerIntent extends Intent {
  const _ViewerIntent(this.delta);
  final int delta;
}

class _ViewerHomeIntent extends Intent {
  const _ViewerHomeIntent(this.end);
  final bool end;
}

class _ViewerJumpIntent extends Intent {
  const _ViewerJumpIntent();
}
