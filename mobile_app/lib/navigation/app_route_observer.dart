import 'package:flutter/material.dart';

/// Permet aux écrans (ex. rapports) de se rafraîchir quand on revient d’une autre route.
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
