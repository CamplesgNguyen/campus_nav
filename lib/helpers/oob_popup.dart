import 'dart:io';

import 'package:campus_nav/global_variables.dart';
import 'package:campus_nav/helpers/classes.dart';
import 'package:campus_nav/helpers/helper_funcs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';

Future<LatLng?> outOfBoundPopup(context) async {
  TextEditingController destLookupTextController = TextEditingController();
  LatLng? selectedLocation;

  return await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
                alignment: Alignment.topCenter,
                insetPadding: EdgeInsets.only(
                    top: kIsWeb
                        ? 5
                        : Platform.isAndroid
                            ? 30
                            : 5,
                    bottom: 5,
                    left: 5,
                    right: 5),
                shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).primaryColorLight), borderRadius: const BorderRadius.all(Radius.circular(5))),
                titlePadding: const EdgeInsets.only(top: 10, bottom: 10, left: 10, right: 10),
                title: const Text('Out of Bound', style: TextStyle(fontWeight: FontWeight.w700)),
                contentPadding: const EdgeInsets.only(left: 10, right: 10),
                content: Column(
                  spacing: 5,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('It looks like you are not on campus. Please select your starting location'),
                    TypeAheadField<CoordPoint>(
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
                            suffixIcon: IconButton(
                                visualDensity: VisualDensity.adaptivePlatformDensity,
                                onPressed: () {
                                  destLookupTextController.clear();
                                  selectedLocation = null;
                                  setState(() {});
                                },
                                icon: const Icon(Icons.clear))),
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
                        selectedLocation = point.coord;
                        destLookupTextController.text = point.locName;
                        setState(() {});
                      },
                      suggestionsCallback: (String search) {
                        return suggestionsCallback(search);
                      },
                      loadingBuilder: (context) => const Text('Loading...'),
                      errorBuilder: (context, error) => const Text('Error!'),
                      emptyBuilder: (context) => const Text('No rooms found!'),
                      // itemSeparatorBuilder: itemSeparatorBuilder,
                      // listBuilder: settings.gridLayout.value ? gridLayoutBuilder : null,
                    )
                  ],
                ),
                actionsPadding: const EdgeInsets.all(10),
                actions: <Widget>[
                  ElevatedButton(
                      onPressed: selectedLocation != null
                          ? () async {
                              Navigator.pop(context, selectedLocation);
                            }
                          : null,
                      child: const Text('Go!')),
                ]);
          }));
}
