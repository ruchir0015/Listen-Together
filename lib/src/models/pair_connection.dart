class PairConnection {
  const PairConnection({
    required this.pairId,
    required this.deviceId,
    required this.createdAt,
  });

  final String pairId;
  final String deviceId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'pairId': pairId,
      'deviceId': deviceId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PairConnection.fromJson(Map<String, dynamic> json) {
    return PairConnection(
      pairId: json['pairId'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
