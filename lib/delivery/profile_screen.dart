import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryProfileScreen extends StatefulWidget {
  final String email;

  DeliveryProfileScreen({required this.email});

  @override
  _DeliveryProfileScreenState createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    DocumentSnapshot doc =
        await _firestore.collection('delivery_guys').doc(widget.email).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _nameController.text = data['name'] ?? 'Delivery Guy';
        _isOnline = data['isOnline'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 20),
        CircleAvatar(
          radius: 50,
          backgroundImage: AssetImage(
            'assets/delivery_profile.png',
          ), // Programmatic
        ),
        SizedBox(height: 20),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Name'),
          onChanged: (value) async {
            await _firestore
                .collection('delivery_guys')
                .doc(widget.email)
                .update({'name': value});
          },
        ),
        SizedBox(height: 20),
        ListTile(
          leading: Icon(Icons.power_settings_new),
          title: Text('Online/Offline'),
          trailing: Switch(
            value: _isOnline,
            onChanged: (value) async {
              setState(() => _isOnline = value);
              await _firestore
                  .collection('delivery_guys')
                  .doc(widget.email)
                  .update({'isOnline': value});
            },
            activeColor: Colors.green,
          ),
        ),
        ListTile(
          leading: Icon(Icons.support),
          title: Text('Contact Support'),
          onTap: () {
            // Implement support logic
          },
        ),
        ListTile(
          leading: Icon(Icons.logout),
          title: Text('Logout'),
          onTap: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ],
    );
  }
}
