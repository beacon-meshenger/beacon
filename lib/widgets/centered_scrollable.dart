import 'package:flutter/material.dart';

class CenteredScrollable extends StatelessWidget {
  final List<Widget> children;

  const CenteredScrollable({@required this.children});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            alignment: Alignment.center,
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - mq.viewPadding.vertical,
            ),
            padding: const EdgeInsets.all(48.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        );
      },
    );
  }
}