import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class Address extends StatefulWidget
    with Invokable, HasController<AddressController, AddressState> {
  static const type = 'Address';
  Address({super.key});

  final AddressController _controller = AddressController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => AddressState();

  @override
  Map<String, Function> getters() {
    return {'value': () => _controller.value};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'showRecent': (value) => _controller.showRecent =
          Utils.getBool(value, fallback: _controller.showRecent),
      'countryFilter': (value) =>
          _controller.countryFilter = Utils.getListOfStrings(value),
      'proximitySearchEnabled': (value) => _controller._proximitySearchEnabled =
          Utils.getBool(value, fallback: _controller._proximitySearchEnabled),
      'proximitySearchCenter': (value) =>
          _controller.proximitySearchCenter = Utils.getLatLng(value),
      'proximitySearchRadius': (value) =>
          _controller.proximitySearchRadius = Utils.optionalInt(value),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.fromYaml(definition, initiator: this)
    };
  }
}

class AddressController extends WidgetController with LocationCapability {
  Place? value;
  EnsembleAction? onChange;

  bool showRecent = true;

  List<String>? _countryFilter;
  set countryFilter(List<String>? items) {
    if (items != null && items.length > 5) {
      throw LanguageError(
          "${Address.type}'s countryFilter can only have up to 5 country codes.");
    }
    _countryFilter = items;
  }

  int? proximitySearchRadius;
  LatLng? proximitySearchCenter;

  bool _proximitySearchEnabled = true;
  set proximitySearchEnabled(bool value) {
    _proximitySearchEnabled = value;
    if (value) {
      // async. Just trigger the permission request. Don't care about the result yet.
      GetIt.I<LocationManager>().getLocationStatus();
    }
  }
}

class AddressState extends WidgetState<Address> {
  TextEditingController? _textEditingController;
  FocusNode? _focusNode;
  List<Place> _recentSearches = [];

  Future<List<PlaceSummary>> _getSearchResults(String query) async {
    if (query.isNotEmpty) {
      // location bias
      LatLng? center = widget._controller.proximitySearchCenter;
      if (center == null &&
          widget._controller._proximitySearchEnabled &&
          widget._controller.getLastLocation() != null) {
        center = LatLng(widget._controller.getLastLocation()!.latitude,
            widget._controller.getLastLocation()!.longitude);
      }
      String locationBiasStr = '';
      if (center != null) {
        locationBiasStr =
            '&locationbias=circle:${widget._controller.proximitySearchRadius ?? 20000}@${center.latitude},${center.longitude}';
      }

      // filter by country
      String countryFilterStr = '';
      if (widget._controller._countryFilter?.isNotEmpty ?? false) {
        countryFilterStr =
            '&components=${widget._controller._countryFilter!.map((e) => 'country:$e').join('|')}';
      }

      var url =
          'https://services-googleplacesautocomplete-2czdl2akpq-uc.a.run.app?input=$query$locationBiasStr$countryFilterStr';
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse['error_message'] != null) {
          throw LanguageError("Error fetching the address list");
        }
        return (jsonResponse['predictions'] as List)
            .map((item) => PlaceSummary(
                placeId: item['place_id'], address: item['description']))
            .toList();
      } else {
        throw LanguageError('Unable to fetch the address list.');
      }
    } else {
      return widget._controller.showRecent ? _recentSearches : [];
    }
  }

  Future<Place> _getPlaceDetail(PlaceSummary placeSummary) async {
    var url =
        'https://services-googleplacesdetail-2czdl2akpq-uc.a.run.app?placeId=${placeSummary.placeId}';
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      if (jsonResponse['error_message'] == null) {
        return Place(
            placeId: jsonResponse['result']['place_id'],
            address: jsonResponse['result']['formatted_address'],
            lat: jsonResponse['result']['geometry']['location']['lat'],
            lng: jsonResponse['result']['geometry']['location']['lng'],
            types: (jsonResponse['result']['types'] as List<dynamic>)
                .cast<String>(),
            bounds: jsonResponse['result']['geometry']['viewport']);
      }
    }
    throw LanguageError("Unable to get the address detail.");
  }

  @override
  Widget buildWidget(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Autocomplete<PlaceSummary>(
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
            _textEditingController = textEditingController;
            _focusNode = focusNode;
            return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                onFieldSubmitted: (String value) {
                  onFieldSubmitted();
                },
                decoration: widget._controller.value != null
                    ? InputDecoration(
                        suffixIcon: IconButton(
                            onPressed: _clearSelection,
                            icon: const Icon(Icons.close)))
                    : null);
          },
          optionsBuilder: (TextEditingValue textEditingValue) {
            return _getSearchResults(textEditingValue.text);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return CustomAutoCompleteOptions(
                key: UniqueKey(),
                displayStringForOption: _displayStringForOption,
                onSelected: onSelected,
                options: options,
                maxOptionsWidth: constraints.maxWidth,
                maxOptionsHeight: 250);
          },
          displayStringForOption: _displayStringForOption,
          onSelected: (selection) => _executeSelection(selection));
    });
  }

  String _displayStringForOption(PlaceSummary placeSummary) =>
      placeSummary.address;

  void _executeSelection(PlaceSummary placeSummary) async {
    Place place = await _getPlaceDetail(placeSummary);
    widget._controller.value = place;

    // update recent searches
    _recentSearches
        .removeWhere((element) => element.placeId == placeSummary.placeId);
    _recentSearches.insert(0, place);
    if (_recentSearches.length > 5) {
      _recentSearches.removeLast();
    }

    setState(() {});

    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget, data: place.toMap()));
    }
  }

  void _clearSelection() {
    setState(() {
      widget._controller.value = null;
      _textEditingController?.clear();
    });
    _focusNode?.requestFocus();
  }
}

