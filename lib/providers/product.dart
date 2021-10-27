import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class Product with ChangeNotifier {
  final String id;
  final String title;
  final String description;
  final double price;
  final String imageUrl;
  bool isFavorite;

  Product({
    @required this.id,
    @required this.title,
    @required this.description,
    @required this.price,
    @required this.imageUrl,
    this.isFavorite = false,
  });

  void _setFavValue(bool newValue) {
    isFavorite = newValue;
    notifyListeners();
  }

  Future<void> toggleFavorite(String authToken, String userId) async {
    final oldStatus = isFavorite;
    isFavorite = !isFavorite;
    notifyListeners();
    try {
      final response = await http.put(
          Uri.parse(
              '${dotenv.env['API']}/userFavorites/$userId/$id.json?auth=$authToken'),
          body: json.encode(
            isFavorite,
          ));
      if (response.statusCode >= 400) {
        print('Server error: ${response.statusCode}');
        _setFavValue(oldStatus);
      }
    } catch (error) {
      print(error);
      _setFavValue(oldStatus);
    }
  }
}
