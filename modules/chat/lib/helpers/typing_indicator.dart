import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({
    super.key,
    required this.showIndicator,
  });

  /// Used to hide indicator when the [options.typingUsers] is empty.
  final bool showIndicator;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late double stackingWidth;
  late AnimationController _appearanceController;
  late AnimationController _animatedCirclesController;
  late Animation<double> _indicatorSpaceAnimation;
  late Animation<Offset> _firstCircleOffsetAnimation;
  late Animation<Offset> _secondCircleOffsetAnimation;
  late Animation<Offset> _thirdCircleOffsetAnimation;

  @override
  void initState() {
    super.initState();
    _appearanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _indicatorSpaceAnimation = CurvedAnimation(
      parent: _appearanceController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ).drive(Tween<double>(
      begin: 0.0,
      end: 60.0,
    ));

    _animatedCirclesController = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
      duration: const Duration(milliseconds: 500),
    )..repeat();

    _firstCircleOffsetAnimation = _circleOffset(
      Offset.zero,
      const Offset(0.0, -0.9),
      const Interval(0.0, 1.0, curve: Curves.linear),
    );
    _secondCircleOffsetAnimation = _circleOffset(
      Offset.zero,
      const Offset(0.0, -0.8),
      const Interval(0.3, 1.0, curve: Curves.linear),
    );
    _thirdCircleOffsetAnimation = _circleOffset(
      Offset.zero,
      const Offset(0.0, -0.9),
      const Interval(0.45, 1.0, curve: Curves.linear),
    );

    if (widget.showIndicator) {
      _appearanceController.forward();
    }
  }

  /// Handler for circles offset.
  Animation<Offset> _circleOffset(
    Offset? start,
    Offset? end,
    Interval animationInterval,
  ) =>
      TweenSequence<Offset>(
        <TweenSequenceItem<Offset>>[
          TweenSequenceItem<Offset>(
            tween: Tween<Offset>(
              begin: start,
              end: end,
            ),
            weight: 50.0,
          ),
          TweenSequenceItem<Offset>(
            tween: Tween<Offset>(
              begin: end,
              end: start,
            ),
            weight: 50.0,
          ),
        ],
      ).animate(CurvedAnimation(
        parent: _animatedCirclesController,
        curve: animationInterval,
        reverseCurve: animationInterval,
      ));

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showIndicator != oldWidget.showIndicator) {
      if (widget.showIndicator) {
        _appearanceController.forward();
      } else {
        _appearanceController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    _animatedCirclesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _indicatorSpaceAnimation,
        builder: (context, child) => SizedBox(
          height: _indicatorSpaceAnimation.value,
          child: child,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(left: 16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.white.withOpacity(0.15),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Wrap(
                  spacing: 3.0,
                  children: <Widget>[
                    AnimatedCircles(
                      circlesColor: Colors.white,
                      animationOffset: _firstCircleOffsetAnimation,
                    ),
                    AnimatedCircles(
                      circlesColor: Colors.white,
                      animationOffset: _secondCircleOffsetAnimation,
                    ),
                    AnimatedCircles(
                      circlesColor: Colors.white,
                      animationOffset: _thirdCircleOffsetAnimation,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class AnimatedCircles extends StatelessWidget {
  const AnimatedCircles({
    super.key,
    required this.circlesColor,
    required this.animationOffset,
  });

  final Color circlesColor;
  final Animation<Offset> animationOffset;
  @override
  Widget build(BuildContext context) => SlideTransition(
        position: animationOffset,
        child: Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(
            color: circlesColor,
            shape: BoxShape.circle,
          ),
        ),
      );
}
