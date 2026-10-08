class AppConstants {
  static const String appName = 'شبكة الحارث';
  static const String version = '2.0.0';
  static const String networkName = 'شبكة الحارث';
  static const String adminSecretKey = '1234';
  static const String superAdminSecretKey = 'super_admin_2024';
  static const String collectionSuperAdmin = 'super_admin';

  // URLs
  static const String defaultLoginUrl = 'http://www.h.net/index.html';
  static const String defaultLiveUrl =
      'http://20.20.20.20:876/videojs/index.html';
  static const String defaultRestUrl =
      'http://20.20.20.20:8096/web/index.html#!/home';
  static const String telegramGroupUrl = 'https://t.me/alkharith_net';
  static const String whatsappNumber = '+967777777777';

  // Firestore collections
  static const String collectionMessages = 'admin_messages';
  static const String collectionSuggestions = 'suggestions';
  static const String collectionUsers = 'app_users';
  static const String collectionSpinPrizes = 'spin_prizes';
  static const String collectionUserSpinData = 'user_spin_data';
  static const String collectionAppSettings = 'app_settings';
  static const String docAppSettings = 'general';

  // SharedPreferences keys
  static const String keyUserVoucher = 'user_voucher';
  static const String keySessionStart = 'session_start';
  static const String keySessionDuration = 'session_duration';
  static const String keyGatewayIp = 'gateway_ip';
  static const String keyLoginUrl = 'login_url';
  static const String keyLiveUrl = 'live_url';
  static const String keyRestUrl = 'rest_url';
  static const String keyFcmToken = 'fcm_token';
  static const String keyAdminLoggedIn = 'admin_logged_in';
  static const String keySuperAdminLoggedIn = 'super_admin_logged_in';
  static const String keyLogoPath = 'custom_logo_path';
  static const String keyWhatsapp = 'custom_whatsapp';
  static const String keyTelegram = 'custom_telegram';
  static const String keyPhone = 'custom_phone';
  static const String keyWhatsappGroup = 'custom_whatsapp_group';
  static const String keyAdminPassword = 'admin_password';
  static const String keySuperAdminPassword = 'super_admin_password';
  static const String keyFcmServerKey = 'fcm_server_key';
  static const String defaultFcmServerKey = '';
  static const String whatsappGroupUrl =
      'https://chat.whatsapp.com/KDSpAN8ygvfCJcb5EB3IPI';

  // Spin Wheel keys
  static const String keySpinSmallCounter = 'spin_small_counter';
  static const String keySpinLargeCounter = 'spin_large_counter';
  static const String keySpinCategory = 'spin_category';
  static const String keySpinSmallAvailable = 'spin_small_available';
  static const String keySpinLargeAvailable = 'spin_large_available';
  static const String keySpinPrizes = 'spin_prizes_list';
  static const String keySpinSmallVouchers = 'spin_small_vouchers';
  static const String keySpinLargeVouchers = 'spin_large_vouchers';
  static const String keyProcessedVouchers = 'processed_vouchers';

  // آخر قيمة رصيد معروفة (محددة من الصفحة الفعلية) - للاحتفاظ بها بين الشاشات
  static const String keyRemainingBytes = 'remaining_bytes';
}
