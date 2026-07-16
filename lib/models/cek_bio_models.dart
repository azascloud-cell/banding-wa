import 'country_model.dart';

enum CekBioInputMethod { nomor, upload }

enum CekBioStatus { idle, scanning, done, error }

/// Hasil pengecekan satu nomor, diisi dari respons backend (data WhatsApp
/// nyata) — bukan lagi hasil validasi format lokal semata.
class CekBioNumberResult {
  final String phone;
  final CountryModel country;
  final bool formatValid;
  final bool registered;
  final bool business;
  final bool verified;
  final bool catalog;
  final bool aiAgent;
  final String? bio;
  final String? bioDate;
  final String? category;
  final String? description;
  final String? website;
  final String? email;
  final String? address;
  final String? timezone;
  final String? memberSince;
  final String? cover;
  final String? error;

  const CekBioNumberResult({
    required this.phone,
    required this.country,
    required this.formatValid,
    required this.registered,
    required this.business,
    required this.verified,
    required this.catalog,
    required this.aiAgent,
    this.bio,
    this.bioDate,
    this.category,
    this.description,
    this.website,
    this.email,
    this.address,
    this.timezone,
    this.memberSince,
    this.cover,
    this.error,
  });

  factory CekBioNumberResult.fromJson(Map<String, dynamic> json) {
    final countryJson = json['country'] as Map<String, dynamic>?;
    return CekBioNumberResult(
      phone: json['phone'] as String? ?? '',
      country: CountryModel(
        code: countryJson?['code'] as String? ?? '??',
        name: countryJson?['name'] as String? ?? 'Tidak diketahui',
        dialCode: countryJson?['dialCode'] as String? ?? '',
        flag: countryJson?['flag'] as String? ?? '🏳️',
      ),
      formatValid: json['formatValid'] as bool? ?? false,
      registered: json['registered'] as bool? ?? false,
      business: json['business'] as bool? ?? false,
      verified: json['verified'] as bool? ?? false,
      catalog: json['catalog'] as bool? ?? false,
      aiAgent: json['aiAgent'] as bool? ?? false,
      bio: json['bio'] as String?,
      bioDate: json['bioDate'] as String?,
      category: json['category'] as String?,
      description: json['description'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      timezone: json['timezone'] as String?,
      memberSince: json['memberSince'] as String?,
      cover: json['cover'] as String?,
      error: json['error'] as String?,
    );
  }
}

class CekBioStatistics {
  final int totalInput;
  final int valid;
  final int invalid;
  final int registered;
  final int unregistered;
  final int haveBio;
  final int noBio;
  final int business;
  final int aiAgent;

  const CekBioStatistics({
    required this.totalInput,
    required this.valid,
    required this.invalid,
    required this.registered,
    required this.unregistered,
    required this.haveBio,
    required this.noBio,
    required this.business,
    required this.aiAgent,
  });

  factory CekBioStatistics.fromJson(Map<String, dynamic> json) {
    return CekBioStatistics(
      totalInput: json['totalInput'] as int? ?? 0,
      valid: json['valid'] as int? ?? 0,
      invalid: json['invalid'] as int? ?? 0,
      registered: json['registered'] as int? ?? 0,
      unregistered: json['unregistered'] as int? ?? 0,
      haveBio: json['haveBio'] as int? ?? 0,
      noBio: json['noBio'] as int? ?? 0,
      business: json['business'] as int? ?? 0,
      aiAgent: json['aiAgent'] as int? ?? 0,
    );
  }
}
