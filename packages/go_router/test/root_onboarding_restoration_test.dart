// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> mount(WidgetTester tester, _Fixture fixture) async {
    addTearDown(fixture.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: fixture.router));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'welcome returns after cancelling and restoring the chat branch',
    (WidgetTester tester) async {
      final _Fixture fixture = _Fixture();
      await mount(tester, fixture);
      for (int entry = 0; entry < 3; entry++) {
        await tap(tester, 'Chats');
        expect(find.text('welcome'), findsOneWidget);
        expect(
          fixture.router.routerDelegate.currentConfiguration.uri.path,
          '/chat/chat_onboarding',
        );
        await tap(tester, 'Cancel');
        expect(find.text('home'), findsOneWidget);
        expect(fixture.finished, isFalse);
      }
      expect(fixture.shellCreations, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system Back preserves welcome on the next chat entry', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture();
    await mount(tester, fixture);
    await tap(tester, 'Chats');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await tap(tester, 'Chats');
    expect(find.text('welcome'), findsOneWidget);
  });

  testWidgets(
    'welcome covers the bottom navigation bar on the root navigator',
    (WidgetTester tester) async {
      final _Fixture fixture = _Fixture();
      await mount(tester, fixture);
      final Rect barRect =
          tester.getRect(find.byKey(const ValueKey<String>('bottom-bar')));
      await tap(tester, 'Chats');
      final Rect welcomeRect = tester.getRect(
        find.byKey(const ValueKey<String>('welcome-page')),
      );
      expect(welcomeRect.contains(barRect.center), isTrue);
      expect(find.text('Chats'), findsNothing);
      expect(find.text('welcome'), findsOneWidget);
    },
  );

  testWidgets('direct chat entry also redirects to welcome',
      (WidgetTester tester) async {
    final _Fixture fixture = _Fixture(initialLocation: '/chat');
    await mount(tester, fixture);
    expect(find.text('welcome'), findsOneWidget);
    expect(fixture.shellCreations, 1);
  });

  testWidgets(
    'confirmed welcome reaches tour and finished onboarding is skipped',
    (WidgetTester tester) async {
      final _Fixture fixture = _Fixture();
      await mount(tester, fixture);
      await tap(tester, 'Chats');
      await tap(tester, 'Got it');
      expect(find.text('tour'), findsOneWidget);
      expect(fixture.finished, isFalse);
      await tap(tester, 'Finish tour');
      expect(fixture.finished, isTrue);
      await tap(tester, 'Home');
      await tap(tester, 'Chats');
      expect(find.text('chat'), findsOneWidget);
      expect(find.text('welcome'), findsNothing);
      expect(find.text('tour'), findsNothing);
      expect(fixture.shellCreations, 1);
    },
  );

  testWidgets('imperative thread stack survives a branch round trip', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture()..finished = true;
    await mount(tester, fixture);
    await tap(tester, 'Chats');
    unawaited(fixture.router.pushNamed<void>(
      'thread',
      pathParameters: <String, String>{'id': '42'},
      extra: 'payload',
    ));
    await tester.pumpAndSettle();
    expect(find.text('thread 42 payload'), findsOneWidget);
    await tap(tester, 'Home');
    await tap(tester, 'Chats');
    expect(find.text('thread 42 payload'), findsOneWidget);
    fixture.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('declarative thread stack survives a branch round trip', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture()..finished = true;
    await mount(tester, fixture);
    fixture.router
        .goNamed('thread', pathParameters: <String, String>{'id': '42'});
    await tester.pumpAndSettle();
    await tap(tester, 'Home');
    await tap(tester, 'Chats');
    expect(find.text('thread 42 null'), findsOneWidget);
    fixture.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
  });

  testWidgets('root popup URI does not remain in the cached branch', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture()..finished = true;
    await mount(tester, fixture);
    fixture.router
        .goNamed('popup', pathParameters: <String, String>{'popupId': '99'});
    await tester.pumpAndSettle();
    expect(find.text('popup'), findsOneWidget);
    await tap(tester, 'Close popup');
    await tap(tester, 'Chats');
    expect(find.text('chat'), findsOneWidget);
    expect(
      fixture.router.routerDelegate.currentConfiguration.uri.path,
      '/chat',
    );
  });

  testWidgets(
    'cached URI keeps branch parameters and removes popup parameters',
    (WidgetTester tester) async {
      final _Fixture fixture = _Fixture(accountId: '17')..finished = true;
      await mount(tester, fixture);
      fixture.router.goNamed(
        'popup',
        pathParameters: <String, String>{'accountId': '17', 'popupId': '99'},
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Close popup');
      await tap(tester, 'Chats');
      expect(find.text('chat'), findsOneWidget);
      expect(
        fixture.router.routerDelegate.currentConfiguration.uri.path,
        '/chat/17',
      );
      expect(
        fixture.router.routerDelegate.currentConfiguration.pathParameters,
        <String, String>{'accountId': '17'},
      );
    },
  );

  testWidgets('fork popUntil still pops a thread to its branch root', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture()..finished = true;
    await mount(tester, fixture);
    await tap(tester, 'Chats');
    unawaited(fixture.router.pushNamed<void>('thread',
        pathParameters: <String, String>{'id': '42'}));
    await tester.pumpAndSettle();
    fixture.router.popUntil(
        (GoRouterState state, Route<dynamic> route) => state.name == 'chat');
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
    expect(find.text('thread 42 null'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  _Fixture({this.initialLocation = '/home', this.accountId});

  final String initialLocation;
  final String? accountId;
  final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();
  bool finished = false;
  int shellCreations = 0;

  String get chatLocation => accountId == null ? '/chat' : '/chat/$accountId';

  Map<String, String> get chatParameters => accountId == null
      ? <String, String>{}
      : <String, String>{'accountId': accountId!};

  late final GoRouter router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
                StatefulNavigationShell shell) =>
            _ShellProbe(
          onCreated: () => shellCreations++,
          child: Scaffold(
            body: shell,
            bottomNavigationBar: Row(
              key: const ValueKey<String>('bottom-bar'),
              children: <Widget>[
                TextButton(
                  onPressed: () => shell.goBranch(0),
                  child: const Text('Home'),
                ),
                TextButton(
                  onPressed: () => shell.goBranch(1),
                  child: const Text('Chats'),
                ),
              ],
            ),
          ),
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('home'),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: chatLocation,
            routes: <RouteBase>[
              GoRoute(
                path: accountId == null ? '/chat' : '/chat/:accountId',
                name: 'chat',
                redirect: (_, GoRouterState state) {
                  if (state.uri.path ==
                          state.namedLocation(
                            'welcome',
                            pathParameters: chatParameters,
                          ) ||
                      state.uri.queryParameters['onboardingStage'] == 'tour') {
                    return null;
                  }
                  return finished
                      ? null
                      : state.namedLocation(
                          'welcome',
                          pathParameters: chatParameters,
                        );
                },
                builder: (_, GoRouterState state) => Column(
                  children: <Widget>[
                    const Text('chat'),
                    if (!finished &&
                        state.uri.queryParameters['onboardingStage'] ==
                            'tour') ...<Widget>[
                      const Text('tour'),
                      TextButton(
                        onPressed: () {
                          finished = true;
                          router.goNamed(
                            'chat',
                            pathParameters: chatParameters,
                          );
                        },
                        child: const Text('Finish tour'),
                      ),
                    ],
                  ],
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'chat_onboarding',
                    name: 'welcome',
                    parentNavigatorKey: rootKey,
                    builder: (BuildContext context, _) => PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (bool didPop, _) {
                        if (!didPop) {
                          context.goNamed('home');
                        }
                      },
                      child: Scaffold(
                        key: const ValueKey<String>('welcome-page'),
                        body: Column(
                          children: <Widget>[
                            const Text('welcome'),
                            TextButton(
                              onPressed: () => context.goNamed('home'),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => context.goNamed(
                                'chat',
                                pathParameters: chatParameters,
                                queryParameters: <String, dynamic>{
                                  'onboardingStage': 'tour'
                                },
                              ),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'thread/:id',
                    name: 'thread',
                    builder: (_, GoRouterState state) => Text(
                      'thread ${state.pathParameters['id']} ${state.extra}',
                    ),
                  ),
                  GoRoute(
                    path: 'popup/:popupId',
                    name: 'popup',
                    parentNavigatorKey: rootKey,
                    builder: (BuildContext context, _) => Scaffold(
                      body: Column(
                        children: <Widget>[
                          const Text('popup'),
                          TextButton(
                            onPressed: () => context.goNamed('home'),
                            child: const Text('Close popup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _ShellProbe extends StatefulWidget {
  const _ShellProbe({required this.onCreated, required this.child});
  final VoidCallback onCreated;
  final Widget child;

  @override
  State<_ShellProbe> createState() => _ShellProbeState();
}

class _ShellProbeState extends State<_ShellProbe> {
  @override
  void initState() {
    super.initState();
    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
