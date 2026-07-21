String getContactDisplayName({String? customName, required String username}) {
  if (customName != null && customName.trim().isNotEmpty) {
    return customName.trim();
  }
  final cleanUsername = username.startsWith('@')
      ? username.substring(1)
      : username;
  return '@$cleanUsername';
}

const Map<String, String> localContactAliases = {
  'alice_vybin': 'Abdulahad',
  'bob_d': 'Bro',
  'charlie_b': 'Hanzala Abid',
};
