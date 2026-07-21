import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: player quality/speed/subtitle menus use [PopupMenuButton], which
/// pushes a [PopupRoute] (a [ModalRoute], not a [PageRoute]).
///
/// If the app [RouteObserver] is typed as [ModalRoute], opening those menus
/// fires [RouteAware.didPushNext] on the watch page → inline surface release →
/// video interrupt. Fullscreen never subscribes, so it looked fine.
///
/// [appRouteObserver] must stay [RouteObserver]<[PageRoute]>.
void main() {
  testWidgets('PageRoute observer ignores PopupMenu (no didPushNext)',
      (tester) async {
    final observer = RouteObserver<PageRoute<dynamic>>();
    var pushNextCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: _AwarePage(
          observer: observer,
          onPushNext: () => pushNextCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(pushNextCount, 0);

    await tester.tap(find.text('menu'));
    await tester.pumpAndSettle();
    expect(find.text('item-a'), findsOneWidget);
    // Popup is open — must not look like a page cover.
    expect(pushNextCount, 0);

    await tester.tap(find.text('item-a'));
    await tester.pumpAndSettle();
    expect(pushNextCount, 0);
  });

  testWidgets('ModalRoute observer wrongly fires didPushNext for PopupMenu',
      (tester) async {
    // Documents the pre-fix bug shape (do not use this observer type in app).
    final observer = RouteObserver<ModalRoute<void>>();
    var pushNextCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: _AwarePage(
          observer: observer,
          onPushNext: () => pushNextCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('menu'));
    await tester.pumpAndSettle();
    expect(pushNextCount, 1);
  });

  testWidgets('PageRoute observer still fires didPushNext for page push',
      (tester) async {
    final observer = RouteObserver<PageRoute<dynamic>>();
    var pushNextCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: _AwarePage(
          observer: observer,
          onPushNext: () => pushNextCount++,
          alsoPagePush: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('push-page'));
    await tester.pumpAndSettle();
    expect(pushNextCount, 1);
  });
}

class _AwarePage extends StatefulWidget {
  const _AwarePage({
    required this.observer,
    required this.onPushNext,
    this.alsoPagePush = false,
  });

  final RouteObserver<ModalRoute<void>> observer;
  final VoidCallback onPushNext;
  final bool alsoPagePush;

  @override
  State<_AwarePage> createState() => _AwarePageState();
}

class _AwarePageState extends State<_AwarePage> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      widget.observer.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    widget.observer.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => widget.onPushNext();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PopupMenuButton<String>(
            child: const Text('menu'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'a', child: Text('item-a')),
            ],
            onSelected: (_) {},
          ),
          if (widget.alsoPagePush)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('next')),
                  ),
                );
              },
              child: const Text('push-page'),
            ),
        ],
      ),
    );
  }
}
