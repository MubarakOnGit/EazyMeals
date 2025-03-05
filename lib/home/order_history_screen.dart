import 'package:flutter/material.dart';

class OrderHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order History')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Add order history items here
        ],
      ),
    );
  }
}
