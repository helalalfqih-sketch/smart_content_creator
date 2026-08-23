/// 📱 WhatsApp Sync Data Models
/// نماذج بيانات تكامل ومزامنة وسائط الواتساب
library;

class WhatsAppWabaAccount {
  final String name;
  final String wabaId;
  final String phone;
  final String phoneNumberId;
  final String status;

  WhatsAppWabaAccount({
    required this.name,
    required this.wabaId,
    required this.phone,
    required this.phoneNumberId,
    required this.status,
  });

  factory WhatsAppWabaAccount.fromMap(Map<String, dynamic> map) {
    return WhatsAppWabaAccount(
      name: map['name'] ?? '',
      wabaId: map['wabaId'] ?? '',
      phone: map['phone'] ?? '',
      phoneNumberId: map['phoneNumberId'] ?? '',
      status: map['status'] ?? 'مسجّل',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'wabaId': wabaId,
      'phone': phone,
      'phoneNumberId': phoneNumberId,
      'status': status,
    };
  }
}

class WhatsAppSyncConfig {
  final String phoneNumber;
  final String wabaId;
  final String? phoneNumberId;
  final String? metaAppId;
  final String? contactEmail;
  final String? privacyPolicyUrl;
  final String? termsOfServiceUrl;
  final String? dataDeletionUrl;
  final String verifyToken;
  final bool autoAiProcess;
  final String status;
  final String? lastSyncAt;
  final int mediaCount;
  final List<WhatsAppWabaAccount> accounts;

  WhatsAppSyncConfig({
    required this.phoneNumber,
    required this.wabaId,
    this.phoneNumberId,
    this.metaAppId,
    this.contactEmail,
    this.privacyPolicyUrl,
    this.termsOfServiceUrl,
    this.dataDeletionUrl,
    required this.verifyToken,
    this.autoAiProcess = true,
    this.status = 'active',
    this.lastSyncAt,
    this.mediaCount = 14,
    this.accounts = const [],
  });

  factory WhatsAppSyncConfig.fromMap(Map<String, dynamic> map) {
    var rawAccounts = map['accounts'] as List? ?? [];
    List<WhatsAppWabaAccount> parsedAccounts = rawAccounts
        .map((a) => WhatsAppWabaAccount.fromMap(Map<String, dynamic>.from(a)))
        .toList();

    return WhatsAppSyncConfig(
      phoneNumber: map['phoneNumber'] ?? '+967738609222',
      wabaId: map['wabaId'] ?? '28459237033683884',
      phoneNumberId: map['phoneNumberId'] ?? '1307082469145976',
      metaAppId: map['metaAppId'] ?? '1403080371744739',
      contactEmail: map['contactEmail'] ?? 'smartaccuont@gmail.com',
      privacyPolicyUrl: map['privacyPolicyUrl'],
      termsOfServiceUrl: map['termsOfServiceUrl'],
      dataDeletionUrl: map['dataDeletionUrl'],
      verifyToken: map['verifyToken'] ?? 'indexes_wa_secret_verify_2026',
      autoAiProcess: map['autoAiProcess'] ?? true,
      status: map['status'] ?? 'active',
      lastSyncAt: map['lastSyncAt'],
      mediaCount: (map['mediaCount'] as num?)?.toInt() ?? 14,
      accounts: parsedAccounts.isNotEmpty
          ? parsedAccounts
          : [
              WhatsAppWabaAccount(
                name: 'اندكس للتجارة',
                wabaId: '28459237033683884',
                phone: '+967738609222',
                phoneNumberId: '1307082469145976',
                status: 'مسجّل',
              ),
              WhatsAppWabaAccount(
                name: 'اندكس للتجارة 1',
                wabaId: '2347070759160644',
                phone: '+967785574271',
                phoneNumberId: '1282161161642455',
                status: 'لم يتم التحقق',
              ),
            ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'wabaId': wabaId,
      'phoneNumberId': phoneNumberId,
      'metaAppId': metaAppId,
      'contactEmail': contactEmail,
      'privacyPolicyUrl': privacyPolicyUrl,
      'termsOfServiceUrl': termsOfServiceUrl,
      'dataDeletionUrl': dataDeletionUrl,
      'verifyToken': verifyToken,
      'autoAiProcess': autoAiProcess,
      'status': status,
      'lastSyncAt': lastSyncAt,
      'mediaCount': mediaCount,
      'accounts': accounts.map((a) => a.toMap()).toList(),
    };
  }

  WhatsAppSyncConfig copyWith({
    String? phoneNumber,
    String? wabaId,
    String? phoneNumberId,
    String? metaAppId,
    String? contactEmail,
    String? privacyPolicyUrl,
    String? termsOfServiceUrl,
    String? dataDeletionUrl,
    String? verifyToken,
    bool? autoAiProcess,
    String? status,
    String? lastSyncAt,
    int? mediaCount,
    List<WhatsAppWabaAccount>? accounts,
  }) {
    return WhatsAppSyncConfig(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      wabaId: wabaId ?? this.wabaId,
      phoneNumberId: phoneNumberId ?? this.phoneNumberId,
      metaAppId: metaAppId ?? this.metaAppId,
      contactEmail: contactEmail ?? this.contactEmail,
      privacyPolicyUrl: privacyPolicyUrl ?? this.privacyPolicyUrl,
      termsOfServiceUrl: termsOfServiceUrl ?? this.termsOfServiceUrl,
      dataDeletionUrl: dataDeletionUrl ?? this.dataDeletionUrl,
      verifyToken: verifyToken ?? this.verifyToken,
      autoAiProcess: autoAiProcess ?? this.autoAiProcess,
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      mediaCount: mediaCount ?? this.mediaCount,
      accounts: accounts ?? this.accounts,
    );
  }
}

class WhatsAppAiSuggestion {
  final String title;
  final String description;
  final String category;
  final double price;
  final List<String> tags;

