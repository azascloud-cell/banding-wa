class CountryModel {
  final String code;
  final String name;
  final String dialCode;
  final String flag;

  const CountryModel({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
  });

  @override
  String toString() => '$flag $name (+$dialCode)';
}
