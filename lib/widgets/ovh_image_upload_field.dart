import 'package:flutter/material.dart';
import '../services/ovh_storage_service.dart';
import 'photo_library_picker_dialog.dart';

class OvhImageUploadField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String folder;
  final VoidCallback? onUploaded;

  const OvhImageUploadField({
    super.key,
    required this.label,
    required this.controller,
    this.folder = 'dishes',
    this.onUploaded,
  });

  @override
  State<OvhImageUploadField> createState() => _OvhImageUploadFieldState();
}

class _OvhImageUploadFieldState extends State<OvhImageUploadField> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    setState(() => _isUploading = true);
    try {
      final url = await OvhStorageService.pickAndUploadImage(folder: widget.folder);
      if (url != null && mounted) {
        setState(() {
          widget.controller.text = url;
        });
        widget.onUploaded?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Nouvelle photo enregistrée sur le serveur OVH !"),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⛔ Erreur upload OVH : $e"),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _openLibraryPicker() async {
    final selectedUrl = await PhotoLibraryPickerDialog.show(
      context,
      initialFolder: widget.folder,
    );

    if (selectedUrl != null && selectedUrl.isNotEmpty && mounted) {
      setState(() {
        widget.controller.text = selectedUrl;
      });
      widget.onUploaded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Photo sélectionnée depuis la Bibliothèque Photo OVH !"),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_isUploading)
              const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  ),
                  SizedBox(width: 8),
                  Text("Envoi vers OVH...", style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  widget.controller.text.trim(),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.white10,
                    child: const Icon(Icons.image_not_supported, color: Colors.white38, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "https://www.openfood.fr/uploads/${widget.folder}/...",
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF161F17),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton 1 : Choisir depuis la Bibliothèque Photo
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF142418),
                foregroundColor: const Color(0xFF34D399),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF34D399).withValues(alpha: 0.4)),
                ),
              ),
              onPressed: _openLibraryPicker,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text(
                "Bibliothèque",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton 2 : Importer un nouveau fichier vers OVH
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2E21),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
              ),
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(
                _isUploading ? "Envoi..." : "Importer",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
