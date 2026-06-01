import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music_picker_example/main.dart';

/// Smoke test to verify that the example app widget tree builds
/// without errors.
void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    // Build the example app and trigger the first frame.
    await tester.pumpWidget(const MusicPickerExampleApp());

    // Verify that the app's title bar is present.
    expect(find.text('Music Picker'), findsOneWidget);
  });
}
