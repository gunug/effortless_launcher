import 'korean_search.dart';

class IndexedApp {
  final String name;
  final String packageName;
  final bool isSystemApp;
  final String nameLower;
  final String chosung;
  final String qwerty;
  final String roman;
  final String packageLower;
  final String initials;

  IndexedApp({
    required this.name,
    required this.packageName,
    this.isSystemApp = false,
  })  : nameLower = name.toLowerCase(),
        chosung = extractChosung(name),
        qwerty = toQwerty(name),
        roman = romanize(name),
        packageLower = packageName.toLowerCase(),
        initials = extractInitials(name);
}

class DeletedApp {
  final String name;
  final String packageName;
  final int confirmedAt;

  const DeletedApp({
    required this.name,
    required this.packageName,
    required this.confirmedAt,
  });

  Map<String, dynamic> toJson() => {
        'n': name,
        'p': packageName,
        't': confirmedAt,
      };

  static DeletedApp fromJson(Map<String, dynamic> j) => DeletedApp(
        name: j['n'] as String,
        packageName: j['p'] as String,
        confirmedAt: (j['t'] as num).toInt(),
      );
}
