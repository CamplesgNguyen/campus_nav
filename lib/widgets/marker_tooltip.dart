import 'package:classroom_nav/global_variables.dart';
import 'package:classroom_nav/helpers/classes.dart';
import 'package:classroom_nav/helpers/json_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:toggle_switch/toggle_switch.dart';

class MarkerTooltip extends StatefulWidget {
  const MarkerTooltip({super.key, required this.point});

  final CoordPoint point;

  @override
  State<MarkerTooltip> createState() => _MarkerTooltipState();
}

class _MarkerTooltipState extends State<MarkerTooltip> {
  TextEditingController newLocName = TextEditingController();
  List<LatLng> toBeRemovedNeighborCoords = [];
  final nameFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    newLocName.text = widget.point.locName;
    int locTypeIndex = widget.point.isREntrancePoint != null && widget.point.isREntrancePoint!
        ? 1
        : widget.point.isBEntrancePoint != null && widget.point.isBEntrancePoint!
            ? 2
            : widget.point.isStairsPoint != null && widget.point.isStairsPoint!
                ? 3
                : widget.point.isElevatorsPoint != null && widget.point.isREntrancePoint!
                    ? 4
                    : 0;

    return Column(
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
              for (int i = 0; i < widget.point.neighborCoords.length; i++)
                ListTile(
                  dense: true,
                  title: Text('Lat: ${widget.point.neighborCoords[i].latitude}\nLng: ${widget.point.neighborCoords[i].longitude}'),
                  trailing: ElevatedButton.icon(
                      onPressed: () {
                        if (!toBeRemovedNeighborCoords.contains(widget.point.neighborCoords[i])) {
                          toBeRemovedNeighborCoords.add(widget.point.neighborCoords[i]);
                        } else {
                          toBeRemovedNeighborCoords.remove(widget.point.neighborCoords[i]);
                        }
                        setState(
                          () {},
                        );
                      },
                      label: Icon(Icons.delete, color: toBeRemovedNeighborCoords.contains(widget.point.neighborCoords[i]) ? Colors.red : null)),
                )
            ],
          ),
        ),
        ElevatedButton(
            onPressed: () async {
              // Rename
              if (nameFormKey.currentState!.validate()) {
                widget.point.locName = newLocName.text;
              }
              // Types
              locTypeIndex == 1
                  ? widget.point.isREntrancePoint = true
                  : locTypeIndex == 2
                      ? widget.point.isBEntrancePoint = true
                      : locTypeIndex == 3
                          ? widget.point.isStairsPoint = true
                          : locTypeIndex == 4
                              ? widget.point.isElevatorsPoint = true
                              : locTypeIndex = 0;
              // Neighbor coords
              for (var element in toBeRemovedNeighborCoords) {
                mappedCoords
                    .firstWhere((e) => e.coord.latitude == element.latitude && e.coord.longitude == element.longitude)
                    .neighborCoords
                    .removeWhere((e) => e.latitude == widget.point.coord.latitude && e.longitude == widget.point.coord.longitude);
              }
              widget.point.neighborCoords.removeWhere((e) => toBeRemovedNeighborCoords.contains(e));
              for (var element in toBeRemovedNeighborCoords) {
                mappedPaths.removeWhere((e) =>
                    e.points.where((c) => c.latitude == element.latitude && c.longitude == element.longitude).isNotEmpty &&
                    e.points.where((c) => c.latitude == widget.point.coord.latitude && c.longitude == widget.point.coord.longitude).isNotEmpty);
              }
              //Save
              mappedCoordSave();
            },
            child: const Text('Save'))
      ],
    );
  }
}
