import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class AnimatedLogo extends StatefulWidget {
  final double size;

  const AnimatedLogo({Key key, this.size}) : super(key: key);

  @override
  _AnimatedLogoState createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> {
  Artboard _artboard;
  RiveAnimationController _controller;

  @override
  void initState() {
    super.initState();
    rootBundle.load("assets/logo.riv").then((data) async {
      final file = RiveFile();
      if (file.import(data)) {
        final artboard = file.mainArtboard;
        artboard.addController(_controller = SimpleAnimation("Animate"));
        _controller.isActive = true;
        setState(() {
          _artboard = artboard;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _artboard == null ? null : Rive(artboard: _artboard),
    );
  }
}
