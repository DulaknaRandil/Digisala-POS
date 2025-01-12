class PosId {
  final int? id;
  final String posId;
  final String status; // Add status field

  PosId({this.id, required this.posId, required this.status});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pos_id': posId,
      'status': status, // Include status in map
    };
  }

  factory PosId.fromMap(Map<String, dynamic> map) {
    return PosId(
      id: map['id'],
      posId: map['pos_id'],
      status: map['status'], // Map status
    );
  }
}