class PlaceSummary {
  PlaceSummary({required this.placeId, required this.address});
  String placeId;
  String address;
}

class Place extends PlaceSummary {
  Place(
      {required super.placeId,
      required super.address,
      required this.lat,
      required this.lng,
      this.types,
      this.bounds});
  double lat;
  double lng;
  List<String>? types;
  dynamic bounds;

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'address': address,
      'types': types,
      'bounds': bounds
    };
  }
}

// taken from Flutter code and modified
class CustomAutoCompleteOptions<T extends Object> extends StatelessWidget {
  const CustomAutoCompleteOptions({
    super.key,
    required this.displayStringForOption,
    required this.onSelected,
    required this.options,
    required this.maxOptionsWidth,
    required this.maxOptionsHeight,
  });

  final AutocompleteOptionToString<T> displayStringForOption;

  final AutocompleteOnSelected<T> onSelected;

  final Iterable<T> options;
  final double maxOptionsWidth;
  final double maxOptionsHeight;

  @override
  Widget build(BuildContext context) {
    // check if this is Recent result or actual Search Result
    bool isRecent = false;
    if (options.isNotEmpty && options.first is Place) {
      isRecent = true;
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: maxOptionsHeight, maxWidth: maxOptionsWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isRecent
                    ? const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        child: const Row(children: [
                          Icon(Icons.access_time,
                              size: 16, color: Colors.black54),
                          SizedBox(width: 3),
                          Text('RECENT',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54))
                        ]))
                    : const SizedBox.shrink(),
                Expanded(
                    child: ListView.builder(
                  padding: isRecent
                      ? EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                      : EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final T option = options.elementAt(index);
                    return InkWell(
                      onTap: () {
                        onSelected(option);
                      },
                      child: Builder(builder: (BuildContext context) {
                        final bool highlight =
                            AutocompleteHighlightedOption.of(context) == index;
                        if (highlight) {
                          SchedulerBinding.instance
                              .addPostFrameCallback((Duration timeStamp) {
                            Scrollable.ensureVisible(context, alignment: 0.5);
                          });
                        }
                        return Container(
                            color:
                                highlight ? Theme.of(context).focusColor : null,
                            padding: const EdgeInsets.all(16.0),
                            child: Text(displayStringForOption(option),
                                maxLines: isRecent ? 1 : null));
                      }),
                    );
                  },
                ))
              ],
            )),
      ),
    );
  }
}
