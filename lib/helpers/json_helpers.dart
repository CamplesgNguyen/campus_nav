import 'dart:convert';
import 'dart:io';

import 'package:campus_nav/global_variables.dart';


void mappedCoordSave() {
  mappedCoords.map((e) => e.toJson()).toList();
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  File(mappedCoordsJsonPath).writeAsStringSync(encoder.convert(mappedCoords));
}
