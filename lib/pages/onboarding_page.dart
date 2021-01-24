import 'dart:math';

import 'package:chat/widgets/centered_scrollable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingPage extends StatefulWidget {
  final ValueChanged<String> nameCallback;

  const OnboardingPage({Key key, @required this.nameCallback})
      : super(key: key);

  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final logoSize = min(size.width, size.height) / 2;
    return CenteredScrollable(
      children: [
        SvgPicture.asset(
          "assets/logo.svg",
          width: logoSize,
          height: logoSize,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: logoSize),
          child: Text(
            "Welcome to Beacon! Enter you name below to get started...",
            style: TextStyle(height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
        TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: "Name"),
        ),
        SizedBox(height: 8.0),
        RaisedButton(
          onPressed: _controller.text.isEmpty
              ? null
              : () {
            widget.nameCallback(_controller.text);
          },
          child: Text("Let's go!"),
        ),
      ],
    );
  }
}