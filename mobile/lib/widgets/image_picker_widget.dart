// ABOUTME: Reusable image picker widget for profile pictures and banner images
// ABOUTME: Handles image selection, cropping, and preview with customizable aspect ratios

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImagePickerWidget extends StatelessWidget {
  final File? imageFile;
  final String? placeholder;
  final double aspectRatio;
  final double? width;
  final double? height;
  final bool isCircular;
  final Function(File?) onImageChanged;

  const ImagePickerWidget({
    super.key,
    this.imageFile,
    this.placeholder,
    required this.aspectRatio,
    this.width,
    this.height,
    this.isCircular = false,
    required this.onImageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final containerWidth = width ?? double.infinity;
    final containerHeight = height ?? (containerWidth / aspectRatio);

    return GestureDetector(
      onTap: () => _showImagePickerDialog(context),
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: isCircular ? null : BorderRadius.circular(8),
          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
          border: Border.all(
            color: Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: isCircular 
              ? BorderRadius.circular(containerHeight / 2)
              : BorderRadius.circular(8),
          child: Stack(
            children: [
              // Image display
              Positioned.fill(
                child: _buildImageDisplay(),
              ),
              
              // Overlay with camera icon
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: isCircular 
                        ? BorderRadius.circular(containerHeight / 2)
                        : BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    // Show local file if selected
    if (imageFile != null) {
      return Image.file(
        imageFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }
    
    // Show placeholder URL if provided
    if (placeholder != null && placeholder!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: placeholder!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    
    // Show default placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[700],
      child: Center(
        child: Icon(
          isCircular ? Icons.person : Icons.image,
          color: Colors.grey[400],
          size: isCircular ? 32 : 48,
        ),
      ),
    );
  }

  void _showImagePickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isCircular ? 'Profile Picture' : 'Select Image',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Camera option
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromCamera();
                },
              ),
              
              // Gallery option
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromGallery();
                },
              ),
              
              // Remove option (if image exists)
              if (imageFile != null || (placeholder != null && placeholder!.isNotEmpty))
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Remove Image',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onImageChanged(null);
                  },
                ),
              
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _pickImageFromCamera() {
    // TODO: Implement camera image picker
    // This would typically use image_picker package:
    // final picker = ImagePicker();
    // final image = await picker.pickImage(source: ImageSource.camera);
    // if (image != null) {
    //   final croppedFile = await _cropImage(File(image.path));
    //   onImageChanged(croppedFile);
    // }
    
    debugPrint('📷 Camera image picker not implemented yet');
  }

  void _pickImageFromGallery() {
    // TODO: Implement gallery image picker
    // This would typically use image_picker package:
    // final picker = ImagePicker();
    // final image = await picker.pickImage(source: ImageSource.gallery);
    // if (image != null) {
    //   final croppedFile = await _cropImage(File(image.path));
    //   onImageChanged(croppedFile);
    // }
    
    debugPrint('🖼️ Gallery image picker not implemented yet');
  }

  // TODO: Implement image cropping
  // Future<File?> _cropImage(File imageFile) async {
  //   // This would typically use image_cropper package:
  //   final croppedFile = await ImageCropper().cropImage(
  //     sourcePath: imageFile.path,
  //     aspectRatio: CropAspectRatio(
  //       ratioX: aspectRatio == 1.0 ? 1 : aspectRatio,
  //       ratioY: 1,
  //     ),
  //     uiSettings: [
  //       AndroidUiSettings(
  //         toolbarTitle: 'Crop Image',
  //         toolbarColor: Colors.black,
  //         toolbarWidgetColor: Colors.white,
  //         statusBarColor: Colors.black,
  //         backgroundColor: Colors.black,
  //       ),
  //       IOSUiSettings(
  //         title: 'Crop Image',
  //       ),
  //     ],
  //   );
  //   return croppedFile != null ? File(croppedFile.path) : null;
  // }
}