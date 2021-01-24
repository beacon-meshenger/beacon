import 'package:flutter/material.dart';

const _avatarTextStyle = TextStyle(color: Colors.white);

class Avatar extends StatelessWidget {
  final String user;
  final double size;

  const Avatar({
    Key key,
    @required this.user,
    this.size = 32.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.accentColor,
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
      ),
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Text(user[0], style: _avatarTextStyle),
    );
  }
}
