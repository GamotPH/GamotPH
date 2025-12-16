// lib/data/adr_alias.dart

/// Maps descriptive / multilingual ADR phrases
/// into clean, clinical display labels.
///
/// IMPORTANT:
/// - Keys MUST be lowercase
/// - Values are the final display labels
const Map<String, String> adrAliasMap = {
  // ---- FEVER ----
  'mataas na temperatura ng katawan': 'Fever',
  'mataas ang temperatura ng katawan': 'Fever',
  'mataas ang init ng katawan': 'Fever',
  'mainit ang katawan': 'Fever',
  'nilalagnat': 'Fever',
  'lagnat': 'Fever',
  'fever': 'Fever',

  // ---- NAUSEA ----
  'feeling sick to your stomach': 'Nausea',
  'feeling sick in the stomach': 'Nausea',
  'sick to my stomach': 'Nausea',
  'parang nasusuka': 'Nausea',
  'nasusuka': 'Nausea',
  'nauseous': 'Nausea',
  'nausea': 'Nausea',

  // ---- VOMITING ----
  'pagsusuka': 'Vomiting',
  'sumusuka': 'Vomiting',
  'vomiting': 'Vomiting',

  // ---- DIZZINESS ----
  'nahihilo': 'Dizziness',
  'pagkahilo': 'Dizziness',
  'dizziness': 'Dizziness',

  // ---- STOMACH PAIN ----
  'sakit ng tiyan': 'Stomach pain',
  'sumasakit ang tiyan': 'Stomach pain',
  'stomach ache': 'Stomach pain',
  'stomach pain': 'Stomach pain',
};

String normalizeAdrAlias(String raw) {
  final t = raw.toLowerCase().trim();

  // -------- Fever --------
  if (t.contains('lagnat') ||
      t.contains('fever') ||
      t.contains('mataas na temperatura') ||
      t.contains('high temperature') ||
      t.contains('mainit ang katawan')) {
    return 'Fever';
  }

  // -------- Nausea --------
  if (t.contains('nausea') ||
      t.contains('nasusuka') ||
      t.contains('feeling sick') ||
      t.contains('walang gana kumain')) {
    return 'Nausea';
  }

  // -------- Vomiting --------
  if (t.contains('vomit') || t.contains('pagsusuka') || t.contains('sumuka')) {
    return 'Vomiting';
  }

  // -------- Dizziness --------
  if (t.contains('dizziness') ||
      t.contains('nahihilo') ||
      t.contains('pagkahilo') ||
      t.contains('vertigo')) {
    return 'Dizziness';
  }

  // -------- Headache --------
  if (t.contains('headache') ||
      t.contains('sakit ng ulo') ||
      t.contains('masakit ang ulo')) {
    return 'Headache';
  }

  // -------- Stomach pain --------
  if (t.contains('stomach pain') ||
      t.contains('abdominal pain') ||
      t.contains('sakit ng tiyan') ||
      t.contains('masakit ang tiyan')) {
    return 'Stomach pain';
  }

  // -------- Rash --------
  if (t.contains('rash') ||
      t.contains('pantal') ||
      t.contains('itch') ||
      t.contains('makati') ||
      t.contains('skin eruption')) {
    return 'Rash';
  }

  // -------- Swelling --------
  if (t.contains('swelling') || t.contains('namamaga') || t.contains('maga')) {
    return 'Swelling';
  }

  // -------- Fallback --------
  // Anything unmapped is NOT allowed as its own slice
  return 'Medical (Unmapped)';
}
