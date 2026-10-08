import 'package:device_info_plus/device_info_plus.dart';

/// جمع معلومات الجهاز (العلامة + الطراز) لعرضها في لوحة الإدارة.
class DeviceInfoService {
  static final DeviceInfoService instance = DeviceInfoService._();
  DeviceInfoService._();

  /// اسم الجهاز قابل للقراءة مثل "Xiaomi Redmi Note 12" (أو معرف الجهاز إن تعذر).
  Future<String> getDeviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final brand = info.brand.trim();
      final model = info.model.trim();
      if (model.isNotEmpty && brand.isNotEmpty && model != brand) {
        return '$brand $model';
      }
      if (model.isNotEmpty) return model;
      if (brand.isNotEmpty) return brand;
      return info.device.isEmpty ? 'جهاز غير معروف' : info.device;
    } catch (_) {
      return 'جهاز غير معروف';
    }
  }
}