  WhatsAppAiSuggestion({
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.tags = const [],
  });

  factory WhatsAppAiSuggestion.fromMap(Map<String, dynamic> map) {
    var rawTags = map['tags'] as List? ?? [];
    return WhatsAppAiSuggestion(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'متنوعات',
      price: (map['price'] as num?)?.toDouble() ?? 15000.0,
      tags: rawTags.map((t) => t.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'tags': tags,
    };
  }
}

class WhatsAppDraftModel {
  final String id;
  final String supplierPhone;
  final String title;
  final String description;
  final double price;
  final String currency;
  final String imageLink;
  final List<String> additionalImageLinks;
  final String? videoUrl;
  final String? categoryName;
  final String status;
  final WhatsAppAiSuggestion? aiSuggestion;
  final DateTime? receivedAt;

  WhatsAppDraftModel({
    required this.id,
    required this.supplierPhone,
    required this.title,
    required this.description,
    required this.price,
    this.currency = 'YER',
    required this.imageLink,
    this.additionalImageLinks = const [],
    this.videoUrl,
    this.categoryName,
    this.status = 'pending_review',
    this.aiSuggestion,
    this.receivedAt,
  });

  factory WhatsAppDraftModel.fromMap(Map<String, dynamic> map) {
    var rawAdd = map['additionalImageLinks'] as List? ?? [];
    WhatsAppAiSuggestion? sug;
    if (map['aiSuggestion'] is Map) {
      sug = WhatsAppAiSuggestion.fromMap(Map<String, dynamic>.from(map['aiSuggestion']));
    }

    DateTime? parsedDate;
    if (map['createdAt'] != null) {
      parsedDate = DateTime.tryParse(map['createdAt'].toString());
    } else if (map['receivedAt'] != null) {
      parsedDate = DateTime.tryParse(map['receivedAt'].toString());
    }

    return WhatsAppDraftModel(
      id: map['id'] ?? map['objectId'] ?? '',
      supplierPhone: map['supplierPhone'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'YER',
      imageLink: map['imageLink'] ?? '',
      additionalImageLinks: rawAdd.map((e) => e.toString()).toList(),
      videoUrl: map['videoUrl'],
      categoryName: map['categoryName'],
      status: map['status'] ?? 'pending_review',
      aiSuggestion: sug,
      receivedAt: parsedDate ?? DateTime.now(),
    );
  }
}
