abstract class RingtoneState {
  const RingtoneState();
}

class RingtoneInitial extends RingtoneState {
  const RingtoneInitial();
}

class RingtoneLoading extends RingtoneState {
  const RingtoneLoading();
}

class RingtoneLoaded extends RingtoneState {
  final List<Map<String, String>> ringtones;
  final int? playingIndex;

  const RingtoneLoaded({
    required this.ringtones,
    this.playingIndex,
  });

  RingtoneLoaded copyWith({
    List<Map<String, String>>? ringtones,
    int? playingIndex,
  }) => RingtoneLoaded(
    ringtones: ringtones ?? this.ringtones,
    playingIndex: playingIndex,
  );
}

class RingtoneError extends RingtoneState {
  final String message;
  const RingtoneError(this.message);
}

class RingtonePlaying extends RingtoneState {
  final int index;
  const RingtonePlaying(this.index);
}

class RingtoneStopped extends RingtoneState {
  const RingtoneStopped();
}
