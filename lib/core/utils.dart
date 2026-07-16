import '../models/country_model.dart';

/// Hapus semua karakter non-angka, normalisasi ke format E.164
String formatPhone(String raw) {
  String digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');

  if (digits.startsWith('0')) {
    digits = '+' + digits.substring(1);
  }

  if (!digits.startsWith('+')) {
    digits = '+' + digits;
  }

  return digits;
}

/// Map prefix negara → CountryModel (minimal)
final Map<String, CountryModel> phoneCountries = {
  '62': CountryModel(code: 'ID', name: 'Indonesia', dialCode: '62', flag: '🇮🇩'),
  '1': CountryModel(code: 'US', name: 'United States', dialCode: '1', flag: '🇺🇸'),
  '44': CountryModel(code: 'GB', name: 'United Kingdom', dialCode: '44', flag: '🇬🇧'),
  '91': CountryModel(code: 'IN', name: 'India', dialCode: '91', flag: '🇮🇳'),
  '86': CountryModel(code: 'CN', name: 'China', dialCode: '86', flag: '🇨🇳'),
  '81': CountryModel(code: 'JP', name: 'Japan', dialCode: '81', flag: '🇯🇵'),
  '82': CountryModel(code: 'KR', name: 'South Korea', dialCode: '82', flag: '🇰🇷'),
  '60': CountryModel(code: 'MY', name: 'Malaysia', dialCode: '60', flag: '🇲🇾'),
  '65': CountryModel(code: 'SG', name: 'Singapore', dialCode: '65', flag: '🇸🇬'),
  '66': CountryModel(code: 'TH', name: 'Thailand', dialCode: '66', flag: '🇹🇭'),
  '84': CountryModel(code: 'VN', name: 'Vietnam', dialCode: '84', flag: '🇻🇳'),
  '63': CountryModel(code: 'PH', name: 'Philippines', dialCode: '63', flag: '🇵🇭'),
  '880': CountryModel(code: 'BD', name: 'Bangladesh', dialCode: '880', flag: '🇧🇩'),
  '92': CountryModel(code: 'PK', name: 'Pakistan', dialCode: '92', flag: '🇵🇰'),
  '966': CountryModel(code: 'SA', name: 'Saudi Arabia', dialCode: '966', flag: '🇸🇦'),
  '971': CountryModel(code: 'AE', name: 'UAE', dialCode: '971', flag: '🇦🇪'),
  '974': CountryModel(code: 'QA', name: 'Qatar', dialCode: '974', flag: '🇶🇦'),
  '973': CountryModel(code: 'BH', name: 'Bahrain', dialCode: '973', flag: '🇧🇭'),
  '968': CountryModel(code: 'OM', name: 'Oman', dialCode: '968', flag: '🇴🇲'),
  '967': CountryModel(code: 'YE', name: 'Yemen', dialCode: '967', flag: '🇾🇪'),
  '212': CountryModel(code: 'MA', name: 'Morocco', dialCode: '212', flag: '🇲🇦'),
  '234': CountryModel(code: 'NG', name: 'Nigeria', dialCode: '234', flag: '🇳🇬'),
  '27': CountryModel(code: 'ZA', name: 'South Africa', dialCode: '27', flag: '🇿🇦'),
  '254': CountryModel(code: 'KE', name: 'Kenya', dialCode: '254', flag: '🇰🇪'),
  '55': CountryModel(code: 'BR', name: 'Brazil', dialCode: '55', flag: '🇧🇷'),
  '52': CountryModel(code: 'MX', name: 'Mexico', dialCode: '52', flag: '🇲🇽'),
  '54': CountryModel(code: 'AR', name: 'Argentina', dialCode: '54', flag: '🇦🇷'),
  '57': CountryModel(code: 'CO', name: 'Colombia', dialCode: '57', flag: '🇨🇴'),
  '33': CountryModel(code: 'FR', name: 'France', dialCode: '33', flag: '🇫🇷'),
  '49': CountryModel(code: 'DE', name: 'Germany', dialCode: '49', flag: '🇩🇪'),
  '7': CountryModel(code: 'RU', name: 'Russia', dialCode: '7', flag: '🇷🇺'),
  '90': CountryModel(code: 'TR', name: 'Turkey', dialCode: '90', flag: '🇹🇷'),
  '98': CountryModel(code: 'IR', name: 'Iran', dialCode: '98', flag: '🇮🇷'),
  '380': CountryModel(code: 'UA', name: 'Ukraine', dialCode: '380', flag: '🇺🇦'),
};

/// Deteksi negara dari nomor telepon format E.164 (misal: +628xxx)
CountryModel detectCountry(String phone) {
  if (phone.length < 2 || !phone.startsWith('+')) {
    return CountryModel(
      code: 'UN',
      name: 'Unknown',
      dialCode: '',
      flag: '🌐',
    );
  }

  String digits = phone.substring(1);

  // Cek prefix 3 digit, 2 digit, 1 digit — prioritas terpanjang
  for (int len = 3; len >= 1; len--) {
    if (digits.length >= len) {
      String prefix = digits.substring(0, len);
      if (phoneCountries.containsKey(prefix)) {
        return phoneCountries[prefix]!;
      }
    }
  }

  return CountryModel(
    code: 'UN',
    name: 'Unknown',
    dialCode: '',
    flag: '🌐',
  );
}

/// Konversi 2-letter ISO code ke flag emoji regional indicator
/// Contoh: 'ID' → '🇮🇩', 'US' → '🇺🇸'
String getFlagEmoji(String isoCode) {
  if (isoCode.length != 2) return '🌐';

  final int base = 127397;
  String emoji = '';

  for (int i = 0; i < isoCode.length; i++) {
    emoji += String.fromCharCode(base + isoCode.codeUnitAt(i));
  }

  return emoji;
}
