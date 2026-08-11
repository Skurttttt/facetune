import '../entities/avatar_image.dart';

abstract interface class AvatarPicker {
  Future<AvatarImage?> pick();
}
