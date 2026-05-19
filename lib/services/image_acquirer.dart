import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:permission_handler/permission_handler.dart' as ph;

/// Which permission was denied — used by [PermissionDeniedException] so the UI
/// can show the right inline error.
enum ImagePermissionSource { camera, gallery }

class PermissionDeniedException implements Exception {
  final ImagePermissionSource source;
  PermissionDeniedException(this.source);

  @override
  String toString() => 'PermissionDeniedException(${source.name})';
}

/// Abstract interface so [CaptureScreen] can be tested with a fake.
abstract class ImageAcquirer {
  /// Take a photo with the camera. Returns the raw bytes, or null if the user
  /// cancelled. Throws [PermissionDeniedException] if camera permission is
  /// denied.
  Future<Uint8List?> takePhoto();

  /// Pick an existing image from the gallery. Returns the raw bytes, or null
  /// if the user cancelled. Throws [PermissionDeniedException] if photo-
  /// library permission is denied.
  Future<Uint8List?> pickFromGallery();

  /// Open the OS settings app for this app so the user can flip permissions.
  Future<void> openAppSettings();
}

/// Real implementation backed by [image_picker] + [permission_handler].
class ImagePickerAcquirer implements ImageAcquirer {
  final picker.ImagePicker _picker;

  ImagePickerAcquirer({picker.ImagePicker? imagePicker})
      : _picker = imagePicker ?? picker.ImagePicker();

  @override
  Future<Uint8List?> takePhoto() async {
    try {
      final file = await _picker.pickImage(source: picker.ImageSource.camera);
      if (file == null) return null;
      return file.readAsBytes();
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' || e.code == 'permission_denied') {
        throw PermissionDeniedException(ImagePermissionSource.camera);
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List?> pickFromGallery() async {
    // On Android the appropriate permission depends on API level; permission_handler
    // smooths this over with Permission.photos.
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await ph.Permission.photos.status;
      if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
        final result = await ph.Permission.photos.request();
        if (!result.isGranted && !result.isLimited) {
          throw PermissionDeniedException(ImagePermissionSource.gallery);
        }
      }
    }
    try {
      final file = await _picker.pickImage(source: picker.ImageSource.gallery);
      if (file == null) return null;
      return file.readAsBytes();
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied' || e.code == 'permission_denied') {
        throw PermissionDeniedException(ImagePermissionSource.gallery);
      }
      rethrow;
    }
  }

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}
