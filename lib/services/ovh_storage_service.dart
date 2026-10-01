import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class OvhStorageService {
  // Point d'entrée de l'API Upload sur le serveur OVH
  static const String uploadUrl = 'https://www.openfood.fr/api/upload.php';

  /// Ouvre le sélecteur de fichier/galerie et téléverse automatiquement sur le serveur OVH
  static Future<String?> pickAndUploadImage({
    String folder = 'dishes',
  }) async {
    try {
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
    } catch (e) {
      print('Erreur OvhStorageService.pickAndUploadImage: $e');
      rethrow;
    }
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
      print('Erreur OvhStorageService.uploadImageBytes: $e');
      rethrow;
    }
  }
}
