// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:campus_nav/global_variables.dart';
import 'package:campus_nav/helpers/classes.dart';
import 'package:campus_nav/helpers/custom_marker.dart';
import 'package:campus_nav/helpers/enums.dart';
import 'package:campus_nav/helpers/helper_funcs.dart';
import 'package:campus_nav/helpers/json_helpers.dart';
import 'package:campus_nav/helpers/popups.dart';
import 'package:duration/duration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_math/flutter_geo_math.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:overlay_tooltip/overlay_tooltip.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:units_converter/models/extension_converter.dart';
import 'package:units_converter/properties/length.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSUF Campus Navigation App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 27, 51, 229)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<List<LatLng>> exploredCoordinates = [];
  List<LatLng> shortestCoordinates = [];
  TextEditingController destLookupTextController = TextEditingController();
  LocationMarkerHeading? userMarkerHeadingData;
  Stream<Position> positionStream = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1));
  bool onRoute = true;
  bool showOnlySavedCoords = false;
  Signal headingAccuracy = Signal<double>(0.0);
  late Future permission;

  @override
  void initState() {
    permission = checkLocationPerm();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load mapped markers
      mappedMakers = await loadMappedMarkers(mappedCoordsJsonPath);
      // Load saved coords
      final prefs = await SharedPreferences.getInstance();
      savedCoordList = prefs.getStringList('savedCoords') ?? [];
    });
    super.initState();
  }

  Future<bool> checkLocationPerm() async {
    LocationPermission perm = await Geolocator.checkPermission();
    while (perm != LocationPermission.whileInUse && perm != LocationPermission.always) {
      await Geolocator.requestPermission();
      perm = await Geolocator.checkPermission();
    }
    if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
      return true;
    } else {
      return false;
    }
  }

  void routingFinish() {
    // curPathFindingState = PathFindingState.idle;
    exploredCoordinates.clear();
    shortestCoordinates.clear();
    // destLookupTextController.clear();
    // destinationCoord = null;
    // destName = '';
    mapController.move(centerCoord!, mapDefaultZoomValue);
    mapController.rotate(0);
    manualHeadingValue = 0.0;
    headingAccuracy.value = 0.0;
    contUpdatePos = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [mapView()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: Visibility(visible: mapDoneLoading, child: floatingButtons(context)),
    );
  }

  // Map
  Widget mapView() {
    return FutureBuilder(
      future: permission,
      builder: (context, permSnapshot) {
        if (permSnapshot.hasData && !permSnapshot.hasError) {
          bool? result = permSnapshot.data;
          if (kIsWeb || result!) {
            return StreamBuilder(
                stream: positionStream, // Get current lat & longtitude
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.active) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          '${snapshot.error} occurred',
                          style: const TextStyle(fontSize: 18),
                        ),
                      );
                    } else {
                      // Set center
                      centerCoord = LatLng(snapshot.data!.latitude, snapshot.data!.longitude);
                      // Other algorithms
                      if (curPathFindingState == PathFindingState.finished) {
                        // Update heading data
                        manualHeadingValue = navMapRotation(shortestCoordinates);
                        // Routing events
                        if (shortestCoordinates.isNotEmpty && distanceToDest(centerCoord!, shortestCoordinates) < 15) {
                          arrivedAtDest.value = true;
                          routingFinish();
                        }

                        if (shortestCoordinates.isNotEmpty) {
                          int halfWayIndex = (shortestCoordinates.length ~/ 2) + 1;
                          LatLng halfWayCoord = shortestCoordinates[halfWayIndex];
                          shortestCoordinates.removeRange(0, halfWayIndex);
                          shortestCoordinates.insertAll(0, reRoute(LatLng(centerCoord!.latitude, centerCoord!.longitude), halfWayCoord));
                        }

                        // Estimate time recalc
                        estimateNavTime.value = totalNavTimeCalc(shortestCoordinates, defaultWalkingSpeedMPH).pretty(abbreviated: true);
                      }

                      return FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: centerCoord!,
                          initialZoom: mapDefaultZoomValue,
                          maxZoom: mapMaxZoomValue,
                          cameraConstraint:
                              CameraConstraint.containCenter(bounds: LatLngBounds(const LatLng(33.8892181509212, -117.89024039406391), const LatLng(33.87568283383185, -117.87979836324752))),
                          onMapReady: () {
                            mapDoneLoading = true;
                            setState(() {});
                          },
                          // onPositionChanged: (camera, hasGesture) async {
                          //   // Onroute tracking
                          //   if (curPathFindingState == PathFindingState.finished) {
                          //     onRoute = onRouteCheck(shortestCoordinates);
                          //     if (!onRoute) {
                          //       contUpdatePos = false;
                          //       exploredCoordinates.clear();
                          //       shortestCoordinates.clear();
                          //       curPathFindingState = PathFindingState.finding;
                          //       await traceRoute(centerCoord!, destinationCoord!);
                          //       onRoute = onRouteCheck(shortestCoordinates);
                          //       curPathFindingState = PathFindingState.finished;
                          //       setState(() {});
                          //     }
                          //   }
                          // },
                          onTap: (tapPosition, point) {
                            if (!kIsWeb && showMappingLayer.value) {
                              mappedMakers.add(mappingMaker(point, false, false, false, false));
                              // Get neighbors
                              mappedCoords.add(CoordPoint(
                                  point,
                                  mappedCoords
                                      .where((e) => Geolocator.distanceBetween(point.latitude, point.longitude, e.coord.latitude, e.coord.longitude) <= maxNeighborDistance)
                                      .map((e) => e.coord)
                                      .toList()));
                              for (var coord in mappedCoords.last.neighborCoords) {
                                CoordPoint neighbor = mappedCoords.firstWhere((e) => e.coord.latitude == coord.latitude && e.coord.longitude == coord.longitude);
                                if (neighbor.neighborCoords.indexWhere((e) => e.latitude == point.latitude && e.longitude == point.longitude) == -1) {
                                  neighbor.neighborCoords.add(point);
                                }
                              }
                              mappedPaths.addAll(mappedCoords.last.neighborCoords.map((e) => Polyline(points: [mappedCoords.last.coord, e], strokeWidth: 5, color: Colors.purple)));
                              //Save
                              mappedCoordSave();
                              setState(() {});
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            // Display map tiles from osm
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // OSMF's Tile Server
                            userAgentPackageName: 'com.campusnav.app',
                            // tileBounds: LatLngBounds(const LatLng(33.8892181509212, -117.89024039406391), const LatLng(33.87568283383185, -117.87979836324752)),
                          ),

                          //Mapped markers in nav mode
                          Visibility(
                              visible: showMappingLayer.watch(context) && curPathFindingState != PathFindingState.idle,
                              child: PolylineLayer(
                                polylines: mappedPaths,
                              )),
                          Visibility(visible: showMappingLayer.watch(context) && curPathFindingState != PathFindingState.idle, child: MarkerLayer(markers: mappedMakers)),

                          // Explored Paths
                          Visibility(
                            visible: showExploredPath.watch(context),
                            child: PolylineLayer(polylines: exploredCoordinates.map((e) => Polyline(points: e, color: Colors.red, strokeWidth: 5)).toList()),
                          ),

                          // Shortest Path
                          PolylineLayer(polylines: [
                            Polyline(points: headingPolyline, color: const Color.fromARGB(255, 0, 0, 0), strokeWidth: 5),
                            Polyline(points: shortestCoordinates, color: Colors.blue, strokeWidth: 5)
                          ]),

                          // User location marker
                          CurrentLocationLayer(
                            alignPositionOnUpdate: !contUpdatePos ? AlignOnUpdate.once : AlignOnUpdate.always,
                            alignDirectionOnUpdate: !contUpdatePos ? AlignOnUpdate.once : AlignOnUpdate.always,
                            positionStream: Stream.value(LocationMarkerPosition(latitude: centerCoord!.latitude, longitude: centerCoord!.longitude, accuracy: snapshot.data!.accuracy)),
                            headingStream: (kIsWeb || Platform.isWindows)
                                ? Stream.value(LocationMarkerHeading(heading: manualHeadingValue, accuracy: headingAccuracy.watch(context)))
                                : const LocationMarkerDataStreamFactory().fromCompassHeadingStream(),
                            style: const LocationMarkerStyle(
                              markerDirection: MarkerDirection.heading,
                            ),
                          ),

                          // Map Markers for intertest point
                          Visibility(
                              visible: destinationCoord != null,
                              child: MarkerLayer(alignment: Alignment.center, rotate: true, markers: [
                                if (destinationCoord != null) Marker(width: destName.length > 9 ? destName.length * 9 : 100, height: 80, point: destinationCoord!, child: LabelMarker(destName))
                              ])),

                          //Mapped markers
                          Visibility(
                              visible: showMappingLayer.watch(context) && curPathFindingState == PathFindingState.idle,
                              child: PolylineLayer(
                                polylines: mappedPaths,
                              )),
                          Visibility(
                              visible: showMappingLayer.watch(context) && curPathFindingState == PathFindingState.idle && markedToDelLine.watch(context).points.isNotEmpty,
                              child: PolylineLayer(
                                polylines: [markedToDelLine.watch(context)],
                              )),
                          Visibility(visible: showMappingLayer.watch(context) && curPathFindingState == PathFindingState.idle, child: MarkerLayer(markers: mappedMakers)),

                          // Destination lookup textfield
                          Padding(
                              padding: EdgeInsets.only(
                                  top: kIsWeb
                                      ? 5
                                      : Platform.isAndroid
                                          ? 30
                                          : 5,
                                  bottom: 5,
                                  left: 5,
                                  right: 5),
                              child: TypeAheadField<CoordPoint>(
                                direction: VerticalDirection.down,
                                controller: destLookupTextController,
                                builder: (context, controller, focusNode) => TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  autofocus: false,
                                  style: DefaultTextStyle.of(context).style.copyWith(fontStyle: FontStyle.italic),
                                  decoration: InputDecoration(
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      hintText: 'Enter your destination',
                                      suffixIcon: Row(
                                        spacing: 1,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                              visualDensity: VisualDensity.adaptivePlatformDensity,
                                              onPressed: savedCoordList.isNotEmpty
                                                  ? () {
                                                      if (showOnlySavedCoords) {
                                                        showOnlySavedCoords = false;
                                                        focusNode.unfocus();
                                                      } else {
                                                        showOnlySavedCoords = true;
                                                        focusNode.requestFocus();
                                                      }

                                                      setState(() {});
                                                    }
                                                  : null,
                                              icon: Icon(showOnlySavedCoords ? Icons.saved_search_outlined : Icons.saved_search)),
                                          IconButton(
                                              visualDensity: VisualDensity.adaptivePlatformDensity,
                                              onPressed: () {
                                                if (destLookupTextController.text.isEmpty) {
                                                  curPathFindingState = PathFindingState.idle;
                                                  focusNode.unfocus();
                                                  exploredCoordinates.clear();
                                                  shortestCoordinates.clear();
                                                  destLookupTextController.clear();
                                                  destinationCoord = null;
                                                  destName = '';
                                                  mapController.move(centerCoord!, mapDefaultZoomValue);
                                                  mapController.rotate(0);
                                                  manualHeadingValue = 0.0;
                                                  contUpdatePos = false;
                                                  arrivedAtDest.value = false;
                                                } else {
                                                  destLookupTextController.clear();
                                                  curPathFindingState = PathFindingState.idle;
                                                  destinationCoord = null;
                                                  destName = '';
                                                }
                                                setState(() {});
                                              },
                                              icon: const Icon(Icons.clear))
                                        ],
                                      )),
                                ),
                                decorationBuilder: (context, child) => Material(
                                  type: MaterialType.card,
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(10),
                                  child: child,
                                ),
                                itemBuilder: (context, point) => ListTile(
                                  title: Text(point.locName),
                                  trailing: savedCoordList.contains(coordToString(point.coord)) ? const Icon(Icons.save) : null,
                                ),
                                hideOnEmpty: true,
                                hideOnSelect: true,
                                hideOnUnfocus: true,
                                hideWithKeyboard: true,
                                retainOnLoading: true,
                                onSelected: (point) {
                                  //reset
                                  curPathFindingState = PathFindingState.idle;
                                  exploredCoordinates.clear();
                                  shortestCoordinates.clear();
                                  destLookupTextController.clear();
                                  destinationCoord = null;
                                  destName = '';
                                  mapController.move(centerCoord!, mapDefaultZoomValue);
                                  mapController.rotate(0);
                                  manualHeadingValue = 0.0;
                                  contUpdatePos = false;
                                  arrivedAtDest.value = false;
                                  //new route
                                  destLookupTextController.text = point.locName;
                                  destinationCoord = point.coord;
                                  destName = point.locName;
                                  FocusScope.of(context).unfocus();
                                  mapController.rotate(0);
                                  mapController.move(point.coord, mapDefaultZoomValue);
                                  curPathFindingState = PathFindingState.ready;
                                  setState(() {});
                                },
                                suggestionsCallback: (String search) {
                                  return suggestionsCallback(search, showOnlySavedCoords);
                                },
                                loadingBuilder: (context) => const Text('Loading...'),
                                errorBuilder: (context, error) => const Text('Error!'),
                                emptyBuilder: (context) => const Text('No rooms found!'),
                                // itemSeparatorBuilder: itemSeparatorBuilder,
                                // listBuilder: settings.gridLayout.value ? gridLayoutBuilder : null,
                              )),

                          // Map credit
                          RichAttributionWidget(
                            alignment: AttributionAlignment.bottomLeft,
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')), // (external)
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                });
          } else {
            return const Center(
              child: Text("Location service is blocked"),
            );
          }
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  // Load mapped coords
  Future<List<Marker>> loadMappedMarkers(String jsonPath) async {
    List<Marker> markers = [];
    if (!File(jsonPath).existsSync()) File(jsonPath).createSync();
    String markersFromJson = kIsWeb || Platform.isAndroid ? await rootBundle.loadString(jsonPath) : await File(jsonPath).readAsString();
    if (markersFromJson.isNotEmpty) {
      var jsonData = await jsonDecode(markersFromJson);
      for (var coordPoint in jsonData) {
        mappedCoords.add(CoordPoint.fromJson(coordPoint));
        mappedPaths.addAll(mappedCoords.last.neighborCoords.map((e) => Polyline(points: [mappedCoords.last.coord, e], strokeWidth: 5, color: Colors.purple)));
        markers.add(mappingMaker(CoordPoint.fromJson(coordPoint).coord, CoordPoint.fromJson(coordPoint).isREntrancePoint, CoordPoint.fromJson(coordPoint).isBEntrancePoint,
            CoordPoint.fromJson(coordPoint).isStairsPoint, CoordPoint.fromJson(coordPoint).isElevatorsPoint));
      }
    }

    return markers;
  }

  // Mapping Marker
  Marker mappingMaker(LatLng point, bool? isREntrance, bool? isBEntrance, bool? isStairs, bool? isEvevators) {
    return Marker(
        width: 15,
        height: 15,
        point: point,
        child: InkWell(
            onSecondaryTap: () {
              if (!kIsWeb) {
                for (var element in mappedCoords.where((e) => e.neighborCoords.indexWhere((c) => c.latitude == point.latitude && c.longitude == point.longitude) != -1)) {
                  element.neighborCoords.removeWhere((e) => e.latitude == point.latitude && e.longitude == point.longitude);
                }
                mappedMakers.removeWhere((element) => element.point.latitude == point.latitude && element.point.longitude == point.longitude);
                mappedCoords.removeWhere((element) => element.coord.latitude == point.latitude && element.coord.longitude == point.longitude);
                mappedPaths.removeWhere((e) => e.points.where((p) => p.latitude == point.latitude && p.longitude == point.longitude).isNotEmpty);
                //Save
                mappedCoordSave();
                setState(() {});
              }
            },
            onTap: () async {
              if (!kIsWeb) {
                int index = mappedCoords.indexWhere((e) => e.coord.latitude == point.latitude && e.coord.longitude == point.longitude);
                if (index != -1) {
                  CoordPoint curCoordPoint = mappedCoords[index];
                  await mappingCoordSettingsPopup(context, curCoordPoint);
                  setState(() {});
                }
              }
            },
            child: Icon(Icons.gps_fixed_sharp,
                size: 15,
                color: isREntrance != null && isREntrance
                    ? Colors.green
                    : isBEntrance != null && isBEntrance
                        ? Colors.blue
                        : isStairs != null && isStairs
                            ? Colors.yellow
                            : isEvevators != null && isEvevators
                                ? Colors.orange
                                : null)));
  }

  // A* Algorithm
  Future<void> traceRoute(LatLng startCoord, LatLng destCoord) async {
    List<CoordPoint> exploredPoints = [];
    List<CoordPoint> frontier = [CoordPoint(startCoord, getNearbyPoints(startCoord).map((e) => e.coord).toList())];

    //Center  before trace
    mapController.fitCamera(CameraFit.coordinates(
        coordinates: [startCoord, destCoord], padding: EdgeInsets.symmetric(horizontal: mapController.camera.nonRotatedSize.x / 5, vertical: mapController.camera.nonRotatedSize.y / 5)));

    while (exploredPoints.isEmpty || (exploredPoints.last.coord.latitude != destCoord.latitude && exploredPoints.last.coord.longitude != destCoord.longitude)) {
      var removedFrontierPoint = frontier.removeAt(0);
      if (exploredCoordinates.isNotEmpty && !removedFrontierPoint.neighborCoords.contains(exploredCoordinates.last.last)) {
        exploredCoordinates.add([
          exploredPoints.firstWhere((e) => e.neighborCoords.indexWhere((t) => t.latitude == removedFrontierPoint.coord.latitude && t.longitude == removedFrontierPoint.coord.longitude) != -1).coord
        ]);
      }
      exploredPoints.add(removedFrontierPoint);
      if (exploredCoordinates.isEmpty) exploredCoordinates.add([]);
      exploredCoordinates.last.add(exploredPoints.last.coord);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 10));
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
    while (backTrack.isNotEmpty) {
      shortestCoordinates.add(backTrack.removeLast().coord);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 10));
    }

    routingCoordCount = shortestCoordinates.length;

    // Total time calc
    estimateNavTime.value = totalNavTimeCalc(shortestCoordinates, defaultWalkingSpeedMPH).pretty(abbreviated: true);

    // Zoom back to start point for navigation
    // mapController.move(debugCenterCoord, 19);
    await Future.delayed(const Duration(milliseconds: 100));
    mapController.move(centerCoord!, 19);
    manualHeadingValue = navMapRotation(shortestCoordinates);
    headingAccuracy.value = 0.5;
  }

  // Floating button
  Widget floatingButtons(context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Visibility(
            visible: curPathFindingState == PathFindingState.finished,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 5,
                shape: Theme.of(context).floatingActionButtonTheme.shape,
                color: Theme.of(context).floatingActionButtonTheme.foregroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: SizedBox(
                      height: 25,
                      child: Text(
                        arrivedAtDest.watch(context) ? 'Arrived!' : 'Estimated Time: ${estimateNavTime.watch(context)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      )),
                ),
              ),
            )),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Visibility(
              visible: showDebugButtons,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  direction: Axis.vertical,
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    FloatingActionButton.small(
                        tooltip: showMappingLayer.value ? 'Stop Mapping' : 'Start Mapping',
                        onPressed: () {
                          setState(() {
                            showMappingLayer.value ? showMappingLayer.value = false : showMappingLayer.value = true;
                            debugPrint(showMappingLayer.toString());
                          });
                        },
                        child: Icon(showMappingLayer.value ? Icons.map : Icons.map_outlined)),
                    FloatingActionButton.small(
                        tooltip: showExploredPath.value ? 'Hide Explored' : 'Show Explored',
                        onPressed: () {
                          showExploredPath.value ? showExploredPath.value = false : showExploredPath.value = true;
                          setState(() {});
                        },
                        child: Icon(showExploredPath.value ? Icons.pattern_sharp : Icons.linear_scale_sharp)),
                  ],
                ),
              ),
            ),
            Visibility(
                visible: curPathFindingState == PathFindingState.finished,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FloatingActionButton.small(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          String curCoordString = coordToString(destinationCoord);
                          if (!savedCoordList.contains(curCoordString)) {
                            savedCoordList.add(curCoordString);
                            prefs.setStringList('savedCoords', savedCoordList);
                          } else {
                            savedCoordList.remove(curCoordString);
                            prefs.setStringList('savedCoords', savedCoordList);
                          }
                          setState(() {});
                        },
                        child: Icon(savedCoordList.contains(coordToString(destinationCoord)) ? Icons.save : Icons.save_outlined)))),
            Visibility(
                visible: curPathFindingState == PathFindingState.finished,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FloatingActionButton.small(
                        onPressed: () async {
                          contUpdatePos = false;
                          exploredCoordinates.clear();
                          shortestCoordinates.clear();
                          curPathFindingState = PathFindingState.finding;
                          await traceRoute(centerCoord!, destinationCoord!);
                          curPathFindingState = PathFindingState.finished;
                          contUpdatePos = true;
                          setState(() {});
                        },
                        child: const Icon(Icons.route_outlined)))),
            Visibility(
                visible: curPathFindingState == PathFindingState.finished,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FloatingActionButton.small(
                        onPressed: () {
                          mapController.move(centerCoord!, 19);
                          setState(() {});
                        },
                        child: const Icon(Icons.gps_fixed_outlined)))),
            GestureDetector(
              onLongPress: () {
                showDebugButtons ? showDebugButtons = false : showDebugButtons = true;
                setState(() {});
              },
              child: FloatingActionButton(
                  onPressed: () async {
                    if (curPathFindingState == PathFindingState.idle) {
                      mapController.rotate(0);
                      mapController.move(centerCoord!, mapDefaultZoomValue);
                      manualHeadingValue = 0.0;
                    } else if (curPathFindingState == PathFindingState.finding || curPathFindingState == PathFindingState.finished) {
                      curPathFindingState = PathFindingState.idle;
                      exploredCoordinates.clear();
                      shortestCoordinates.clear();
                      destLookupTextController.clear();
                      destinationCoord = null;
                      destName = '';
                      mapController.move(centerCoord!, mapDefaultZoomValue);
                      mapController.rotate(0);
                      manualHeadingValue = 0.0;
                      headingAccuracy.value = 0.0;
                      contUpdatePos = false;
                    } else {
                      exploredCoordinates.clear();
                      shortestCoordinates.clear();
                      curPathFindingState = PathFindingState.finding;
                      setState(() {});
                      await traceRoute(centerCoord!, destinationCoord!);
                      arrivedAtDest.value = false;
                      curPathFindingState = PathFindingState.finished;
                      contUpdatePos = true;
                    }
                    setState(() {});
                  },
                  child: curPathFindingState == PathFindingState.finding
                      ? const CircularProgressIndicator(strokeWidth: 6)
                      : Icon(curPathFindingState == PathFindingState.idle
                          ? Icons.gps_fixed_outlined
                          : curPathFindingState == PathFindingState.finished
                              ? Icons.stop
                              : Icons.play_arrow)),
            ),
          ],
        )
      ],
    );
  }
}
