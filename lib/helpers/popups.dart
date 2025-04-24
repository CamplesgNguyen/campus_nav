import 'package:classroom_nav/global_variables.dart';
import 'package:classroom_nav/helpers/classes.dart';
import 'package:classroom_nav/helpers/json_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:toggle_switch/toggle_switch.dart';

Future<void> mappingCoordSettingsPopup(context, CoordPoint point) async {
  TextEditingController newLocName = TextEditingController();
  newLocName.text = point.locName;
  int locTypeIndex = point.isREntrancePoint != null && point.isREntrancePoint!
      ? 1
      : point.isBEntrancePoint != null && point.isBEntrancePoint!
          ? 2
          : point.isStairsPoint != null && point.isStairsPoint!
              ? 3
              : point.isElevatorsPoint != null && point.isREntrancePoint!
                  ? 4
                  : 0;
  List<LatLng> toBeRemovedNeighborCoords = [];
  final nameFormKey = GlobalKey<FormState>();

  return await showDialog(
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
                insetPadding: EdgeInsets.zero,
                alignment: Alignment.topLeft,
                shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).primaryColorLight), borderRadius: const BorderRadius.all(Radius.circular(5))),
                titlePadding: const EdgeInsets.only(top: 10, bottom: 10, left: 10, right: 10),
                title: const Text('Coord Settings', style: TextStyle(fontWeight: FontWeight.w700)),
                contentPadding: const EdgeInsets.only(left: 10, right: 10),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Types', style: Theme.of(context).textTheme.titleMedium),
                    ToggleSwitch(
                      minWidth: double.infinity,
                      minHeight: 30,
                      initialLabelIndex: locTypeIndex,
                      animate: true,
                      totalSwitches: 5,
                      labels: const ['None', 'Room Entrance', 'Building Entrance', 'Stairs', 'Elevators'],
                      onToggle: (index) {
                        if (index != null) {
                          locTypeIndex = index;
                          setState(() {});
                        }
                      },
                    ),
                    Divider(
                      thickness: 2,
                      color: Theme.of(context).dividerColor,
                    ),
                    Text('Location Name', style: Theme.of(context).textTheme.titleMedium),
                    Form(
                      key: nameFormKey,
                      child: TextFormField(
                        enabled: locTypeIndex == 1 || locTypeIndex == 2,
                        controller: newLocName,
                        maxLines: 1,
                        textAlignVertical: TextAlignVertical.center,
                        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.deny(RegExp('[\\/:*?"<>|]'))],
                        validator: (value) {
                          if (mappedCoords.indexWhere((e) => e.locName.toLowerCase() == value!.toLowerCase()) != -1 && value!.isNotEmpty) {
                            return 'This name already existed';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                            labelText: 'Enter location name',
                            hintText: 'CS 101',
                            hintStyle: TextStyle(color: Theme.of(context).hintColor.withAlpha(50)),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(width: 1, color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(width: 1, color: Theme.of(context).colorScheme.error),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            //isCollapsed: true,
                            //isDense: true,
                            contentPadding: const EdgeInsets.only(left: 5, right: 5, bottom: 2),
                            constraints: const BoxConstraints.tightForFinite(),
                            // Set border for enabled state (default)
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(width: 1, color: Theme.of(context).hintColor),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            // Set border for focused state
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(width: 1, color: Theme.of(context).colorScheme.primary),
                              borderRadius: BorderRadius.circular(2),
                            )),
                        onChanged: (value) async {
                          setState(() {
                            nameFormKey.currentState!.validate();
                          });
                        },
                      ),
                    ),
                    Divider(
                      thickness: 2,
                      color: Theme.of(context).dividerColor,
                    ),
                    Text('Connected coords', style: Theme.of(context).textTheme.titleMedium),
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < point.neighborCoords.length; i++)
                            ListTile(
                              dense: true,
                              title: Text('Lat: ${point.neighborCoords[i].latitude}\nLng: ${point.neighborCoords[i].longitude}'),
                              trailing: ElevatedButton.icon(
                                  onPressed: () {
                                    if (!toBeRemovedNeighborCoords.contains(point.neighborCoords[i])) {
                                      toBeRemovedNeighborCoords.add(point.neighborCoords[i]);
                                      markedToDelLine.value = Polyline(points: [point.coord, point.neighborCoords[i]], color: Colors.red, strokeWidth: 6);
                                    } else {
                                      toBeRemovedNeighborCoords.remove(point.neighborCoords[i]);
                                      markedToDelLine.value = Polyline(points: []);
                                    }
                                    setState(
                                      () {},
                                    );
                                  },
                                  label: Icon(Icons.delete, color: toBeRemovedNeighborCoords.contains(point.neighborCoords[i]) ? Colors.red : null)),
                            )
                        ],
                      ),
                    )
                  ],
                ),
                actionsPadding: const EdgeInsets.all(10),
                actions: <Widget>[
                  ElevatedButton(
                      child: const Text('Cancel'),
                      onPressed: () async {
                        markedToDelLine.value = Polyline(points: []);
                        Navigator.pop(context);
                      }),
                  ElevatedButton(
                      onPressed: () async {
                        markedToDelLine.value = Polyline(points: []);
                        // Rename
                        if (nameFormKey.currentState!.validate()) {
                          point.locName = newLocName.text;
                        }
                        // Types
                        locTypeIndex == 1
                            ? point.isREntrancePoint = true
                            : locTypeIndex == 2
                                ? point.isBEntrancePoint = true
                                : locTypeIndex == 3
                                    ? point.isStairsPoint = true
                                    : locTypeIndex == 4
                                        ? point.isElevatorsPoint = true
                                        : locTypeIndex = 0;
                        // Neighbor coords
                        for (var element in toBeRemovedNeighborCoords) {
                          mappedCoords
                              .firstWhere((e) => e.coord.latitude == element.latitude && e.coord.longitude == element.longitude)
                              .neighborCoords
                              .removeWhere((e) => e.latitude == point.coord.latitude && e.longitude == point.coord.longitude);
                        }
                        point.neighborCoords.removeWhere((e) => toBeRemovedNeighborCoords.contains(e));
                        for (var element in toBeRemovedNeighborCoords) {
                          mappedPaths.removeWhere((e) =>
                              e.points.where((c) => c.latitude == element.latitude && c.longitude == element.longitude).isNotEmpty &&
                              e.points.where((c) => c.latitude == point.coord.latitude && c.longitude == point.coord.longitude).isNotEmpty);
                        }
                        //Save
                        mappedCoordSave();
                        Navigator.pop(context);
                      },
                      child: const Text('Save'))
                ]);
          }));
}
