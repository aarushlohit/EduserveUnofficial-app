class VersionUtils {
  VersionUtils._();

  static bool isRemoteVersionNewer({
    required String installed,
    required String remote,
  }) {
    final installedParts = _parse(installed);
    final remoteParts = _parse(remote);
    final maxLen = installedParts.length > remoteParts.length
        ? installedParts.length
        : remoteParts.length;

    for (var i = 0; i < maxLen; i++) {
      final local = i < installedParts.length ? installedParts[i] : 0;
      final next = i < remoteParts.length ? remoteParts[i] : 0;
      if (next > local) return true;
      if (next < local) return false;
    }
    return false;
  }

  static List<int> _parse(String input) {
    return input
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }
}
