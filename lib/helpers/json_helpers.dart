import 'dart:convert';
import 'dart:io';

import 'package:classroom_nav/global_variables.dart';

void mappedCoordSave() {
  mappedCoords.map((e) => e.toJson()).toList();
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  File(mappedCoordsLocalJsonPath).writeAsStringSync(encoder.convert(mappedCoords));
}
