import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryGuysScreen extends StatefulWidget {
  @override
  _DeliveryGuysScreenState createState() => _DeliveryGuysScreenState();
}

class _DeliveryGuysScreenState extends State<DeliveryGuysScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _showVerified = true;
  bool _showUnverified = true;
  bool _showAssigned = true;
  bool _showUnassigned = true;
  List<String> _selectedFilterCategories = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Delivery Guys',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 10),
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter Delivery Guys',
            ),
          ],
        ),
        SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('delivery_guys').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              final deliveryGuys =
                  snapshot.data!.docs.where(_applyFilters).toList();
              if (deliveryGuys.isEmpty) {
                return Center(
                  child: Text('No delivery guys match the filters'),
                );
              }
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
                  final assignedUsers = List<String>.from(
                    data['assignedUsers'] ?? [],
                  );
                  final locationCategories = List<String>.from(
                    data['locationCategories'] ?? [],
                  );

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
                          Text('Assigned Users: ${assignedUsers.length}'),
                          Text(
                            'Location Categories: ${locationCategories.isEmpty ? 'None' : locationCategories.join(', ')}',
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
                            onPressed:
                                () =>
                                    assignedUsers.isEmpty
                                        ? _assignOrders(context, guy.id)
                                        : _editAssignment(
                                          context,
                                          guy.id,
                                          assignedUsers,
                                          locationCategories,
                                        ),
                            child: Text(
                              assignedUsers.isEmpty
                                  ? 'Assign Orders'
                                  : 'Edit Assignment',
                            ),
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

  bool _applyFilters(DocumentSnapshot guy) {
    final data = guy.data() as Map<String, dynamic>;
    final isVerified = data['verified'] ?? false;
    final lastVerified =
        data['lastVerified'] != null
            ? (data['lastVerified'] as Timestamp).toDate()
            : null;
    final now = DateTime.now();
    final isValid =
        lastVerified != null && now.difference(lastVerified).inHours < 12;
    final assignedUsers = List<String>.from(data['assignedUsers'] ?? []);
    final locationCategories = List<String>.from(
      data['locationCategories'] ?? [],
    );

    // Verification filter
    if (!_showVerified && isVerified && isValid) return false;
    if (!_showUnverified && (!isVerified || !isValid)) return false;

    // Assignment filter
    if (!_showAssigned && assignedUsers.isNotEmpty) return false;
    if (!_showUnassigned && assignedUsers.isEmpty) return false;

    // Location category filter
    if (_selectedFilterCategories.isNotEmpty &&
        !locationCategories.any(
          (cat) => _selectedFilterCategories.contains(cat),
        )) {
      return false;
    }

    return true;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Filter Delivery Guys'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        CheckboxListTile(
                          title: Text('Verified'),
                          value: _showVerified,
                          onChanged:
                              (value) => setState(() => _showVerified = value!),
                        ),
                        CheckboxListTile(
                          title: Text('Unverified'),
                          value: _showUnverified,
                          onChanged:
                              (value) =>
                                  setState(() => _showUnverified = value!),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Assignment Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        CheckboxListTile(
                          title: Text('Assigned'),
                          value: _showAssigned,
                          onChanged:
                              (value) => setState(() => _showAssigned = value!),
                        ),
                        CheckboxListTile(
                          title: Text('Unassigned'),
                          value: _showUnassigned,
                          onChanged:
                              (value) =>
                                  setState(() => _showUnassigned = value!),
                        ),
                        SizedBox(height: 10),
                        _buildCategorySelector(
                          setState,
                          _selectedFilterCategories,
                          isFilter: true,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Trigger rebuild with new filters
                        Navigator.pop(context);
                      },
                      child: Text('Apply'),
                    ),
                  ],
                ),
          ),
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
    List<String> selectedCategories = [];
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
                  content: SingleChildScrollView(
                    child: Column(
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
                        _buildCategorySelector(setState, selectedCategories),
                        SizedBox(height: 10),
                        if (numberOfUsers != null && numberOfUsers! > 0)
                          Container(
                            height: 200,
                            width: double.maxFinite,
                            child: ListView(
                              children:
                                  subscribedUsers.docs
                                      .where((userDoc) {
                                        final userData =
                                            userDoc.data()
                                                as Map<String, dynamic>;
                                        final userCategory =
                                            userData['locationCategory']
                                                as String?;
                                        return selectedCategories.isEmpty ||
                                            (userCategory != null &&
                                                selectedCategories.contains(
                                                  userCategory,
                                                ));
                                      })
                                      .map((userDoc) {
                                        final userData =
                                            userDoc.data()
                                                as Map<String, dynamic>;
                                        return CheckboxListTile(
                                          title: Text(
                                            userData['name'] ?? 'Unknown',
                                          ),
                                          subtitle: Text(
                                            '${userData['email'] ?? 'N/A'} - ${userData['locationCategory'] ?? 'No Category'}',
                                          ),
                                          value: selectedUsers.contains(
                                            userDoc.id,
                                          ),
                                          onChanged: (bool? value) {
                                            setState(() {
                                              if (value == true &&
                                                  selectedUsers.length <
                                                      numberOfUsers!) {
                                                selectedUsers.add(userDoc.id);
                                              } else if (value == false) {
                                                selectedUsers.remove(
                                                  userDoc.id,
                                                );
                                              }
                                            });
                                          },
                                        );
                                      })
                                      .toList(),
                            ),
                          ),
                      ],
                    ),
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
                                    .update({
                                      'assignedUsers': selectedUsers,
                                      'locationCategories': selectedCategories,
                                    });
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

  void _editAssignment(
    BuildContext context,
    String deliveryId,
    List<String> currentUsers,
    List<String> currentCategories,
  ) async {
    int? numberOfUsers = currentUsers.length;
    List<String> selectedUsers = List.from(currentUsers);
    List<String> selectedCategories = List.from(currentCategories);
    QuerySnapshot subscribedUsers =
        await _firestore
            .collection('users')
            .where('activeSubscription', isEqualTo: true)
            .get();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Edit Assignment'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          initialValue: numberOfUsers.toString(),
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
                        _buildCategoryEditor(setState, selectedCategories),
                        SizedBox(height: 10),
                        if (numberOfUsers != null && numberOfUsers! > 0)
                          Container(
                            height: 200,
                            width: double.maxFinite,
                            child: ListView(
                              children:
                                  subscribedUsers.docs
                                      .where((userDoc) {
                                        final userData =
                                            userDoc.data()
                                                as Map<String, dynamic>;
                                        final userCategory =
                                            userData['locationCategory']
                                                as String?;
                                        return selectedCategories.isEmpty ||
                                            (userCategory != null &&
                                                selectedCategories.contains(
                                                  userCategory,
                                                ));
                                      })
                                      .map((userDoc) {
                                        final userData =
                                            userDoc.data()
                                                as Map<String, dynamic>;
                                        return CheckboxListTile(
                                          title: Text(
                                            userData['name'] ?? 'Unknown',
                                          ),
                                          subtitle: Text(
                                            '${userData['email'] ?? 'N/A'} - ${userData['locationCategory'] ?? 'No Category'}',
                                          ),
                                          value: selectedUsers.contains(
                                            userDoc.id,
                                          ),
                                          onChanged: (bool? value) {
                                            setState(() {
                                              if (value == true &&
                                                  selectedUsers.length <
                                                      numberOfUsers!) {
                                                selectedUsers.add(userDoc.id);
                                              } else if (value == false) {
                                                selectedUsers.remove(
                                                  userDoc.id,
                                                );
                                              }
                                            });
                                          },
                                        );
                                      })
                                      .toList(),
                            ),
                          ),
                      ],
                    ),
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
                                    .update({
                                      'assignedUsers': selectedUsers,
                                      'locationCategories': selectedCategories,
                                    });
                                Navigator.pop(context);
                              }
                              : null,
                      child: Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildCategorySelector(
    void Function(void Function()) setState,
    List<String> selectedCategories, {
    bool isFilter = false,
  }) {
    final availableCategories = ['North', 'South', 'East', 'West', 'Central'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8.0,
          children:
              availableCategories.map((category) {
                return FilterChip(
                  label: Text(category),
                  selected: selectedCategories.contains(category),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        selectedCategories.add(category);
                      } else {
                        selectedCategories.remove(category);
                      }
                    });
                  },
                );
              }).toList(),
        ),
        if (isFilter && selectedCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton(
              onPressed: () => setState(() => selectedCategories.clear()),
              child: Text('Clear Categories'),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryEditor(
    void Function(void Function()) setState,
    List<String> selectedCategories,
  ) {
    final availableCategories = ['North', 'South', 'East', 'West', 'Central'];
    TextEditingController categoryController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: categoryController,
                decoration: InputDecoration(labelText: 'Add New Category'),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                final newCategory = categoryController.text.trim();
                if (newCategory.isNotEmpty &&
                    !selectedCategories.contains(newCategory)) {
                  setState(() {
                    selectedCategories.add(newCategory);
                    categoryController.clear();
                  });
                }
              },
            ),
          ],
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          children:
              selectedCategories.map((category) {
                return Chip(
                  label: Text(category),
                  deleteIcon: Icon(Icons.remove_circle),
                  onDeleted: () {
                    setState(() {
                      selectedCategories.remove(category);
                    });
                  },
                );
              }).toList(),
        ),
        SizedBox(height: 10),
        Text(
          'Suggested Categories:',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        Wrap(
          spacing: 8.0,
          children:
              availableCategories
                  .where((cat) => !selectedCategories.contains(cat))
                  .map((category) {
                    return ActionChip(
                      label: Text(category),
                      onPressed: () {
                        setState(() {
                          selectedCategories.add(category);
                        });
                      },
                    );
                  })
                  .toList(),
        ),
      ],
    );
  }
}
