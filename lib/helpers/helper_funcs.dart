import 'package:classroom_nav/global_variables.dart';
import 'package:classroom_nav/helpers/classes.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:units_converter/units_converter.dart';

List<CoordPoint> getNearbyPoints(LatLng curCoord) {
  List<CoordPoint> neighborCoords = [];
  double distanceFromCurCoord = 10;
  bool found = false;
  while (!found) {
    final foundCoords = mappedCoords.where((e) => Geolocator.distanceBetween(curCoord.latitude, curCoord.longitude, e.coord.latitude, e.coord.longitude) <= distanceFromCurCoord);
    if (foundCoords.isNotEmpty) {
      neighborCoords = foundCoords.toList();
      found = true;
    } else {
      distanceFromCurCoord += 5;
    }
  }

  return neighborCoords;
}

List<LatLng> getCoordsInRange(List<LatLng> coords) {
  return coords.where((e) => routingCoordCount > coords.length && Geolocator.distanceBetween(centerCoord!.latitude, centerCoord!.longitude, e.latitude, e.longitude) < maxNeighborDistance).toList();
}

bool onRouteCheck(List<LatLng> coords) {
  if (routingCoordCount > coords.length &&
      coords.where((e) => e != coords.first && Geolocator.distanceBetween(centerCoord!.latitude, centerCoord!.longitude, e.latitude, e.longitude) < maxNeighborDistance).length > 1) {
    return false;
  }
  return true;
}

Future<List<CoordPoint>> suggestionsCallback(String pattern) async => Future<List<CoordPoint>>.delayed(
      const Duration(milliseconds: 100),
      () => mappedCoords.where((e) => e.locName.isNotEmpty).where((point) {
        final nameLower = point.locName.toLowerCase().split(' ').join('');
        final patternLower = pattern.toLowerCase().split(' ').join('');
        return nameLower.contains(patternLower);
      }).toList(),
    );

Duration totalNavTimeCalc(List<LatLng> coords, double avgSpeed) {
  if (coords.isNotEmpty) {
    LatLng prevCoord = coords.first;
    double distance = 0;
    for (var coord in coords) {
      distance += Geolocator.distanceBetween(prevCoord.latitude, prevCoord.longitude, coord.latitude, coord.longitude);
      prevCoord = coord;
    }
    double? distanceInMiles = distance.convertFromTo(LENGTH.meters, LENGTH.miles);
    if (distanceInMiles != null) {
      double time = distanceInMiles / avgSpeed;
      return Duration(minutes: time.convertFromTo(TIME.hours, TIME.minutes)!.toInt(), seconds: time.convertFromTo(TIME.hours, TIME.seconds)!.toInt());
    } else {
      return const Duration(seconds: 0);
    }
  }
  return const Duration(seconds: 0);
}

double distanceToDest(LatLng curCoord, List<LatLng> coords) {
  if (coords.isNotEmpty) {
    LatLng prevCoord = coords.first;
    double distance = 0;
    for (var coord in coords) {
      distance += Geolocator.distanceBetween(prevCoord.latitude, prevCoord.longitude, coord.latitude, coord.longitude);
      prevCoord = coord;
    }
    return distance;
  } else {
    return 0;
  }
}



double navMapRotation(List<LatLng> coords) {
  if (coords.isNotEmpty) {
    LatLng closestCoord = coords.first;
    double closestDistance = -1;
    for (var coord in coords) {
      if (coord == coords.first) continue;
      double newDistance = Geolocator.distanceBetween(centerCoord!.latitude, centerCoord!.longitude, coord.latitude, coord.longitude);
      if (closestDistance == -1 || newDistance < closestDistance) {
        closestDistance = newDistance;
        closestCoord = coord;
      }
    }

    double newHeadingAngle = Geolocator.bearingBetween(centerCoord!.latitude, centerCoord!.longitude, closestCoord.latitude, closestCoord.longitude);
    return degToRadian(newHeadingAngle);
  }

  return prevRotationValue;
}

// A* Algorithm for rerouting
List<LatLng> reRoute(LatLng startCoord, LatLng destCoord) {
  List<CoordPoint> exploredPoints = [];
  List<CoordPoint> frontier = [CoordPoint(startCoord, getNearbyPoints(startCoord).map((e) => e.coord).toList())];

  while (exploredPoints.isEmpty || (exploredPoints.last.coord.latitude != destCoord.latitude && exploredPoints.last.coord.longitude != destCoord.longitude)) {
    exploredPoints.add(frontier.removeAt(0));
    List<CoordPoint> neighborPoints = mappedCoords
        .where((e) => exploredPoints.last.neighborCoords.map((n) => [n.latitude, n.longitude]).where((m) => m.first == e.coord.latitude && m.last == e.coord.longitude).isNotEmpty)
        .toList();
    for (var point in neighborPoints) {
      // Calc path values
      point.gVal = Geolocator.distanceBetween(point.coord.latitude, point.coord.longitude, exploredPoints.last.coord.latitude, exploredPoints.last.coord.longitude);
      point.hVal = Geolocator.distanceBetween(point.coord.latitude, point.coord.longitude, destCoord.latitude, destCoord.longitude);
      point.fVal = point.gVal + point.hVal;

      // Store points
      int indexOfSamePointInFrontier = frontier.indexWhere((e) => e.coord.latitude == point.coord.latitude && e.coord.longitude == point.coord.longitude);
      if (indexOfSamePointInFrontier == -1 && exploredPoints.indexWhere((e) => e.coord.latitude == point.coord.latitude && e.coord.longitude == point.coord.longitude) == -1) {
        frontier.add(point);
      } else if (indexOfSamePointInFrontier != -1 && frontier[indexOfSamePointInFrontier].fVal > point.fVal) {
        frontier.removeAt(indexOfSamePointInFrontier);
        frontier.insert(indexOfSamePointInFrontier, point);
      }
    }
    frontier.sort((a, b) => a.fVal.compareTo(b.fVal));
  }

  // Back track to get shortest path
  List<CoordPoint> backTrack = [];
  while (exploredPoints.isNotEmpty) {
    if (backTrack.isEmpty) {
      backTrack.add(exploredPoints.removeLast());
    } else if (backTrack.last.neighborCoords.indexWhere((e) => e.latitude == exploredPoints.last.coord.latitude && e.longitude == exploredPoints.last.coord.longitude) != -1 ||
        exploredPoints.length == 1) {
      backTrack.add(exploredPoints.removeLast());
    } else {
      exploredPoints.removeLast();
    }
  }

  // Reverse push to draw shortest path
  List<LatLng> shortestPath = [];
  while (backTrack.isNotEmpty) {
    shortestPath.add(backTrack.removeLast().coord);
  }

  return shortestPath;
}
