import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'glass_container.dart';

class PhotoLibraryPickerDialog extends StatefulWidget {
  final String? initialFolder;

  const PhotoLibraryPickerDialog({super.key, this.initialFolder});

  static Future<String?> show(BuildContext context, {String? initialFolder}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => PhotoLibraryPickerDialog(initialFolder: initialFolder),
    );
  }

  @override
  State<PhotoLibraryPickerDialog> createState() => _PhotoLibraryPickerDialogState();
}

class _PhotoLibraryPickerDialogState extends State<PhotoLibraryPickerDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allFiles = [];
  List<Map<String, dynamic>> _filteredFiles = [];
  String _searchQuery = '';
  String _selectedFolder = 'all';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFolder != null && widget.initialFolder!.isNotEmpty) {
      _selectedFolder = widget.initialFolder!;
    }
    _loadPhotos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('https://www.openfood.fr/api/list_media.php?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Impossible de récupérer la liste des photos.');
      }

      final files = List<Map<String, dynamic>>.from(data['files'] as List<dynamic>);

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
    List<Map<String, dynamic>> list = List.from(_allFiles);

    if (_selectedFolder != 'all') {
      list = list.where((f) => (f['folder'] as String?)?.toLowerCase() == _selectedFolder.toLowerCase()).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((f) {
        final filename = (f['filename'] as String?)?.toLowerCase() ?? '';
        final folder = (f['folder'] as String?)?.toLowerCase() ?? '';
        return filename.contains(q) || folder.contains(q);
      }).toList();
    }

    setState(() {
      _filteredFiles = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.emeraldGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choisir depuis la Bibliothèque Photo OVH',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Sélectionnez une image existante sans avoir besoin de la réimporter',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),

              // Barre de Recherche & Dossiers
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une photo par nom...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedFolder,
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
                          _selectedFolder = val;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.emeraldGreen),
                    tooltip: 'Actualiser la bibliothèque',
                    onPressed: _loadPhotos,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grille des Photos
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.emeraldGreen),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                const SizedBox(height: 8),
                                Text('Erreur: $_errorMessage', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _loadPhotos, child: const Text('Réessayer')),
                              ],
                            ),
                          )
                        : _filteredFiles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library_outlined, color: Colors.white30, size: 48),
                                    const SizedBox(height: 12),
                                    const Text('Aucune photo trouvée dans ce dossier.', style: TextStyle(color: Colors.white70)),
                                    if (_selectedFolder != 'all') ...[
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedFolder = 'all';
                                            _applyFilters();
                                          });
                                        },
                                        child: const Text('Afficher tous les dossiers', style: TextStyle(color: AppTheme.emeraldGreen)),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 180,
                                  mainAxisExtent: 200,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _filteredFiles.length,
                                itemBuilder: (context, idx) {
                                  final file = _filteredFiles[idx];
                                  final url = file['url'] as String? ?? '';
                                  final filename = file['filename'] as String? ?? '';
                                  final sizeFormatted = file['size_formatted'] as String? ?? '';
                                  final folder = file['folder'] as String? ?? '';

                                  return InkWell(
                                    onTap: () => Navigator.pop(context, url),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                                  child: Image.network(
                                                    url,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context, child, progress) {
                                                      if (progress == null) return child;
                                                      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emeraldGreen));
                                                    },
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(Icons.broken_image, color: Colors.white24, size: 32),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 6,
                                                  left: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black87,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      folder,
                                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  filename,
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  sizeFormatted,
                                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
