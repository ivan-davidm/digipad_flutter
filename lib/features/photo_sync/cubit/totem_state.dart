abstract class TotemState {
  const TotemState();
}

class TotemIdle extends TotemState {
  const TotemIdle();
}

class TotemStarting extends TotemState {
  const TotemStarting();
}

class TotemActive extends TotemState {
  final String totemName;
  final List<String> connectedClientIds;
  final int photoCount;

  /// Nearby Connections advertising is up.
  final bool nearbyOk;

  /// `http://ip:port` URLs the LAN server can be reached on ("" list = LAN off).
  final List<String> lanHosts;

  /// LAN HTTP server port (0 = not running).
  final int lanPort;

  const TotemActive({
    required this.totemName,
    this.connectedClientIds = const [],
    this.photoCount = 0,
    this.nearbyOk = true,
    this.lanHosts = const [],
    this.lanPort = 0,
  });

  bool get lanOk => lanHosts.isNotEmpty;

  TotemActive copyWith({
    List<String>? connectedClientIds,
    int? photoCount,
    bool? nearbyOk,
    List<String>? lanHosts,
    int? lanPort,
  }) {
    return TotemActive(
      totemName: totemName,
      connectedClientIds: connectedClientIds ?? this.connectedClientIds,
      photoCount: photoCount ?? this.photoCount,
      nearbyOk: nearbyOk ?? this.nearbyOk,
      lanHosts: lanHosts ?? this.lanHosts,
      lanPort: lanPort ?? this.lanPort,
    );
  }
}

class TotemError extends TotemState {
  final String message;
  const TotemError(this.message);
}
