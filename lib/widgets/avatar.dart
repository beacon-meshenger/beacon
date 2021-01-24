import 'package:flutter/material.dart';

const _avatarTextStyle = TextStyle(color: Colors.white);



class Avatar extends StatelessWidget {
  final String user;
  final Color color;
  final double size;

  const Avatar({
    Key key,
    @required this.user,
    @required this.color,
    this.size = 32.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
      ),
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Text(user, style: _avatarTextStyle),
    );
  }
}
