import 'package:latlong2/latlong.dart';
import 'package:json_annotation/json_annotation.dart';

part 'classes.g.dart';

@JsonSerializable()
class CoordPoint {
  CoordPoint(this.coord, this.neighborCoords);
  LatLng coord;
  String locName = '';
  bool? isBEntrancePoint = false;
  bool? isREntrancePoint = false;
  bool? isStairsPoint = false;
  bool? isElevatorsPoint = false;
  @JsonKey(includeFromJson: false, includeToJson: false)
  double gVal = 0.0;
  @JsonKey(includeFromJson: false, includeToJson: false)
  double hVal = 0.0;
  @JsonKey(includeFromJson: false, includeToJson: false)
  double fVal = 0.0;
  List<LatLng> neighborCoords;

  factory CoordPoint.fromJson(Map<String, dynamic> json) => _$CoordPointFromJson(json);
  Map<String, dynamic> toJson() => _$CoordPointToJson(this);
}
