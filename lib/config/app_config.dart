/// Runtime configuration.
///
/// Secrets are injected at build time so they never get committed:
///   flutter run --dart-define=OPENAI_API_KEY=sk-...
class AppConfig {
  const AppConfig._();

  static const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const openAiModel = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-4o-mini',
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
