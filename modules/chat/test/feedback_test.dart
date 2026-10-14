import 'package:ensemble_chat/chat_page.dart';
import 'package:ensemble_chat/ensemble_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores stable message IDs and existing feedback', () {
    final controller = EnsembleChatController();
    final message = InternalMessage.fromMap({
      'id': 'assistant-message-123',
      'role': 'assistant',
      'content': 'A response',
      'feedback': {
        'rating': 'negative',
      },
    }, controller);

    expect(message.id, 'assistant-message-123');
    expect(message.feedbackRating, 'negative');
    expect(message.toMap()['feedback'], {
      'rating': 'negative',
    });
  });

  test('parses feedback configuration', () {
    final controller = EnsembleChatController();

    controller.setters()['feedback']!({
      'enabled': false,
    });

    expect(controller.feedbackEnabled, isFalse);
  });

  test('initial messages are not feedback eligible unless explicitly enabled',
      () {
    final controller = EnsembleChatController();

    controller.setters()['initialMessages']!([
      {
        'role': 'assistant',
        'content': 'Static greeting',
      },
      {
        'role': 'assistant',
        'content': 'Explicitly rateable',
        'feedbackEligible': true,
      },
    ]);

    expect(controller.messages.value[0].feedbackEligible, isFalse);
    expect(controller.messages.value[1].feedbackEligible, isTrue);
  });

  test('interactive assistant widgets remain feedback eligible', () {
    final message = InternalMessage(
      inlineWidget: const {'ReviewProposal': '{}'},
      role: MessageRole.assistant,
    );

    expect(message.feedbackEligible, isTrue);
  });

  testWidgets('submits and clears assistant feedback', (tester) async {
    final controller = EnsembleChatController();
    final message = InternalMessage(
      content: 'A response',
      role: MessageRole.assistant,
    );
    final submissions = <Map<String, String?>>[];

    await tester.pumpWidget(MaterialApp(
      home: ChatPage(
        messages: [message],
        onMessageSend: (_) {},
        onFeedback: (message, rating) async {
          submissions.add({
            'messageId': message.id,
            'rating': rating,
          });
        },
        controller: controller,
      ),
    ));

    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pump();

    expect(submissions.single, {
      'messageId': message.id,
      'rating': 'positive',
    });
    expect(find.byIcon(Icons.thumb_up), findsOneWidget);

    await tester.tap(find.byIcon(Icons.thumb_up));
    await tester.pump();

    expect(submissions.last['rating'], isNull);
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
  });

  testWidgets('does not show feedback on user or protocol messages',
      (tester) async {
    final controller = EnsembleChatController();

    await tester.pumpWidget(MaterialApp(
      home: ChatPage(
        messages: [
          InternalMessage(content: 'User', role: MessageRole.user),
          InternalMessage(
            content: 'Protocol',
            role: MessageRole.assistant,
            feedbackEligible: false,
          ),
        ],
        onMessageSend: (_) {},
        onFeedback: (_, __) async {},
        controller: controller,
      ),
    ));

    expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
    expect(find.byIcon(Icons.thumb_down_outlined), findsNothing);
  });

  testWidgets('shows only like and dislike feedback controls', (tester) async {
    final controller = EnsembleChatController();

    await tester.pumpWidget(MaterialApp(
      home: ChatPage(
        messages: [
          InternalMessage(content: 'Assistant', role: MessageRole.assistant),
        ],
        onMessageSend: (_) {},
        onFeedback: (_, __) async {},
        controller: controller,
      ),
    ));

    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
  });
}
