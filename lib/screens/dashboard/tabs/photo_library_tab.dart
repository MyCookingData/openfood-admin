import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';

class PhotoUsage {
  final String type; // 'Plat', 'Restaurant', 'Bannière', 'Catégorie'
  final String title;
  final String? subtitle;
  final String docId;

  PhotoUsage({
    required this.type,
    required this.title,
    this.subtitle,
    required this.docId,
  });
}

class OvhMediaFile {
  final String filename;
  final String folder;
  final String relativePath;
  final String url;
  final int sizeBytes;
  final String sizeFormatted;
  final int modifiedTimestamp;
  final String modifiedFormatted;
  final String extension;
  List<PhotoUsage> usages = [];

  OvhMediaFile({
    required this.filename,
    required this.folder,
    required this.relativePath,
    required this.url,
    required this.sizeBytes,
    required this.sizeFormatted,
    required this.modifiedTimestamp,
    required this.modifiedFormatted,
    required this.extension,
  });

  bool get isUsed => usages.isNotEmpty;
  int get usageCount => usages.length;
}

class PhotoLibraryTab extends StatefulWidget {
  const PhotoLibraryTab({super.key});

  @override
  State<PhotoLibraryTab> createState() => _PhotoLibraryTabState();
}

class _PhotoLibraryTabState extends State<PhotoLibraryTab> {
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;
  List<OvhMediaFile> _allFiles = [];
  List<OvhMediaFile> _filteredFiles = [];

  // Statistiques
  int _totalSizeBytes = 0;
  String _totalSizeFormatted = '0 Ko';

