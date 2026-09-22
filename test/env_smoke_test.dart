// End-to-end environment smoke test.
//
// Renders the real interactive piano keyboard (`PianoView` -> `PianoOctave`
// -> `PianoKey`) under the Flutter engine, captures a golden screenshot of the
// rendered UI, and simulates a key press to verify the app drives the native
// `flutter_midi` channel with `play_midi_note`. The native MIDI/vibrate
// platform channels are mocked because they are only available on real
// iOS/Android devices.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_piano/ui/common/piano_view.dart';
import 'package:flutter_piano/ui/common/piano_key.dart';

void main() {
  const midiChannel = MethodChannel('flutter_midi');
  const vibrateChannel = MethodChannel('vibrate');
  final List<MethodCall> midiCalls = <MethodCall>[];

  setUp(() {
    midiCalls.clear();
    midiChannel.setMockMethodCallHandler((MethodCall call) async {
      midiCalls.add(call);
      return 'ok';
    });
    vibrateChannel.setMockMethodCallHandler((MethodCall call) async => true);
  });

  tearDown(() {
    midiChannel.setMockMethodCallHandler(null);
    vibrateChannel.setMockMethodCallHandler(null);
  });

  testWidgets('renders the piano keyboard and plays a note on tap',
      (WidgetTester tester) async {
    // The Pocket Piano is a landscape app.
    await tester.binding.setSurfaceSize(const Size(1000, 500));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          appBar: AppBar(title: const Text('The Pocket Piano')),
          body: PianoView(
            keyWidth: 70.0,
            showLabels: true,
            labelsOnlyOctaves: false,
            disableScroll: false,
            feedback: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The core UI renders a full keyboard made of many piano keys.
    expect(find.byType(PianoView), findsOneWidget);
    expect(find.byType(PianoKey), findsWidgets);
    expect(find.text('The Pocket Piano'), findsOneWidget);

    // Capture a screenshot of the real rendered piano UI.
    await expectLater(
      find.byType(PianoView),
      matchesGoldenFile('goldens/pocket_piano.png'),
    );

    // Tapping a key must drive the native MIDI channel end to end.
    // Tap low in the keyboard area where only white keys are hit-testable.
    await tester.tapAt(const Offset(500.0, 430.0));
    await tester.pumpAndSettle();

    expect(
      midiCalls.map((MethodCall c) => c.method),
      contains('play_midi_note'),
      reason: 'Tapping a piano key should invoke flutter_midi.play_midi_note',
    );
  });
}
