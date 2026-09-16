// SPDX-License-Identifier: GPL-3.0-or-later
//
// The layout and virtual-row approach were informed by Mushagaeshi Binary
// Editor (f00daaeb0f51d708cbbd83588207071966509547), GPL-3.0-or-later.
// This is a read-only implementation written for the IC programmer.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Azuki red used consistently for byte and snapshot checksum differences.
Color azukiDifferenceBackground(Brightness brightness) =>
    brightness == Brightness.dark
    ? const Color(0xff743c48)
    : const Color(0xffffd9dd);

/// An immutable byte snapshot to display.  The viewer never mutates [bytes].
class ViewerImage {
  const ViewerImage({
    required this.bytes,
    required this.name,
    required this.origin,
    this.sha1 = 'Calculating…',
    this.capturedAt,
    this.stale = false,
  });

  final Uint8List bytes;
  final String name;
  final String origin;
  final String sha1;
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
  });

  final ViewerImage? input;
  final ViewerImage? readout;
  final int initialColumns;

  @override
  State<BinaryViewer> createState() => _BinaryViewerState();
}

class _BinaryViewerState extends State<BinaryViewer> {
  late final ScrollController _vertical;
  int _columns = 16;
  int? _selected;
  bool _leftActive = true;

  ViewerImage? get _active => _leftActive ? widget.input : widget.readout;
  int get _totalLength =>
      math.max(widget.input?.length ?? 0, widget.readout?.length ?? 0);
  int get _rowCount => (_totalLength / _columns).ceil();

  @override
  void initState() {
    super.initState();
    _columns = widget.initialColumns == 8 ? 8 : 16;
    _vertical = ScrollController();
  }

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
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
    if (_selected == null || !_vertical.hasClients) return;
    final row = _selected! ~/ _columns;
    const rowHeight = 27.0;
    final target = (row * rowHeight).toDouble();
    if (target < _vertical.offset ||
        target >
            _vertical.offset +
                _vertical.position.viewportDimension -
                rowHeight) {
      _vertical.animateTo(
        target.clamp(0, _vertical.position.maxScrollExtent),
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _jump() async {
    final controller = TextEditingController(
      text: _selected?.toRadixString(16) ?? '0',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Hexadecimal address',
            prefixText: '0x',
          ),
          onSubmitted: Navigator.of(context).pop,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Jump'),
          ),
        ],
      ),
    );
    final rawAddress = value?.trim().replaceFirst(
      RegExp(r'^0x', caseSensitive: false),
      '',
    );
    final address = rawAddress == null
        ? null
        : int.tryParse(rawAddress, radix: 16);
    final image = _active;
    if (!mounted) return;
    if (address != null &&
        image != null &&
        address >= 0 &&
        address < image.length) {
      _select(address, _leftActive);
      _scrollSelectionIntoView();
    } else if (value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That address is outside this snapshot.')),
      );
    }
    controller.dispose();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No differences found.')));
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
              Row(
                children: [
                  Expanded(child: _imageSummary(widget.input, 'Input BIN')),
                  const SizedBox(width: 8),
                  Expanded(child: _imageSummary(widget.readout, 'IC Readout')),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _totalLength == 0
                      ? const Center(
                          child: Text(
                            'Open a BIN file or read an IC to inspect immutable data.',
                          ),
                        )
                      : ListView.builder(
                          controller: _vertical,
                          itemCount: _rowCount,
                          itemExtent: 27,
                          itemBuilder: (context, row) => _HexRow(
                            address: row * _columns,
                            columns: _columns,
                            left: widget.input,
                            right: widget.readout,
                            selected: _selected,
                            onSelect: _select,
                          ),
                        ),
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

  Widget _toolbar(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 8, label: Text('8 bytes')),
          ButtonSegment(value: 16, label: Text('16 bytes')),
        ],
        selected: {_columns},
        onSelectionChanged: (value) => setState(() => _columns = value.first),
      ),
      Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Previous difference',
            onPressed: widget.input != null && widget.readout != null
                ? () => _difference(false)
                : null,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: 'Next difference',
            onPressed: widget.input != null && widget.readout != null
                ? () => _difference(true)
                : null,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          OutlinedButton.icon(
            onPressed: _jump,
            icon: const Icon(Icons.my_location),
            label: const Text('Jump'),
          ),
        ],
      ),
    ],
  );

  Widget _imageSummary(ViewerImage? image, String title) {
    final input = widget.input;
    final readout = widget.readout;
    final hashMismatch =
        input != null && readout != null && input.sha1 != readout.sha1;
    final background = hashMismatch
        ? azukiDifferenceBackground(Theme.of(context).brightness)
        : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: image == null
            ? Text('$title · no snapshot', style: const TextStyle(fontSize: 12))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title · Read only',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${image.name} · ${image.length} bytes',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${image.origin}${image.stale ? ' · previous successful readout' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  Container(
                    key: ValueKey('$title-checksum'),
                    color: background,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 2,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        'SHA-1: ${image.sha1}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _inspector(int? value) {
    final address = _selected;
    final ascii = value == null
        ? '—'
        : (value >= 0x20 && value <= 0x7e ? String.fromCharCode(value) : '.');
    return Semantics(
      label: value == null
          ? 'No byte selected'
          : 'Address ${address!.toRadixString(16)}, value ${value.toRadixString(16)}, decimal $value, binary ${value.toRadixString(2).padLeft(8, '0')}, ASCII $ascii',
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 22,
            runSpacing: 6,
            children: [
              _detail(
                'Address',
                address == null
                    ? '—'
                    : '0x${address.toRadixString(16).padLeft(8, '0').toUpperCase()}',
              ),
              _detail(
                'HEX',
                value == null
                    ? '—'
                    : value.toRadixString(16).padLeft(2, '0').toUpperCase(),
              ),
              _detail('Decimal', value?.toString() ?? '—'),
              _detail(
                'Binary',
                value == null ? '—' : value.toRadixString(2).padLeft(8, '0'),
              ),
              _detail('ASCII', ascii),
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

class _HexRow extends StatelessWidget {
  const _HexRow({
    required this.address,
    required this.columns,
    required this.left,
    required this.right,
    required this.selected,
    required this.onSelect,
  });
  final int address, columns;
  final ViewerImage? left, right;
  final int? selected;
  final void Function(int, bool) onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _pane(context, left, true)),
      const VerticalDivider(width: 1),
      Expanded(child: _pane(context, right, false)),
    ],
  );

  Widget _pane(BuildContext context, ViewerImage? image, bool isLeft) {
    if (image == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('No snapshot'),
      );
    }
    return SingleChildScrollView(
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
  }

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