  // Filtres et tri
  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // 'all', 'used', 'unused'
  String _selectedFolderFilter = 'all'; // 'all', 'dishes', 'restaurants', 'carousels', etc.
  String _selectedSort = 'recent'; // 'recent', 'oldest', 'size_desc', 'size_asc', 'usage_desc'

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Récupération des fichiers depuis l'API OVH
      final uri = Uri.parse('https://www.openfood.fr/api/list_media.php?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Erreur serveur OVH (code HTTP ${response.statusCode})');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Impossible de récupérer la liste des fichiers.');
      }

      final rawFiles = data['files'] as List<dynamic>;
      _totalSizeBytes = data['total_size_bytes'] ?? 0;
      _totalSizeFormatted = data['total_size_formatted'] ?? '0 Ko';

      final List<OvhMediaFile> files = rawFiles.map((f) {
        return OvhMediaFile(
          filename: f['filename'] as String? ?? '',
          folder: f['folder'] as String? ?? 'general',
          relativePath: f['relative_path'] as String? ?? '',
          url: f['url'] as String? ?? '',
          sizeBytes: (f['size_bytes'] as num?)?.toInt() ?? 0,
          sizeFormatted: f['size_formatted'] as String? ?? '0 Ko',
          modifiedTimestamp: (f['modified_timestamp'] as num?)?.toInt() ?? 0,
          modifiedFormatted: f['modified_formatted'] as String? ?? '',
          extension: f['extension'] as String? ?? '',
        );
      }).toList();

      // 2. Récupération de Firestore pour croiser les usages
      final firestore = FirebaseFirestore.instance;
      final results = await Future.wait([
        firestore.collection('restaurants').get(),
        firestore.collection('products').get(),
        firestore.collection('carousels').get(),
        firestore.collection('categories').get(),
      ]);

      final restoDocs = results[0].docs;
      final productDocs = results[1].docs;
      final carouselDocs = results[2].docs;
      final categoryDocs = results[3].docs;

      final Map<String, String> restoNames = {};
      for (final r in restoDocs) {
        final d = r.data();
        restoNames[r.id] = (d['name'] as String?) ?? 'Restaurant sans nom';
      }

      // 3. Analyse croisée de chaque photo
      for (final file in files) {
        final fileUrl = file.url.toLowerCase();
        final fileName = file.filename.toLowerCase();

        bool match(String? rawVal) {
          if (rawVal == null || rawVal.isEmpty) return false;
          final low = rawVal.toLowerCase();
          return low.contains(fileUrl) || low.contains(fileName) || fileUrl.contains(low);
        }

        // Produits
        for (final p in productDocs) {
          final d = p.data();
          final img = d['imageUrl'] as String? ?? d['image'] as String? ?? d['photoUrl'] as String?;
          if (match(img)) {
            final pName = (d['name'] as String?) ?? 'Plat sans nom';
            final rId = d['restaurantId'] as String? ?? '';
            final rName = restoNames[rId] ?? 'Restaurant ID: $rId';
            file.usages.add(PhotoUsage(
              type: 'Plat',
              title: pName,
              subtitle: 'Restaurant : $rName',
              docId: p.id,
            ));
          }
        }

        // Restaurants
        for (final r in restoDocs) {
          final d = r.data();
          final img = d['imageUrl'] as String? ?? d['coverUrl'] as String? ?? d['logoUrl'] as String? ?? d['image'] as String?;
          if (match(img)) {
            final rName = (d['name'] as String?) ?? 'Restaurant sans nom';
            file.usages.add(PhotoUsage(
              type: 'Restaurant',
              title: rName,
              subtitle: 'Photo de profil / couverture',
              docId: r.id,
            ));
          }
        }

        // Carrousels
        for (final c in carouselDocs) {
          final d = c.data();
          final img = d['imageUrl'] as String? ?? d['logoUrl'] as String? ?? d['image'] as String?;
          if (match(img)) {
            final title = (d['title'] as String?) ?? 'Bannière sans titre';
            final tag = (d['tagText'] as String?) ?? '';
            file.usages.add(PhotoUsage(
              type: 'Bannière',
              title: title,
              subtitle: tag.isNotEmpty ? 'Tag : $tag' : 'Carrousel Accueil',
              docId: c.id,
            ));
          }
        }

        // Catégories
        for (final cat in categoryDocs) {
          final d = cat.data();
          final img = d['imageUrl'] as String? ?? d['iconUrl'] as String? ?? d['image'] as String?;
          if (match(img)) {
            final name = (d['name'] as String?) ?? 'Catégorie sans nom';
            file.usages.add(PhotoUsage(
              type: 'Catégorie',
              title: name,
              subtitle: 'Icône / Bannière de catégorie',
              docId: cat.id,
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _allFiles = files;
          _isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<OvhMediaFile> list = List.from(_allFiles);

    // 1. Recherche
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((f) {
        final matchesFilename = f.filename.toLowerCase().contains(q);
        final matchesFolder = f.folder.toLowerCase().contains(q);
        final matchesUsage = f.usages.any((u) => u.title.toLowerCase().contains(q) || (u.subtitle?.toLowerCase().contains(q) ?? false));
        return matchesFilename || matchesFolder || matchesUsage;
      }).toList();
    }

    // 2. Filtre statut
    if (_selectedStatusFilter == 'used') {
      list = list.where((f) => f.isUsed).toList();
    } else if (_selectedStatusFilter == 'unused') {
      list = list.where((f) => !f.isUsed).toList();
    }

    // 3. Filtre dossier
    if (_selectedFolderFilter != 'all') {
      list = list.where((f) => f.folder.toLowerCase() == _selectedFolderFilter.toLowerCase()).toList();
    }

    // 4. Tri
    switch (_selectedSort) {
      case 'recent':
        list.sort((a, b) => b.modifiedTimestamp.compareTo(a.modifiedTimestamp));
        break;
      case 'oldest':
        list.sort((a, b) => a.modifiedTimestamp.compareTo(b.modifiedTimestamp));
        break;
      case 'size_desc':
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case 'size_asc':
        list.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
        break;
      case 'usage_desc':
        list.sort((a, b) => b.usageCount.compareTo(a.usageCount));
        break;
    }

    setState(() {
      _filteredFiles = list;
    });
  }

  // ==== SUPPRESSION D'UNE PHOTO ORPHELINE ====
  Future<void> _confirmAndDeletePhoto(OvhMediaFile file) async {
    if (file.isUsed) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.lighterDarkBackground,
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.amber),
              SizedBox(width: 10),
              Text('Suppression Bloquée', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Cette photo est activement utilisée par ${file.usageCount} élément(s) dans l\'application.\n\nVous devez d\'abord détacher ou remplacer cette photo sur les plats, restaurants ou bannières concernés avant de pouvoir la supprimer du serveur OVH.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris', style: TextStyle(color: AppTheme.emeraldGreen)),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent, width: 1.5)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Text('Supprimer la photo orpheline ?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 140,
                width: double.infinity,
                color: Colors.black38,
                child: Image.network(
                  file.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Fichier : ${file.filename}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Dossier : ${file.folder} • Taille : ${file.sizeFormatted}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Cette action est irréversible et effacera définitivement le fichier physique du disque OVH.',
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Supprimer définitivement', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);

    try {
      final uri = Uri.parse('https://www.openfood.fr/api/delete_media.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'relative_path': file.relativePath}),
      ).timeout(const Duration(seconds: 15));

      final resData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && resData['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Photo ${file.filename} (${file.sizeFormatted}) supprimée du serveur OVH.', style: const TextStyle(color: Colors.white)),
              backgroundColor: AppTheme.emeraldGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        await _loadData();
      } else {
        throw Exception(resData['error'] ?? 'Échec de la suppression sur le serveur.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  // ==== PURGE TOTALE DES PHOTOS ORPHELINES ====
  Future<void> _purgeAllOrphanPhotos() async {
    final orphanFiles = _allFiles.where((f) => !f.isUsed).toList();

    if (orphanFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune photo orpheline à purger.', style: TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
      return;
    }

    int totalOrphanBytes = orphanFiles.fold(0, (sum, f) => sum + f.sizeBytes);
    String formattedFreed = '${(totalOrphanBytes / 1024).toStringAsFixed(1)} Ko';
    if (totalOrphanBytes > 1024 * 1024) {
      formattedFreed = '${(totalOrphanBytes / (1024 * 1024)).toStringAsFixed(2)} Mo';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amber, width: 1.5)),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Text('Purger ${orphanFiles.length} photos orphelines ?', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous êtes sur le point de supprimer définitivement ${orphanFiles.length} photos orphelines non rattachées.\n\nEspace disque récupéré : $formattedFreed.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Toutes les photos utilisées par des restaurants, plats et bannières sont préservées à 100%.',
              style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: Text('Purger ${orphanFiles.length} photos', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);

    int deletedCount = 0;
    try {
      final uri = Uri.parse('https://www.openfood.fr/api/delete_media.php');
      for (final file in orphanFiles) {
        try {
          final res = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'relative_path': file.relativePath}),
          ).timeout(const Duration(seconds: 10));

          if (res.statusCode == 200) {
            deletedCount++;
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Purge terminée : $deletedCount photos orphelines supprimées ($formattedFreed libérés).', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.emeraldGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      await _loadData();
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _showImageDetailsDialog(OvhMediaFile file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Modale
                Row(
                  children: [
                    const Icon(Icons.photo_library_outlined, color: AppTheme.emeraldGreen, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.filename,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Dossier : ${file.folder} • Publiée le ${file.modifiedFormatted} • ${file.sizeFormatted}',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                
                // Contenu : Image HD + Usages
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Aperçu Grand format
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 500),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                border: Border.all(color: Colors.white12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Image.network(
                                file.url,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 200,
                                    alignment: Alignment.center,
                                    child: const CircularProgressIndicator(color: AppTheme.emeraldGreen),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 200,
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image, color: Colors.redAccent, size: 48),
                                      SizedBox(height: 8),
                                      Text('Erreur de chargement de l\'image', style: TextStyle(color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bloc Lien URL
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link, color: AppTheme.emeraldGreen, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  file.url,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                                tooltip: 'Copier le lien direct',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: file.url));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Lien copié dans le presse-papier !', style: TextStyle(color: Colors.white)),
                                      backgroundColor: AppTheme.emeraldGreen,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section Utilisation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  file.isUsed ? Icons.check_circle : Icons.warning_amber_rounded,
                                  color: file.isUsed ? AppTheme.emeraldGreen : Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  file.isUsed
                                      ? 'Utilisée ${file.usageCount} fois dans l\'application :'
                                      : 'Photo Orpheline (Non rattachée)',
                                  style: TextStyle(
                                    color: file.isUsed ? Colors.white : Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            if (!file.isUsed)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.delete_forever, size: 16),
                                label: const Text('Supprimer du serveur', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _confirmAndDeletePhoto(file);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (file.isUsed)
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: file.usages.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final u = file.usages[idx];
                              IconData typeIcon = Icons.fastfood;
                              Color typeColor = Colors.orangeAccent;

                              if (u.type == 'Restaurant') {
                                typeIcon = Icons.storefront;
                                typeColor = Colors.blueAccent;
                              } else if (u.type == 'Bannière') {
                                typeIcon = Icons.view_carousel;
                                typeColor = Colors.purpleAccent;
                              } else if (u.type == 'Catégorie') {
                                typeIcon = Icons.category;
                                typeColor = Colors.tealAccent;
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(typeIcon, color: typeColor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '[${u.type}] ${u.title}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (u.subtitle != null)
                                            Text(
                                              u.subtitle!,
                                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3)),
                                      ),
                                      child: const Text('Actif', style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usedCount = _allFiles.where((f) => f.isUsed).length;
    final unusedCount = _allFiles.length - usedCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre & Boutons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.emeraldGreen.withValues(alpha: 0.25),
                            AppTheme.emeraldGreen.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.photo_library, color: AppTheme.emeraldGreen, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Bibliothèque Photos',
                              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_done, color: AppTheme.emeraldGreen, size: 14),
                                  SizedBox(width: 6),
                                  Text('Serveur OVH', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inventaire, traçabilité des usages, dates de publication et suppression des photos orphelines',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (unusedCount > 0)
                      ElevatedButton.icon(
                        onPressed: (_isLoading || _isActionInProgress) ? null : _purgeAllOrphanPhotos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.cleaning_services, size: 18),
                        label: Text('Purger Orphelines ($unusedCount)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: (_isLoading || _isActionInProgress) ? null : _loadData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: (_isLoading || _isActionInProgress)
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh),
                      label: const Text('Actualiser', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cartes KPI
            Row(
              children: [
                _buildKpiCard(
                  title: 'Total Photos OVH',
                  value: '${_allFiles.length}',
                  subtitle: 'Fichiers hébergés',
                  icon: Icons.photo_library,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  title: 'Espace Disque',
                  value: _totalSizeFormatted,
                  subtitle: '$_totalSizeBytes octets',
                  icon: Icons.storage,
                  color: Colors.purpleAccent,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  title: 'Photos Utilisées',
                  value: '$usedCount',
                  subtitle: _allFiles.isEmpty ? '0%' : '${((usedCount / _allFiles.length) * 100).toStringAsFixed(0)}% du catalogue',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.emeraldGreen,
                ),
                const SizedBox(width: 16),
                _buildKpiCard(
                  title: 'Photos Orphelines',
                  value: '$unusedCount',
                  subtitle: unusedCount > 0 ? 'Suppression autorisée' : 'Aucune photo à purger',
                  icon: Icons.warning_amber_rounded,
                  color: unusedCount > 0 ? Colors.amber : Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Barre de Filtres & Recherche
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  // Recherche
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom de fichier, plat, restaurant...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                  _applyFilters();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Filtre Utilisation
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    dropdownColor: const Color(0xFF162018),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('Tous statuts (${_allFiles.length})')),
                      DropdownMenuItem(value: 'used', child: Text('✅ Utilisées ($usedCount)')),
                      DropdownMenuItem(value: 'unused', child: Text('⚠️ Orphelines ($unusedCount)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedStatusFilter = val;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 16),

                  // Filtre Dossier
                  DropdownButton<String>(
                    value: _selectedFolderFilter,
                    dropdownColor: const Color(0xFF162018),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('📁 Tous les dossiers')),
                      DropdownMenuItem(value: 'dishes', child: Text('🍽️ Plats (dishes)')),
                      DropdownMenuItem(value: 'restaurants', child: Text('🏪 Restaurants')),
                      DropdownMenuItem(value: 'carousels', child: Text('🎨 Carrousels')),
                      DropdownMenuItem(value: 'categories', child: Text('🏷️ Catégories')),
                      DropdownMenuItem(value: 'general', child: Text('📦 Général')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedFolderFilter = val;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 16),

                  // Tri
                  DropdownButton<String>(
                    value: _selectedSort,
                    dropdownColor: const Color(0xFF162018),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'recent', child: Text('⏱️ Plus récentes')),
                      DropdownMenuItem(value: 'oldest', child: Text('⏳ Plus anciennes')),
                      DropdownMenuItem(value: 'size_desc', child: Text('💾 Plus lourdes')),
                      DropdownMenuItem(value: 'size_asc', child: Text('🪶 Plus légères')),
                      DropdownMenuItem(value: 'usage_desc', child: Text('🔥 Plus utilisées')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSort = val;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Grille de Photos
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.emeraldGreen),
                          SizedBox(height: 16),
                          Text('Analyse des photos OVH et croisement avec Firestore...', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text('Erreur: $_errorMessage', style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _loadData, child: const Text('Réessayer')),
                            ],
                          ),
                        )
                      : _filteredFiles.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library_outlined, color: Colors.white30, size: 64),
                                  const SizedBox(height: 16),
                                  const Text('Aucune photo ne correspond à vos filtres.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchCtrl.clear();
                                        _searchQuery = '';
                                        _selectedStatusFilter = 'all';
                                        _selectedFolderFilter = 'all';
                                        _selectedSort = 'recent';
                                        _applyFilters();
                                      });
                                    },
                                    child: const Text('Réinitialiser les filtres', style: TextStyle(color: AppTheme.emeraldGreen)),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 280,
                                mainAxisExtent: 330,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _filteredFiles.length,
                              itemBuilder: (context, idx) {
                                final file = _filteredFiles[idx];
                                return _buildPhotoCard(file);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(OvhMediaFile file) {
    return InkWell(
      onTap: () => _showImageDetailsDialog(file),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file.isUsed ? Colors.white.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview avec Badges & Bouton de suppression
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.black26,
                    child: Image.network(
                      file.url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emeraldGreen));
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white24, size: 40),
                      ),
                    ),
                  ),
                ),
                // Badge Dossier (haut gauche)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      file.folder,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // Badge Utilisation ou Bouton Supprimer (haut droite)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: file.isUsed ? AppTheme.emeraldGreen : Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(file.isUsed ? Icons.check : Icons.warning_amber_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              file.isUsed ? 'Utilisée (${file.usageCount})' : 'Orpheline',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      if (!file.isUsed) ...[
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.redAccent.withValues(alpha: 0.85),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _confirmAndDeletePhoto(file),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(Icons.delete_forever, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Détails Métadonnées
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom de fichier
                        Text(
                          file.filename,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Date de publication & Taille
                        Text(
                          '${file.sizeFormatted} • ${file.modifiedFormatted}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),

                    // Ligne d'usage (ex: Plat : "Tasty Crousty" ou bouton orpheline)
                    if (file.isUsed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link, color: AppTheme.emeraldGreen, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                file.usages.first.title,
                                style: const TextStyle(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.amber, size: 12),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'Non liée • Supprimable',
                                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              onTap: () => _confirmAndDeletePhoto(file),
                              child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
