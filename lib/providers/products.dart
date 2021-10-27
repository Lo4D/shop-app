import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/http_exception.dart';
import 'product.dart';

class Products with ChangeNotifier {
  List<Product> _items = [];

  // var _showFavoritesOnly = false;

  final String authToken;
  final String userId;

  Products({
    @required this.authToken,
    @required this.userId,
    List<Product> items,
  }) : _items = items;

  List<Product> get items {
    // if (_showFavoritesOnly) {
    //   _items.where((product) => product.isFavorite).toList();
    // }
    return [..._items];
  }

  List<Product> get favItems {
    return _items.where((product) => product.isFavorite).toList();
  }

  Product findById(String id) {
    return _items.firstWhere((product) => product.id == id);
  }

  Future<void> getProducts([bool filterByUser = false]) async {
    final filterString =
        filterByUser ? '&orderBy="ownerId"&equalTo="$userId"' : '';
    try {
      final response = await http.get(Uri.parse(
          '${dotenv.env['API']}/products.json?auth=$authToken$filterString'));
      final decodedJson = json.decode(response.body) as Map<String, dynamic>;
      if (decodedJson == null) return;
      final favoritesResponse = await http.get(Uri.parse(
          '${dotenv.env['API']}/userFavorites/$userId.json?auth=$authToken'));
      final favoriteData = json.decode(favoritesResponse.body);
      final List<Product> loadedProducts = [];
      decodedJson.forEach((prodId, prodData) {
        loadedProducts.add(Product(
          id: prodId,
          title: prodData['title'],
          description: prodData['description'],
          imageUrl: prodData['imageUrl'],
          price: prodData['price'],
          isFavorite:
              favoriteData == null ? false : favoriteData[prodId] ?? false,
        ));
      });
      _items = loadedProducts;
      notifyListeners();
    } catch (error) {
      print(error);
      throw (error);
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API']}/products.json?auth=$authToken'),
        body: json.encode({
          'title': product.title,
          'description': product.description,
          'imageUrl': product.imageUrl,
          'price': product.price,
          'ownerId': userId,
        }),
      );
      final newProduct = Product(
        title: product.title,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
        id: json.decode(response.body)['name'],
      );
      _items.add(newProduct);
      // _items.insert(0, newProduct); // at the start of the list
      notifyListeners();
    } catch (error) {
      print(error);
      throw error;
    }
  }

  Future<void> updateProduct(String id, Product newProduct) async {
    final prodIndex = _items.indexWhere((prod) => prod.id == id);
    if (prodIndex >= 0) {
      await http.patch(
          Uri.parse('${dotenv.env['API']}/products/$id.json?auth=$authToken'),
          body: json.encode({
            'title': newProduct.title,
            'description': newProduct.description,
            'imageUrl': newProduct.imageUrl,
            'price': newProduct.price,
          }));
      _items[prodIndex] = newProduct;
      notifyListeners();
    } else {
      print('No existing product');
    }
  }

  Future<void> deleteProduct(String id) async {
    // Creating shadow copy of the product
    final existingProductIndex = _items.indexWhere((prod) => prod.id == id);
    var existingProduct = _items[existingProductIndex];

    // Deleting the product from the products list
    _items.removeAt(existingProductIndex);
    notifyListeners();

    // Requesting delete from the server db
    final response = await http.delete(
        Uri.parse('${dotenv.env['API']}/products/$id.json?auth=$authToken'));
    if (response.statusCode >= 400) {
      // If server throw delete error restore product from shadow copy
      _items.insert(existingProductIndex, existingProduct);
      notifyListeners();
      throw HttpException('Could not delete product remotely.');
    }
    // If deleting was successful get rid of shadow copy
    existingProduct = null;
    // _items.removeWhere((prod) => prod.id == id); old deletion
  }

// void showFavoritesOnly() {
//   _showFavoritesOnly = true;
//   notifyListeners();
// }
//
// void showAll() {
//   _showFavoritesOnly = false;
//   notifyListeners();
// }
}
