import 'package:flutter/material.dart';

class CustomLabelMarker extends StatelessWidget {
  final String name;
  const CustomLabelMarker(this.name, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 25.0,
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(width: 1.5, color: Colors.green),
              borderRadius: const BorderRadius.all(Radius.circular(5))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                ),
          ),
        ),
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
