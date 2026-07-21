import 'package:flutter/material.dart';

/// App-wide [RouteObserver] for [RouteAware] subscribers.
///
/// Wired on the [ShellRoute] navigator so watch-page [PlayerPane]s receive
/// push/pop/cover events for stacked `/video/:id` routes (related → back).
///
/// **Must be [PageRoute], not [ModalRoute].** [PopupMenuButton] / [showMenu]
/// push a [PopupRoute] (still a [ModalRoute]). With `RouteObserver<ModalRoute>`,
/// opening quality/speed/subtitle menus fires [RouteAware.didPushNext] on the
/// watch page → [PlayerPane] releases the inline surface → video “interrupts”.
/// Fullscreen is fine because it never subscribes to this observer.
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();
