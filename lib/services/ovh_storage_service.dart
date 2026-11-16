import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class OvhStorageService {
  // Point d'entrée de l'API Upload sur le serveur OVH
  static const String uploadUrl = 'https://www.openfood.fr/api/upload.php';

  /// Ouvre le sélecteur de fichier/galerie et téléverse automatiquement sur le serveur OVH
  static Future<String?> pickAndUploadImage({
    String folder = 'dishes',
  }) async {
    try {
      if (kIsWeb) {
        // En environnement web, assurer l'enregistrement du plugin ou utiliser le sélecteur HTML natif
        try {
          ImagePickerPlatform.instance = ImagePickerPlugin();
          final picker = ImagePicker();
          final XFile? file = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );

          if (file == null) return null;

          final bytes = await file.readAsBytes();
          return await uploadImageBytes(
            bytes: bytes,
            fileName: file.name,
            folder: folder,
          );
        } catch (pluginError) {
          debugPrint('ImagePicker web plugin fallback to native HTML input: $pluginError');
          return await _pickAndUploadViaHtmlInput(folder: folder);
        }
      } else {
        final picker = ImagePicker();
        final XFile? file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (file == null) return null;

        final bytes = await file.readAsBytes();
        return await uploadImageBytes(
          bytes: bytes,
          fileName: file.name,
          folder: folder,
        );
      }
    } catch (e) {
      debugPrint('Erreur OvhStorageService.pickAndUploadImage: $e');
      rethrow;
    }
  }

  /// Sélecteur de fichier HTML natif garantissant 0 dépendance de plugin sur navigateur
  static Future<String?> _pickAndUploadViaHtmlInput({
    required String folder,
  }) async {
    final completer = Completer<String?>();
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/png,image/jpeg,image/webp,image/gif,image/*';
    uploadInput.multiple = false;

    // Détecter l'annulation via le focus de la fenêtre
    void onFocusListener(html.Event e) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!completer.isCompleted && (uploadInput.files == null || uploadInput.files!.isEmpty)) {
          completer.complete(null);
        }
      });
    }

    html.window.addEventListener('focus', onFocusListener);

    uploadInput.onChange.listen((e) async {
      html.window.removeEventListener('focus', onFocusListener);
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoadEnd.listen((e) async {
        try {
          final Uint8List bytes = reader.result as Uint8List;
          final String? url = await uploadImageBytes(
            bytes: bytes,
            fileName: file.name,
            folder: folder,
          );
          if (!completer.isCompleted) completer.complete(url);
        } catch (err) {
          if (!completer.isCompleted) completer.completeError(err);
        }
      });

      reader.onError.listen((e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception("Erreur de lecture du fichier sélectionné"));
        }
      });
    });

    uploadInput.click();
    return completer.future;
  }

  /// Téléverse un flux binaire (bytes) vers l'API PHP OVH
  static Future<String?> uploadImageBytes({
    required List<int> bytes,
    required String fileName,
    String folder = 'dishes',
  }) async {
    try {
      final uri = Uri.parse(uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      request.fields['folder'] = folder;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName.isNotEmpty ? fileName : 'photo.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['url'] != null) {
          return data['url'] as String;
        } else {
          throw Exception(data['error'] ?? 'Échec du stockage sur OVH.');
        }
      } else {
        throw Exception('Erreur serveur OVH (HTTP ${response.statusCode}) : ${response.body}');
      }
    } catch (e) {
      debugPrint('Erreur OvhStorageService.uploadImageBytes: $e');
      rethrow;
    }
  }
}
