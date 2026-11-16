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

  final List<Widget> _pages = const [
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

  static const List<_NavItem> _navItems = [
    _NavItem(Icons.receipt_long, 'Commandes Live'),
    _NavItem(Icons.bar_chart, 'Statistiques'),
    _NavItem(Icons.storefront, 'Restaurants'),
    _NavItem(Icons.inventory_2, 'Inventaire'),
    _NavItem(Icons.map_outlined, 'Logistique'),
    _NavItem(Icons.people, 'Utilisateurs'),
    _NavItem(Icons.local_offer, 'Codes Promo'),
    _NavItem(Icons.view_carousel, 'Bannières Accueil'),
    _NavItem(Icons.category, 'Catégories'),
    _NavItem(Icons.photo_library, 'Bibliothèque Photo'),
  ];

  String get _currentTabTitle => _navItems[_selectedIndex].label;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1000;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppTheme.darkBackground,
            appBar: AppBar(
              backgroundColor: AppTheme.darkBackground,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.4)),
                    ),
                    child: Image.asset(
                      'assets/logo_openfood_transparent.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_menu, color: AppTheme.emeraldGreen, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'OPENFOOD ADMIN',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentTabTitle,
                          style: const TextStyle(color: AppTheme.emeraldGreen, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  tooltip: 'Se déconnecter',
                  onPressed: _logout,
                ),
              ],
            ),
            drawer: Drawer(
              backgroundColor: AppTheme.darkBackground,
              child: SafeArea(
                child: _buildSidebarContent(isDrawer: true),
              ),
            ),
            body: SafeArea(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          );
        }

        // Desktop layout
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          body: Row(
            children: [
              Container(
                width: 250,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: _buildSidebarContent(isDrawer: false),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.darkBackground, AppTheme.lighterDarkBackground],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
      },
    );
  }

  Widget _buildSidebarContent({required bool isDrawer}) {
    return Column(
      children: [
        // Header logo
        Padding(
          padding: EdgeInsets.symmetric(vertical: isDrawer ? 16.0 : 20.0, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo_openfood_transparent.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_menu, color: AppTheme.emeraldGreen, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OPENFOOD',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    Text(
                      'Super Administration',
                      style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),

        // Navigation list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _navItems.length,
            itemBuilder: (context, index) {
              final item = _navItems[index];
              final isSelected = _selectedIndex == index;

              return ListTile(
                dense: true,
                leading: Icon(
                  item.icon,
                  color: isSelected ? AppTheme.emeraldGreen : Colors.white60,
                  size: 20,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                onTap: () {
                  if (isDrawer) {
                    Navigator.of(context).pop();
                  }
                  setState(() => _selectedIndex = index);
                },
              );
            },
          ),
        ),

        const Divider(color: Colors.white12, height: 1),

        // Footer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Conçu & Développé par Cooking Data • Solutions Informatiques & IA (cookingdata.fr)',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.verified_outlined, color: AppTheme.emeraldGreen, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cooking Data 🇲🇶',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                tooltip: 'Se déconnecter',
                onPressed: _logout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
