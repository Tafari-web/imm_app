class InventoryItem {
  final String id;
  final String name;
  final int quantity;
  final String category;

  InventoryItem({required this.id, required this.name, required this.quantity, required this.category});

  factory InventoryItem.fromFirestore(String id, Map<String, dynamic> data) {
    return InventoryItem(
      id: id,
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? 0,
      category: data['category'] ?? 'Uncategorized',
    );
  }
}
