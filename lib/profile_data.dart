import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfileData extends ChangeNotifier {
  static final ProfileData _instance = ProfileData._internal();
  factory ProfileData() => _instance;
  ProfileData._internal();

  XFile? _avatarFile;
  XFile? get avatarFile => _avatarFile;

  // Select avatar from phone gallery and notify all listening pages
  Future<void> pickAndSaveAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _avatarFile = image;
      notifyListeners();
    }
  }
}

final profileData = ProfileData();
