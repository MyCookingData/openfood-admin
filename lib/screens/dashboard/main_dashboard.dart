import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'tabs/live_orders_tab.dart';
import 'tabs/statistics_tab.dart';
import 'tabs/restaurants/restaurants_list_tab.dart';
import 'tabs/logistics_tab.dart';
import 'tabs/users_management_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/promo_codes_tab.dart';
import 'tabs/carousel_tab.dart';
import 'tabs/categories_tab.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;

  List<Widget> get _pages => const [
    LiveOrdersTab(),
    StatisticsTab(),
    RestaurantsListTab(),
    InventoryTab(),
    LogisticsTab(),
    UsersManagementTab(),
    PromoCodesTab(),
    CarouselTab(),
    CategoriesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: NavigationRail(
              backgroundColor: AppTheme.darkBackground,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Icon(
                  Icons.restaurant_menu,
                  color: AppTheme.emeraldGreen,
                  size: 40,
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('Commandes Live'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Statistiques'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storefront),
                  selectedIcon: Icon(Icons.storefront),
                  label: Text('Restaurants'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Inventaire'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_outlined),
                  label: Text('Logistique'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Utilisateurs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_offer),
                  selectedIcon: Icon(Icons.local_offer),
                  label: Text('Codes Promo'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.view_carousel),
                  selectedIcon: Icon(Icons.view_carousel),
                  label: Text('Bannières Accueil'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.category),
                  selectedIcon: Icon(Icons.category),
                  label: Text('Catégories'),
                ),
              ],
              trailing: Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  tooltip: 'Se déconnecter',
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.darkBackground, AppTheme.lighterDarkBackground],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              ),
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

