class MinuteItem {
  int minute; // 0-59
  int idBase; // unique base id for this minute item
  String? ringtoneUri;
  String? ringtoneTitle;
  String? remark; // user note for this alarm

  MinuteItem({
    required this.minute,
    required this.idBase,
    this.ringtoneUri,
    this.ringtoneTitle,
    this.remark,
  });

  Map<String, dynamic> toJson() => {
    'minute': minute,
    'idBase': idBase,
    'ringtoneUri': ringtoneUri,
    'ringtoneTitle': ringtoneTitle,
    'remark': remark,
  };

  static MinuteItem fromJson(Map<String, dynamic> j) => MinuteItem(
    minute: j['minute'],
    idBase: j['idBase'],
    ringtoneUri: j['ringtoneUri'],
    ringtoneTitle: j['ringtoneTitle'],
    remark: j['remark'],
  );

  MinuteItem copyWith({
    int? minute,
    int? idBase,
    String? ringtoneUri,
    String? ringtoneTitle,
    String? remark,
  }) => MinuteItem(
    minute: minute ?? this.minute,
    idBase: idBase ?? this.idBase,
    ringtoneUri: ringtoneUri ?? this.ringtoneUri,
    ringtoneTitle: ringtoneTitle ?? this.ringtoneTitle,
    remark: remark ?? this.remark,
  );
}
