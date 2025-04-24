import 'package:flutter/material.dart';

class LabelMarker extends StatelessWidget {
  final String name;
  const LabelMarker(this.name, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 20.0,
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.green,
              ),
              borderRadius: const BorderRadius.only(topRight: Radius.circular(5), topLeft: Radius.circular(5))),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        Container(
            height: 5.0,
            decoration: BoxDecoration(
                color: Colors.green,
                border: Border.all(
                  color: Colors.green,
                ),
                borderRadius: const BorderRadius.only(bottomRight: Radius.circular(5), bottomLeft: Radius.circular(5)))),
        ClipPath(
          clipper: CustomClipPath(),
          child: Container(
            width: 25.0,
            height: 40.0,
            color: Colors.green,
          ),
        )
      ],
    );
  }
}

class CustomClipPath extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width / 3, 0.0);
    path.lineTo(size.width / 2, size.height / 3);
    path.lineTo(size.width - size.width / 3, 0.0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
