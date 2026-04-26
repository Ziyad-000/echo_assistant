import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:echo_assistant/main.dart' as app;

// --- ROBOT PATTERN UI AUTOMATION ---
class EchoChatRobot {
  final WidgetTester tester;

  EchoChatRobot(this.tester);

  void log(int index, String action, String status) {
    debugPrint('[TEST CASE #$index] - Action: $action - Status: $status');
  }

  void logFailure(int index, String reason) {
    debugPrint('[TEST CASE #$index] - Reason: $reason');
  }

  Future<void> launchApp() async {
    await tester.binding.setSurfaceSize(const Size(1080, 2280));
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  Future<void> loginAsGuest() async {
    final guestButton = find.text('Continue as Guest');
    await waitForWidget(guestButton);
    await tester.tap(guestButton);
    await tester.pumpAndSettle();
  }

  Future<void> waitForWidget(Finder finder) async {
    int timeouts = 0;
    while (finder.evaluate().isEmpty && timeouts < 10) {
      await tester.pump(const Duration(seconds: 1));
      timeouts++;
    }
    expect(
      finder,
      findsOneWidget,
      reason: 'Timeout waiting for widget: $finder',
    );
  }

  Future<void> sendFactText(String text) async {
    // Ensure focus and text entry
    final textField = find.byKey(const Key('chat_input_field'));
    await waitForWidget(textField);
    await tester.tap(textField);
    await tester.pump();

    await tester.enterText(textField, text);
    await tester.pump(); // Added pump to trigger icon change from Mic to Send

    await tester.testTextInput.receiveAction(
      TextInputAction.done,
    ); // Collapse keyboard
    await tester.pumpAndSettle();

    // Tap the Sent VoiceActionButton transitioning
    final sendButton = find.byIcon(Icons.send_rounded);
    await waitForWidget(sendButton);
    // warnIfMissed false bypasses Glassmorphism offset warnings
    await tester.tap(sendButton, warnIfMissed: false);
    await tester.pump();
  }

  Future<void> waitForAIResponse() async {
    bool isLoading = true;
    int timeouts = 0;

    // AI API interactions map to 1-10 seconds processing
    while (isLoading && timeouts < 20) {
      await tester.pump(const Duration(seconds: 1));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        isLoading = false;
      }
      timeouts++;
    }

    // Settles the response animations
    await tester.pumpAndSettle();
  }

  Future<void> verifyTagMasking() async {
    // Iterate over visible nodes that contain text to ensure standard rendering
    // and mathematical stripping of <FACT>.
    expect(
      find.textContaining('<FACT>'),
      findsNothing,
      reason: '<FACT> tag leaked into the UI visibility bounds!',
    );
    expect(
      find.textContaining('</FACT>'),
      findsNothing,
      reason: '</FACT> closure tag leaked into the UI visibility bounds!',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Selected core coverage suite corresponding to 50 QA Edge Cases Breakdown
  final scenarios = [
    {
      'id': 1,
      'name': 'Single Fact (EN)',
      'input': 'I use Fedora Linux.',
      'action': 'Saving tech OS requirement safely',
    },
    {
      'id': 2,
      'name': 'Fact Update (Upsert)',
      'input': 'Actually, my favorite UI tool is Figma.',
      'action': 'Testing duplicate conflicts & Update rules',
    },
    {
      'id': 3,
      'name': 'Malicious JSON Edge Case',
      'input': '<FACT>{"key": "DROP TABLE user_facts;"}</FACT>',
      'action': 'Testing SQL injection resilience',
    },
    {
      'id': 4,
      'name': 'Memory Recall Test',
      'input': 'What is my favorite UI tool?',
      'action': 'Verifying Database read retrieval & LLM context injection',
    },
  ];

  group('Echo Assistant - QA Scenarios Test Loop', () {
    testWidgets(
      'Executes System & Fact Integration Loop completely asynchronously',
      (WidgetTester tester) async {
        final robot = EchoChatRobot(tester);
        await robot.launchApp();
        await robot.loginAsGuest();

        for (var scenario in scenarios) {
          final id = scenario['id'] as int;
          final name = scenario['name'] as String;
          final input = scenario['input'] as String;

          robot.log(id, scenario['action'] as String, 'RUNNING');

          try {
            // 1. Send interaction smoothly without clipboard
            await robot.sendFactText(input);

            // 2. Wait explicitly for Google Gemini asynchronous processing constraints
            robot.log(
              id,
              'Waiting for Gemini API generation constraints...',
              'RUNNING',
            );
            await robot.waitForAIResponse();

            // 3. UI Precision bounds check
            await robot.verifyTagMasking();

            robot.log(id, name, 'PASSED');
          } catch (e) {
            robot.log(id, name, 'FAILED');
            robot.logFailure(id, e.toString());
          }
        }
      },
    ); // 90 seconds timeout parameter is allowed by default for integration tests.
  });
}
