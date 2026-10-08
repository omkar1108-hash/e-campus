/// Runtime configuration.
///
/// Secrets are injected at build time so they never get committed:
///   flutter run --dart-define=GEMINI_API_KEY=AIza...
class AppConfig {
  const AppConfig._();

  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Override with --dart-define=GEMINI_MODEL=... if Google renames models.
  static const geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );

  static const departments = <String>[
    'MCA',
    'MBA',
    'Computer Science',
    'Mechanical',
    'Civil',
    'Electronics',
  ];
}
