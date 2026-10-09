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

  // ---- Opening page ---------------------------------------------------
  // Shown before sign-in. Change these to the college's real details.
  static const collegeName = String.fromEnvironment(
    'COLLEGE_NAME',
    defaultValue: 'Aditya Institute of Management Technology and Research',
  );
  static const collegeTagline = 'One app for classes, library, buses and more';
  static const contactEmail = String.fromEnvironment(
    'COLLEGE_EMAIL',
    defaultValue: 'office@your-college.edu',
  );
  static const contactPhone = String.fromEnvironment(
    'COLLEGE_PHONE',
    defaultValue: '+91 00000 00000',
  );
  static const contactAddress = String.fromEnvironment(
    'COLLEGE_ADDRESS',
    defaultValue: 'Add the college address in lib/config/app_config.dart',
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
