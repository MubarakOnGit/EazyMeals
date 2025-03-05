import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryGuysScreen extends StatefulWidget {
  @override
  _DeliveryGuysScreenState createState() => _DeliveryGuysScreenState();
}

class _DeliveryGuysScreenState extends State<DeliveryGuysScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: Text(
            'Delivery Guys',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('delivery_guys').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              final deliveryGuys = snapshot.data!.docs;
              return ListView.builder(
                itemCount: deliveryGuys.length,
                itemBuilder: (context, index) {
                  final guy = deliveryGuys[index];
                  final data = guy.data() as Map<String, dynamic>;
                  final isVerified = data['verified'] ?? false;
                  final lastVerified =
                      data['lastVerified'] != null
                          ? (data['lastVerified'] as Timestamp).toDate()
                          : null;
                  final now = DateTime.now();
                  final isValid =
                      lastVerified != null &&
                      now.difference(lastVerified).inHours < 12;

                  return Card(
                    child: ListTile(
                      title: Text(data['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: ${data['email'] ?? 'N/A'}'),
                          Text(
                            'Status: ${isVerified && isValid ? 'Verified' : 'Pending'}',
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isVerified || !isValid)
                            ElevatedButton(
                              onPressed: () => _verifyDeliveryGuy(guy.id),
                              child: Text('Verify'),
                            ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _assignOrders(context, guy.id),
                            child: Text('Assign Orders'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _verifyDeliveryGuy(String deliveryId) async {
    await _firestore.collection('delivery_guys').doc(deliveryId).update({
      'verified': true,
      'lastVerified': Timestamp.fromDate(DateTime.now()),
    });
  }

  void _assignOrders(BuildContext context, String deliveryId) async {
    int? numberOfUsers;
    List<String> selectedUsers = [];
    QuerySnapshot subscribedUsers =
        await _firestore
            .collection('users')
            .where('activeSubscription', isEqualTo: true)
            .get();

    if (subscribedUsers.docs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No subscribed users available')));
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Assign Orders'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Number of Users',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          numberOfUsers = int.tryParse(value);
                          setState(() {});
                        },
                      ),
                      SizedBox(height: 10),
                      if (numberOfUsers != null && numberOfUsers! > 0)
                        Container(
                          height: 200,
                          width: double.maxFinite,
                          child: ListView(
                            children:
                                subscribedUsers.docs.map((userDoc) {
                                  final userData =
                                      userDoc.data() as Map<String, dynamic>;
                                  return CheckboxListTile(
                                    title: Text(userData['name'] ?? 'Unknown'),
                                    subtitle: Text(userData['email'] ?? 'N/A'),
                                    value: selectedUsers.contains(userDoc.id),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true &&
                                            selectedUsers.length <
                                                numberOfUsers!) {
                                          selectedUsers.add(userDoc.id);
                                        } else if (value == false) {
                                          selectedUsers.remove(userDoc.id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          selectedUsers.length == numberOfUsers
                              ? () async {
                                await _firestore
                                    .collection('delivery_guys')
                                    .doc(deliveryId)
                                    .update({'assignedUsers': selectedUsers});
                                Navigator.pop(context);
                              }
                              : null,
                      child: Text('Assign'),
                    ),
                  ],
                ),
          ),
    );
  }
}
