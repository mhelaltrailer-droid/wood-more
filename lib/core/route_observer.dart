import 'package:flutter/material.dart';

class RouteObserverProvider {
  RouteObserverProvider._();
  static final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
}
