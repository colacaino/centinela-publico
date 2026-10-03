const estadosPushActivos = {'CREATED', 'NOTIFIED'};

int notificationId(String incidentId) {
  var hash = 0x811c9dc5;
  for (final unit in incidentId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

bool pushVigente(Map<String, dynamic> data, {DateTime? now}) {
  if (data['schemaVersion']?.toString() != '2' ||
      data['incidentId']?.toString().isEmpty != false) {
    return false;
  }
  final expires = int.tryParse(data['expiresAtMillis']?.toString() ?? '');
  final created = int.tryParse(data['createdAtMillis']?.toString() ?? '');
  if (expires == null || created == null || expires <= created) return false;
  final current = (now ?? DateTime.now()).millisecondsSinceEpoch;
  return current < expires &&
      estadosPushActivos.contains(data['estado']?.toString());
}
