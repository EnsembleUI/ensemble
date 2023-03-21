import 'package:ensemble/framework/widget/modal_screen.dart';
import 'package:flutter/material.dart';

class EnsemblePageRoute extends MaterialPageRoute {
  EnsemblePageRoute({required builder, this.asModal})
      : super(builder: builder, fullscreenDialog: asModal ?? false);

  final bool? asModal;

  /*
  @override
  Duration get transitionDuration => Duration(milliseconds: (asModal ? 0 : 300));
  */
}

class EnsemblePageRouteBuilder extends PageRouteBuilder {
  EnsemblePageRouteBuilder({required Widget screenWidget})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => screenWidget,

          /*
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      }

       */
        );
}

class EnsembleModalPageRouteBuilder extends PageRouteBuilder {
  EnsembleModalPageRouteBuilder({required Widget screenWidget})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => ModalScreen(
            screenWidget: screenWidget,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.ease;

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          fullscreenDialog: true,
          barrierDismissible: true,
          opaque: false,
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 250),
        );
}
