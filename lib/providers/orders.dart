import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shop_app/models/http_exception.dart';

import './cart.dart';

class Order {
  final String id;
  final double amount;
  final List<CartItem> products;
  final DateTime dateTime;

  Order({
    @required this.id,
    @required this.amount,
    @required this.dateTime,
    @required this.products,
  });
}

class Orders with ChangeNotifier {
  List<Order> _orders = [];
  final String authToken;
  final String userId;

  Orders({
    @required this.authToken,
    @required this.userId,
    List<Order> orders,
  }) : _orders = orders;

  List<Order> get orders {
    return [..._orders];
  }

  Future<void> getOrders() async {
    final response = await http.get(
        Uri.parse('${dotenv.env['API']}/orders/$userId.json?auth=$authToken'));
    final List<Order> loadedOrders = [];
    final decodedJson = json.decode(response.body) as Map<String, dynamic>;
    if (decodedJson == null) return;
    decodedJson.forEach((orderId, orderData) {
      loadedOrders.add(
        Order(
          id: orderId,
          amount: orderData['amount'],
          dateTime: DateTime.parse(orderData['dateTime']),
          products: (orderData['products'] as List<dynamic>)
              .map((item) => CartItem(
                    id: item['id'],
                    price: item['price'],
                    qty: item['qty'],
                    title: item['title'],
                  ))
              .toList(),
        ),
      );
    });
    _orders = loadedOrders.reversed.toList();
    notifyListeners();
  }

  Future<void> addOrder(List<CartItem> cartProducts, double total) async {
    final timestamp = DateTime.now();
    try {
      final response = await http.post(
          Uri.parse('${dotenv.env['API']}/orders/$userId.json?auth=$authToken'),
          body: json.encode({
            'amount': total,
            'dateTime': timestamp.toIso8601String(),
            'products': cartProducts
                .map((cp) => {
                      'id': cp.id,
                      'title': cp.title,
                      'qty': cp.qty,
                      'price': cp.price,
                    })
                .toList(),
          }));
      _orders.insert(
          0,
          Order(
            id: json.decode(response.body)['name'],
            amount: total,
            dateTime: timestamp,
            products: cartProducts,
          ));
      if (response.statusCode >= 400) {
        throw HttpException(
            '${response.statusCode} - ${json.decode(response.body)['error']}');
      }
      notifyListeners();
    } catch (error) {
      print(error);
      throw error;
    }
  }
}
