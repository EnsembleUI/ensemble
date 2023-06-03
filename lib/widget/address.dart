import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Address extends StatefulWidget with Invokable, HasController<AddressController, AddressState> {
  static const type = 'Address';
  Address({super.key});

  final AddressController _controller = AddressController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => AddressState();

  @override
  Map<String, Function> getters() {
    return {
      'value': () => _controller.value
    };
  }

  @override
  Map<String, Function> methods() {
    return {

    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.fromYaml(definition, initiator: this)
    };
  }

}

class AddressController extends WidgetController {
  Place? value;
  EnsembleAction? onChange;
}

class AddressState extends WidgetState<Address> {
  TextEditingController? _textEditingController;
  List<PlaceSummary> _searchResults = [];
  List<Place> _recentSearches = [];


  Future<void> _getSearchResults(String query) async {
    if (query.isNotEmpty) {
      var url =
          'https://services-googleplacesautocomplete-2czdl2akpq-uc.a.run.app?query=$query';
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse['error_message'] != null) {
          throw LanguageError("Error fetching the address list");
        }
        _searchResults = (jsonResponse['predictions'] as List)
            .map((item) => PlaceSummary(
                placeId: item['place_id'],
                address: item['description']))
            .toList();
      } else {
        throw LanguageError('Unable to fetch the address list.');
      }
    } else {
      _searchResults = [];
    }
  }

  Future<Place> _getPlaceDetail(PlaceSummary placeSummary) async {
    var url = 'https://services-googleplacesdetail-2czdl2akpq-uc.a.run.app?placeId=${placeSummary.placeId}';
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      if (jsonResponse['error_message'] == null) {
        return Place(
            placeId: jsonResponse['result']['place_id'] ,
            address: jsonResponse['result']['formatted_address'],
            lat: jsonResponse['result']['geometry']['location']['lat'],
            lng: jsonResponse['result']['geometry']['location']['lng']);
      }
    }
    throw LanguageError("Unable to get the address detail.");
  }



  @override
  Widget buildWidget(BuildContext context) {
    return Autocomplete<PlaceSummary>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            await _getSearchResults(textEditingValue.text);
            return _searchResults;
          },
          displayStringForOption: (address) => address.address,
          onSelected: (selection) => _executeSelection(selection)
        );
        // _textEditingController != null && _textEditingController!.value.text.isNotEmpty
        //     ? IconButton(
        //           onPressed: () => _textEditingController?.clear(),
        //           icon: const Icon(Icons.close))
        //     : const SizedBox.shrink()

  }

  void _executeSelection(PlaceSummary placeSummary) async {
    log('executing selection');
    //fetch detail
    Place place = await _getPlaceDetail(placeSummary);

    // update recent searches
    _recentSearches.insert(0, place);
    if (_recentSearches.length > 5) {
      _recentSearches.removeLast();
    }

    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget, data: place.toMap()));
    }

  }

}


class PlaceSummary {
  PlaceSummary({required this.placeId, required this.address});
  String placeId;
  String address;
}

class Place extends PlaceSummary {
  Place({
    required super.placeId,
    required super.address,
    required this.lat,
    required this.lng
  });
  double lat;
  double lng;

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'address': address
    };
  }
}