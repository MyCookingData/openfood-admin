import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class _OptimizedImageResult {
  final Uint8List bytes;
  final String fileName;

  _OptimizedImageResult({required this.bytes, required this.fileName});
}

class OvhStorageService {
  // Point d'entrée de l'API Upload sur le serveur OVH
  static const String uploadUrl = 'https://www.openfood.fr/api/upload.php';

  /// Ouvre le sélecteur de fichier/galerie, compresse l'image et la téléverse sur OVH
  static Future<String?> pickAndUploadImage({
    String folder = 'dishes',
  }) async {
    try {
      if (kIsWeb) {
        // En environnement web, sélecteur HTML avec compression Canvas GPU native
        return await _pickAndUploadViaHtmlInput(folder: folder);
      } else {
        final picker = ImagePicker();
        final XFile? file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1400,
          maxHeight: 1400,
          imageQuality: 82,
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

  /// Sélecteur de fichier HTML avec redimensionnement et compression automatique avant upload
  static Future<String?> _pickAndUploadViaHtmlInput({
    required String folder,
    int maxDimension = 1400,
    double quality = 0.82,
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

      // Bloquer si le fichier brut dépasse 25 Mo
      if (file.size > 25 * 1024 * 1024) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception("Le fichier sélectionné est trop volumineux (${(file.size / (1024 * 1024)).toStringAsFixed(1)} Mo). La limite maximale est de 25 Mo."),
          );
        }
        return;
      }

      try {
        // Redimensionnement et compression côté navigateur via Canvas HTML5
        final optimized = await _compressAndResizeFileWeb(
          file,
          maxDimension: maxDimension,
          quality: quality,
        );

        final String? url = await uploadImageBytes(
          bytes: optimized.bytes,
          fileName: optimized.fileName,
          folder: folder,
        );

        if (!completer.isCompleted) completer.complete(url);
      } catch (err) {
        if (!completer.isCompleted) completer.completeError(err);
      }
    });

    uploadInput.click();
    return completer.future;
  }

  /// Redimensionne proportionnellement (max 1400px) et compresse en JPEG 82%
  static Future<_OptimizedImageResult> _compressAndResizeFileWeb(
    html.File file, {
    int maxDimension = 1400,
    double quality = 0.82,
  }) async {
    // Les GIF animés sont conservés bruts pour ne pas corrompre l'animation
    if (file.type == 'image/gif' || file.name.toLowerCase().endsWith('.gif')) {
      final bytes = await _readFileAsBytes(file);
      return _OptimizedImageResult(bytes: bytes, fileName: file.name);
    }

    final completer = Completer<_OptimizedImageResult>();
    final objectUrl = html.Url.createObjectUrlFromBlob(file);
    final img = html.ImageElement(src: objectUrl);

    img.onLoad.listen((_) {
      try {
        final int origWidth = img.naturalWidth;
        final int origHeight = img.naturalHeight;

        if (origWidth <= 0 || origHeight <= 0) {
          _readFileAsBytes(file).then((bytes) {
            html.Url.revokeObjectUrl(objectUrl);
            completer.complete(_OptimizedImageResult(bytes: bytes, fileName: file.name));
          }).catchError((err) {
            html.Url.revokeObjectUrl(objectUrl);
            completer.completeError(err);
          });
          return;
        }

        int targetWidth = origWidth;
        int targetHeight = origHeight;

        // Calcul des dimensions proportionnelles
        if (targetWidth > maxDimension || targetHeight > maxDimension) {
          if (targetWidth > targetHeight) {
            targetHeight = (targetHeight * maxDimension / targetWidth).round();
            targetWidth = maxDimension;
          } else {
            targetWidth = (targetWidth * maxDimension / targetHeight).round();
            targetHeight = maxDimension;
          }
        }

        final canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
        final ctx = canvas.context2D;
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';

        // Fond blanc pour éviter un arrière-plan noir sur les PNG transparents convertis en JPEG
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, targetWidth, targetHeight);

        // Dessin redimensionné
        ctx.drawImageScaled(img, 0, 0, targetWidth, targetHeight);

        // Export compressé en JPEG
        final dataUrl = canvas.toDataUrl('image/jpeg', quality);
        html.Url.revokeObjectUrl(objectUrl);

        final commaIdx = dataUrl.indexOf(',');
        if (commaIdx != -1) {
          final base64Str = dataUrl.substring(commaIdx + 1);
          final bytes = base64Decode(base64Str);

          // Nom de fichier avec extension standard .jpg
          String cleanName = file.name;
          final dotIdx = cleanName.lastIndexOf('.');
          if (dotIdx != -1) {
            cleanName = '${cleanName.substring(0, dotIdx)}.jpg';
          } else {
            cleanName = '$cleanName.jpg';
          }

          debugPrint('Photo optimisée: ${(file.size / 1024).round()} Ko -> ${(bytes.length / 1024).round()} Ko ($origWidth x $origHeight -> $targetWidth x $targetHeight)');
          completer.complete(_OptimizedImageResult(bytes: bytes, fileName: cleanName));
        } else {
          _readFileAsBytes(file).then((bytes) {
            completer.complete(_OptimizedImageResult(bytes: bytes, fileName: file.name));
          });
        }
      } catch (err) {
        html.Url.revokeObjectUrl(objectUrl);
        _readFileAsBytes(file).then((bytes) {
          completer.complete(_OptimizedImageResult(bytes: bytes, fileName: file.name));
        }).catchError(completer.completeError);
      }
    });

    img.onError.listen((_) {
      html.Url.revokeObjectUrl(objectUrl);
      _readFileAsBytes(file).then((bytes) {
        completer.complete(_OptimizedImageResult(bytes: bytes, fileName: file.name));
      }).catchError(completer.completeError);
    });

    return completer.future;
  }

  static Future<Uint8List> _readFileAsBytes(html.File file) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      completer.complete(reader.result as Uint8List);
    });
    reader.onError.listen((_) {
      completer.completeError(Exception("Erreur de lecture du fichier sélectionné"));
    });
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