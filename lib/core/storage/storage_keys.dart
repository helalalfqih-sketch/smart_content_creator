class StorageKeys {
  // --- Auth & Identity ---
  static const String loggedUserId = 'logged_user_id';
  static const String otpEmail = 'otp_email';
  static const String firebaseUid = 'firebase_uid';
  
  // --- Theme & UI ---
  static const String isDarkMode = 'isDarkMode';
  
  // --- AI Providers ---
  static const String activeTextProvider = 'activeTextProvider';
  static const String activeVideoProvider = 'activeVideoProvider';
  static const String activeProvider = 'activeProvider'; // Legacy
  
  // --- Settings & Preferences ---
  static const String jinaEnabled = 'jina_enabled';
  static const String planningModeEnabled = 'planning_mode_enabled';
  static const String lastChatSessionId = 'last_chat_session_id';
  static const String storageMigrated = 'storage_migrated';
  static const String includeBrandInShare = 'include_brand_in_share';
  
  // --- TikTok Account ---
  static const String tiktokActorId = 'tiktok_actor_id';
  static const String tiktokUsername = 'tiktok_username';
  static const String tiktokProfileUrl = 'tiktok_profile_url';
  static const String tiktokConnected = 'tiktok_connected';
  static const String tiktokError = 'tiktok_error';
  
  // --- Social Account (YouTube/Instagram) ---
  static const String youtubeHandle = 'youtube_handle';
  static const String youtubeChannelUrl = 'youtube_channel_url';
  static const String instagramUsername = 'instagram_username';
  static const String instagramProfileUrl = 'instagram_profile_url';

  // --- Secure Storage Keys (Sensitive) ---
  static const String geminiToken = 'gemini_oauth_token';
  static const String instagramToken = 'instagram_access_token';
  static const String tiktokToken = 'tiktok_access_token';
  static const String githubKeyPrefix = 'github_key_';

  // --- Dynamic Provider Keys ---
  static String apiKeyKey(String provider) => 'apiKey_$provider';
  static String endpointKey(String provider) => 'endpoint_$provider';
  static String testTimeKey(String provider) => 'test_time_$provider';
  static String testSuccessKey(String provider) => 'test_success_$provider';
}
