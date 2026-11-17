import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../../theme/app_theme.dart';
import 'tabs/resto_info_tab.dart';
import 'tabs/resto_menu_tab.dart';
import 'tabs/resto_inventory_tab.dart';

class RestaurantDetailsPage extends StatelessWidget {
  final RestaurantModel restaurant;
  
  const RestaurantDetailsPage({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('restaurants').doc(restaurant.id).snapshots(),
      builder: (context, snapshot) {
        RestaurantModel currentResto = restaurant;
        if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
          final data = Map<String, dynamic>.from(snapshot.data!.data() as Map);
          data['id'] = snapshot.data!.id;
          currentResto = RestaurantModel.fromJson(data);
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: AppTheme.darkBackground,
            appBar: AppBar(
              backgroundColor: AppTheme.darkBackground,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                currentResto.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              bottom: const TabBar(
                indicatorColor: AppTheme.emeraldGreen,
                labelColor: AppTheme.emeraldGreen,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(icon: Icon(Icons.info), text: 'Informations'),
                  Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu & Plats'),
                  Tab(icon: Icon(Icons.inventory), text: 'Inventaire (Stock)'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                RestoInfoTab(restaurant: currentResto),
                RestoMenuTab(restaurant: currentResto),
                RestoInventoryTab(restaurant: currentResto),
              ],
            ),
          ),
        );
      },
    );
  }
}
