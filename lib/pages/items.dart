class Items {
  String? itemID;
  String? itemName;
  String? itemDescription;
  String? itemImage;
  String? cloudinaryPublicId;
  String? docId;

  Items({
    this.itemID,
    this.itemName,
    this.itemDescription,
    this.itemImage,
    this.cloudinaryPublicId,
    this.docId,
  });

  factory Items.fromJson(Map<String, dynamic> json) {
    return Items(
      itemID: json['itemID'],
      itemName: json['itemName'],
      itemDescription: json['itemDescription'],
      itemImage: json['itemImage'],
      cloudinaryPublicId: json['publicId'] ?? json['cloudinaryPublicId'], // ✅ handles both cases
    );
  }
}
