import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

//ignore: must_be_immutable
class SwipingGestureDetector<T> extends StatefulWidget {
  SwipingGestureDetector({
    Key? key,
    required this.cardDeck,
    required this.swipeLeft,
    required this.swipeRight,
    required this.cardWidth,
    this.minimumVelocity = 1000,
    this.rotationFactor = .8 / 3.14,
    this.swipeAnimationDuration = const Duration(milliseconds: 500),
    required this.swipeThreshold,
    this.disableDragging = false,
    this.onDrag, // Added onDrag callback
    this.onEnd,   // Added onEnd callback
  }) : super(key: key);

  final List<T> cardDeck;
  final Function() swipeLeft, swipeRight;
  final double minimumVelocity;
  final double rotationFactor;
  final double swipeThreshold;
  final double cardWidth;
  final Duration swipeAnimationDuration;
  final bool disableDragging;
  final Function(double)? onDrag; // Make the callback optional
  final VoidCallback? onEnd;  // Optional callback when dragging ends

  Alignment dragAlignment = Alignment.center;

  late final AnimationController swipeController;
  late Animation<Alignment> swipe;

  @override
  State<StatefulWidget> createState() => _SwipingGestureDetector();
}

class _SwipingGestureDetector extends State<SwipingGestureDetector>
    with TickerProviderStateMixin {
  bool animationActive = false;
  late final AnimationController springController;
  late Animation<Alignment> spring;

  @override
  void initState() {
    super.initState();
    springController = AnimationController(vsync: this);
    springController.addListener(() {
      setState(() {
        widget.dragAlignment = spring.value;
      });
    });

    widget.swipeController = AnimationController(
        vsync: this, duration: widget.swipeAnimationDuration);
    widget.swipeController.addListener(() {
      setState(() {
        widget.dragAlignment = widget.swipe.value;
      });
    });
  }

  @override
  void didUpdateWidget(covariant SwipingGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.swipeController = oldWidget.swipeController;
  }

  @override
  void dispose() {
    springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onPanUpdate: !widget.disableDragging ? _onPanUpdate : (_) {},
      onPanStart: !widget.disableDragging ? _onPanStart : (_) {},
      onPanEnd: !widget.disableDragging
          ? (details) => _onPanEnd(details, screenSize)
          : (_) {},
      child: Stack(
        alignment: Alignment.center,
        children: topTwoCards(),
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      widget.dragAlignment += Alignment(details.delta.dx, details.delta.dy);
      // Call the onDrag callback with the horizontal drag position
      widget.onDrag?.call(widget.dragAlignment.x);  // Safe call using ?.
    });
  }

  void _onPanStart(DragStartDetails details) async {
    if (animationActive) {
      springController.stop();
    }
  }

  void _onPanEnd(DragEndDetails details, Size screenSize) async {
    double vx = details.velocity.pixelsPerSecond.dx;
    if (vx >= widget.minimumVelocity ||
        widget.dragAlignment.x >= widget.swipeThreshold) {
      await widget.swipeRight();
    } else if (vx <= -widget.minimumVelocity ||
        widget.dragAlignment.x <= -widget.swipeThreshold) {
      await widget.swipeLeft();
    } else {
      animateBackToDeck(details.velocity.pixelsPerSecond, screenSize);
    }
     widget.onEnd?.call(); // Call onEnd after handling swipe/back animation

    setState(() {
      widget.dragAlignment = Alignment.center;
    });
  }

  List<Widget> topTwoCards() {
    if (widget.cardDeck.isEmpty) {
      return [
        const SizedBox(
          height: 0,
          width: 0,
        )
      ];
    }
    List<Widget> cardDeck = [];
    int deckLength = widget.cardDeck.length;
    for (int i = max(deckLength - 2, 0); i < deckLength; ++i) {
      cardDeck.add(widget.cardDeck[i]);
    }
    Widget topCard = cardDeck.last;
    cardDeck.removeLast();
    cardDeck.add(
      Align(
          alignment: Alignment(getCardXPosition(), 0),
          child: Transform.rotate(
            angle: getCardAngle(),
            child: topCard,
          )),
    );
    return cardDeck;
  }

  double getCardAngle() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return widget.rotationFactor * (widget.dragAlignment.x / screenWidth);
  }

  double getCardXPosition() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return widget.dragAlignment.x / ((screenWidth - widget.cardWidth) / 2);
  }

  void animateBackToDeck(Offset pixelsPerSecond, Size size) async {
    spring = springController.drive(
      AlignmentTween(
        begin: widget.dragAlignment,
        end: Alignment.center,
      ),
    );

    // Calculate the velocity relative to the unit interval, [0,1],
    // used by the animation controller.
    final unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;

    const springProps = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1,
    );

    final simulation = SpringSimulation(springProps, 0, 1, -unitVelocity);
    animationActive = true;
    await springController.animateWith(simulation);
    animationActive = false;
  }
}