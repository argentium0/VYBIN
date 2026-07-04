/// Helper function to format contact display name according to VYBIN hierarchy specifications:
/// - If a customName (alias) is set, return it.
/// - Otherwise, return the username formatted with an '@' prefix.
String getContactDisplayName({
  String? customName,
  required String username,
}) {
  if (customName != null && customName.trim().isNotEmpty) {
    return customName.trim();
  }
  final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
  return '@$cleanUsername';
}

/// Simulated local contact database mapping contact UIDs to custom aliases.
const Map<String, String> localContactAliases = {
  'alice_vybin': 'Abdulahad',
  'bob_d': 'Bro',
  'charlie_b': 'Hanzala Abid',
};
