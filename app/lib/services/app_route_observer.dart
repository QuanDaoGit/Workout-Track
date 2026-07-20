import 'package:flutter/widgets.dart';

/// The app's single [RouteObserver], registered on the root navigator
/// (`main.dart`). Lets shell surfaces react to routes covering/uncovering
/// them via [RouteAware] — first consumer: the Home room bed, which must stop
/// whenever ANY route is pushed over the shell and re-sync on return.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
