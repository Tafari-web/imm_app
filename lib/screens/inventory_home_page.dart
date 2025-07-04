import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class InventoryHomePage extends StatefulWidget {
  const InventoryHomePage({super.key});

  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  final _fire = FirebaseFirestore.instance;
  late final String _uid;

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  final List<String> _cats = ['Electronics', 'Office', 'Grocery'];
  String _filterCat = 'All'; // Default filter
  String _entryCat = 'Electronics';

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _itemsRef =>
      _fire.collection('users').doc(_uid).collection('items');

  Stream<QuerySnapshot<Map<String, dynamic>>> _itemStream() {
    Query<Map<String, dynamic>> q = _itemsRef;
    if (_filterCat != 'All') {
      q = q.where('category', isEqualTo: _filterCat);
    }
    return q.orderBy('updatedAt', descending: true).snapshots();
  }

  Future<void> _addOrUpdateItem({String? id}) async {
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (name.isEmpty || qty == null || qty <= 0) return;

    await _itemsRef.doc(id).set({
      'name': name,
      'quantity': qty,
      'category': _entryCat,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _nameCtrl.clear();
    _qtyCtrl.clear();

    // After adding item, auto-switch to show items from its category
    setState(() {
      _filterCat = _entryCat;
    });
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _itemsRef.doc(id).delete();
  }

  Future<void> _editItem(String id, Map<String, dynamic> data) async {
    _nameCtrl.text = data['name'];
    _qtyCtrl.text = data['quantity'].toString();
    String editCat = data['category'];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: editCat,
              isExpanded: true,
              items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => editCat = v!),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              _entryCat = editCat;
              await _addOrUpdateItem(id: id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Manager'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add Item Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Item Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Category:'),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _entryCat,
                      items: _cats
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _entryCat = v!),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: _addOrUpdateItem,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Filter:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterCat,
                  items: ['All', ..._cats].map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _filterCat = v!),
                ),
              ],
            ),
          ),

          // Item List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _itemStream(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('No inventory items yet.'));
                }

                return ListView.builder(
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (_, idx) {
                    final doc = snap.data!.docs[idx];
                    final data = doc.data();

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.teal),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(data['name']),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.teal),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Qty: ${data['quantity']}'),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Category: ${data['category']}'),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editItem(doc.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(doc.id),
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
      ),
    );
  }
}
