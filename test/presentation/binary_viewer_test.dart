// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mushagaeshi_ic_programmer/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/presentation/widgets/binary_viewer.dart';

void main() {
  double scrollOffset(WidgetTester tester, Key listKey) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byKey(listKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
      )
      .position
      .pixels;

  ViewerImage image(
    List<int> values, {
    String name = 'fixture.bin',
    String sha1 = 'fixture-hash',
  }) => ViewerImage(
    bytes: Uint8List.fromList(values),
    name: name,
    origin: ViewerImageOrigin.file,
    sha1: sha1,
  );

  Future<void> pumpViewer(
    WidgetTester tester, {
    ViewerImage? input,
    ViewerImage? readout,
    VoidCallback? onInputDropRequested,
    bool inputDropEnabled = true,
    GlobalKey? inputDropRegionKey,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: BinaryViewer(
            input: input,
            readout: readout,
            onInputDropRequested: onInputDropRequested,
            inputDropEnabled: inputDropEnabled,
            inputDropRegionKey: inputDropRegionKey,
          ),
        ),
      ),
    ),
  );

  testWidgets('renders HEX, printable ASCII, and missing bytes distinctly', (
    tester,
  ) async {
    await pumpViewer(tester, input: image([0x00, 0xff, 0x41]));

    expect(find.text('00'), findsOneWidget);
    expect(find.text('FF'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.textContaining('|..A'), findsOneWidget);
    expect(find.text('--'), findsWidgets);
    expect(find.textContaining('Read only'), findsOneWidget);
  });

  testWidgets('keeps separate input and readout panels in their empty states', (
    tester,
  ) async {
    final inputDropRegionKey = GlobalKey();
    var requests = 0;

    await pumpViewer(
      tester,
      inputDropRegionKey: inputDropRegionKey,
      onInputDropRequested: () => requests++,
    );

    expect(find.text('Drop a file here to open'), findsOneWidget);
    expect(find.text('Read IC from programmer'), findsOneWidget);
    expect(inputDropRegionKey.currentContext, isNotNull);

    await tester.tap(find.text('Drop a file here to open'));
    expect(requests, 1);
    expect(find.text('Read IC from programmer'), findsOneWidget);
  });

  testWidgets('keeps the input drop request disabled while host is busy', (
    tester,
  ) async {
    var requests = 0;
    await pumpViewer(
      tester,
      onInputDropRequested: () => requests++,
      inputDropEnabled: false,
    );

    await tester.tap(find.text('Drop a file here to open'));
    expect(requests, 0);
  });

  testWidgets('switches between 16 and 8 byte rows without enabling editing', (
    tester,
  ) async {
    await pumpViewer(tester, input: image(List<int>.generate(16, (i) => i)));

    await tester.tap(find.text('8 bytes'));
    await tester.pump();

    expect(find.text('8 bytes'), findsOneWidget);
    expect(find.text('16 bytes'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('uses azuki checksum backgrounds only for mismatched snapshots', (
    tester,
  ) async {
    await pumpViewer(
      tester,
      input: image([0x41], sha1: 'a' * 40),
      readout: image([0x42], name: 'readout.bin', sha1: 'b' * 40),
    );

    final inputHash = tester.widget<Container>(
      find.byKey(const ValueKey('Input BIN-checksum')),
    );
    final readoutHash = tester.widget<Container>(
      find.byKey(const ValueKey('IC Readout-checksum')),
    );
    expect(inputHash.color, azukiDifferenceBackground(Brightness.light));
    expect(readoutHash.color, azukiDifferenceBackground(Brightness.light));
    expect(find.textContaining('SHA-1: ${'a' * 40}'), findsOneWidget);
    expect(find.textContaining('SHA-256'), findsNothing);
  });

  testWidgets(
    'leaves checksum backgrounds clear for matching or missing snapshots',
    (tester) async {
      await pumpViewer(
        tester,
        input: image([], sha1: 'da39a3ee5e6b4b0d3255bfef95601890afd80709'),
        readout: image(
          [],
          name: 'empty-readout.bin',
          sha1: 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
        ),
      );

      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('Input BIN-checksum')))
            .color,
        isNull,
      );
      expect(
        tester
            .widget<Container>(
              find.byKey(const ValueKey('IC Readout-checksum')),
            )
            .color,
        isNull,
      );

      await pumpViewer(tester, input: image([0x41], sha1: 'a' * 40));
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('Input BIN-checksum')))
            .color,
        isNull,
      );
      expect(find.byKey(const ValueKey('IC Readout-checksum')), findsNothing);
    },
  );

  testWidgets(
    'marks a byte difference and exposes binary inspector on selection',
    (tester) async {
      await pumpViewer(
        tester,
        input: image([0x41]),
        readout: image([0x42], name: 'readout.bin'),
      );

      await tester.tap(find.text('41'));
      await tester.pump();

      expect(find.text('01000001'), findsOneWidget);
      expect(find.text('65'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.byTooltip('Next difference'), findsOneWidget);
    },
  );

  testWidgets('difference navigation reaches a byte present only in readout', (
    tester,
  ) async {
    await pumpViewer(
      tester,
      input: image([0x11]),
      readout: image([0x11, 0x42], name: 'long-readout.bin'),
    );

    await tester.tap(find.byTooltip('Next difference'));
    await tester.pump();

    expect(find.text('01000010'), findsOneWidget);
    expect(find.text('66'), findsOneWidget);
  });

  testWidgets(
    'accepts replacement with an empty snapshot without retaining selection',
    (tester) async {
      final first = image([0x41]);
      final replacement = image([], name: 'empty.bin');
      await pumpViewer(tester, input: first);
      await tester.tap(find.text('41'));
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: BinaryViewer(input: replacement),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Drop a file here to open'), findsOneWidget);
      expect(find.text('Read IC from programmer'), findsOneWidget);
      expect(find.text('01000001'), findsNothing);
    },
  );

  testWidgets(
    'synchronizes a newly populated panel to its scrolled companion',
    (tester) async {
      final input = image(List<int>.generate(512, (index) => index));
      await pumpViewer(tester, input: input);

      await tester.drag(
        find.byKey(const ValueKey('input-bin-byte-list')),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      final inputOffset = scrollOffset(
        tester,
        const ValueKey('input-bin-byte-list'),
      );
      expect(inputOffset, greaterThan(0));

      await pumpViewer(tester, input: input, readout: image(input.bytes));
      await tester.pump();

      final readoutOffset = scrollOffset(
        tester,
        const ValueKey('ic-readout-byte-list'),
      );
      expect(readoutOffset, closeTo(inputOffset, 0.1));
    },
  );

  testWidgets('each jump targets its own pane and open uses input callback', (
    tester,
  ) async {
    var opens = 0;
    await pumpViewer(
      tester,
      input: image([0x11]),
      readout: image([0x22]),
      onInputDropRequested: () => opens++,
    );
    await tester.tap(find.byKey(const ValueKey('input-open-file')));
    expect(opens, 1);
    for (final entry in {
      'readout-jump': '00100010',
      'input-jump': '00010001',
    }.entries) {
      await tester.tap(find.byKey(ValueKey(entry.key)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Jump').last);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }
    await pumpViewer(
      tester,
      inputDropEnabled: false,
      onInputDropRequested: () => opens++,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('input-open-file')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('input-jump')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('readout-jump')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('jump keeps both populated panels vertically synchronized', (
    tester,
  ) async {
    final bytes = List<int>.generate(512, (index) => index);
    await pumpViewer(tester, input: image(bytes), readout: image(bytes));

    await tester.tap(find.byKey(const ValueKey('input-jump')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Jump').last);
    await tester.pumpAndSettle();

    final inputOffset = scrollOffset(
      tester,
      const ValueKey('input-bin-byte-list'),
    );
    final readoutOffset = scrollOffset(
      tester,
      const ValueKey('ic-readout-byte-list'),
    );
    expect(inputOffset, greaterThan(0));
    expect(readoutOffset, closeTo(inputOffset, 0.1));
  });
}
