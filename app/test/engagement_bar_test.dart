import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/bridge/frb/error.dart';
import 'package:nextpili/features/video/engagement_bar.dart';

void main() {
  group('isAlreadyLikedError / isNotLikedError', () {
    test('maps bili 65006 and 重复 message as already liked', () {
      expect(
        isAlreadyLikedError(
          const AppError(
            kind: ErrorKind.internal,
            message: 'x',
            biliCode: 65006,
          ),
        ),
        isTrue,
      );
      expect(
        isAlreadyLikedError(
          const AppError(kind: ErrorKind.internal, message: '重复操作'),
        ),
        isTrue,
      );
      expect(
        isAlreadyLikedError(
          const AppError(kind: ErrorKind.network, message: 'offline'),
        ),
        isFalse,
      );
    });

    test('maps bili 65004 and 未点赞 message as not liked', () {
      expect(
        isNotLikedError(
          const AppError(
            kind: ErrorKind.internal,
            message: 'x',
            biliCode: 65004,
          ),
        ),
        isTrue,
      );
      expect(
        isNotLikedError(
          const AppError(kind: ErrorKind.internal, message: '未点赞'),
        ),
        isTrue,
      );
    });
  });

  group('popRootDialog', () {
    testWidgets(
      'Given nested + root navigators, When cancel pops root, Then page stays',
      (tester) async {
        var pageStillThere = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (nestedCtx) => Scaffold(
                  body: Builder(
                    builder: (pageCtx) {
                      return Column(
                        children: [
                          const Text('video-page'),
                          TextButton(
                            onPressed: () async {
                              await showCupertinoDialog<void>(
                                context: pageCtx,
                                useRootNavigator: true,
                                builder: (_) => CupertinoAlertDialog(
                                  title: const Text('coin-dialog'),
                                  actions: [
                                    CupertinoDialogAction(
                                      onPressed: () =>
                                          popRootDialog(pageCtx),
                                      child: const Text('cancel'),
                                    ),
                                  ],
                                ),
                              );
                              pageStillThere = find
                                  .text('video-page')
                                  .evaluate()
                                  .isNotEmpty;
                            },
                            child: const Text('open-dialog'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open-dialog'));
        await tester.pumpAndSettle();
        expect(find.text('coin-dialog'), findsOneWidget);

        await tester.tap(find.text('cancel'));
        await tester.pumpAndSettle();

        expect(find.text('coin-dialog'), findsNothing);
        expect(find.text('video-page'), findsOneWidget);
        expect(pageStillThere, isTrue);
      },
    );

    testWidgets(
      'Given nested navigator, When pop without rootNavigator, Then page can exit',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (nestedCtx) => Scaffold(
                  body: Builder(
                    builder: (pageCtx) {
                      return Column(
                        children: [
                          const Text('video-page'),
                          TextButton(
                            onPressed: () async {
                              await showCupertinoDialog<void>(
                                context: pageCtx,
                                useRootNavigator: true,
                                builder: (_) => CupertinoAlertDialog(
                                  title: const Text('coin-dialog'),
                                  actions: [
                                    CupertinoDialogAction(
                                      onPressed: () =>
                                          Navigator.of(pageCtx).pop(),
                                      child: const Text('bad-cancel'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('open-dialog'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open-dialog'));
        await tester.pumpAndSettle();
        expect(find.text('coin-dialog'), findsOneWidget);

        await tester.tap(find.text('bad-cancel'));
        await tester.pumpAndSettle();

        // Nested pop removes the page; dialog may still be on root.
        expect(find.text('video-page'), findsNothing);
      },
    );
  });
}
