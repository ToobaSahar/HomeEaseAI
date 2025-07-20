/*import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appliance_model.dart';

class FirestoreHelper {
  static Future<List<ApplianceUsage>> getUserAppliances() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc('USER_ID').get();
    final data = snapshot.data();
    if (data == null || data['appliances'] == null) return [];

    List appliances = data['appliances'];
    return appliances.map((a) => ApplianceUsage(name: a)).toList();
  }
}*/