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
import 'tabs/photo_library_tab.dart';

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
    PhotoLibraryTab(),
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
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emeraldGreen.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo_openfood_transparent.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_menu, color: AppTheme.emeraldGreen, size: 28),
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long),
                  selectedIcon: Icon(Icons.receipt_long, color: AppTheme.emeraldGreen),
                  label: Text('Commandes Live'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart),
                  selectedIcon: Icon(Icons.bar_chart, color: AppTheme.emeraldGreen),
                  label: Text('Statistiques'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storefront),
                  selectedIcon: Icon(Icons.storefront, color: AppTheme.emeraldGreen),
                  label: Text('Restaurants'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2),
                  selectedIcon: Icon(Icons.inventory_2, color: AppTheme.emeraldGreen),
                  label: Text('Inventaire'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_outlined, color: AppTheme.emeraldGreen),
                  label: Text('Logistique'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people),
                  selectedIcon: Icon(Icons.people, color: AppTheme.emeraldGreen),
                  label: Text('Utilisateurs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_offer),
                  selectedIcon: Icon(Icons.local_offer, color: AppTheme.emeraldGreen),
                  label: Text('Codes Promo'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.view_carousel),
                  selectedIcon: Icon(Icons.view_carousel, color: AppTheme.emeraldGreen),
                  label: Text('Bannières Accueil'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.category),
                  selectedIcon: Icon(Icons.category, color: AppTheme.emeraldGreen),
                  label: Text('Catégories'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.photo_library),
                  selectedIcon: Icon(Icons.photo_library, color: AppTheme.emeraldGreen),
                  label: Text('Bibliothèque Photo'),
                ),
              ],
              trailing: Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Conçu & Développé par Cooking Data • Solutions Informatiques & IA (cookingdata.fr)',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.verified_outlined, color: AppTheme.emeraldGreen, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    IconButton(
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
                  ],
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

