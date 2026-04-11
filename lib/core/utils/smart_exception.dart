class SmartUserException implements Exception {
  final String message;
  final bool isConnectionError;
  final bool isQuotaExceeded; // 🧠 Added for Managed AI (v3.0)

  SmartUserException(
    this.message, {
    this.isConnectionError = false,
    this.isQuotaExceeded = false,
  });

  @override
  String toString() => message;
}
