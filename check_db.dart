import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:openfood_admin/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print("--- RESTAURANTS ---");
  final rSnap = await FirebaseFirestore.instance.collection('restaurants').limit(2).get();
  for (var d in rSnap.docs) {
    print("${d.id}: ${d.data()['name']}");
  }

  print("--- PRODUCTS ---");
  final pSnap = await FirebaseFirestore.instance.collection('products').limit(3).get();
  for (var d in pSnap.docs) {
    print("${d.id}: ${d.data()['name']} - restaurantId: ${d.data()['restaurantId']}");
  }
}
