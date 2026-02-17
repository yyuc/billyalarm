abstract class RingtoneEvent {
  const RingtoneEvent();
}

class LoadRingtones extends RingtoneEvent {
  const LoadRingtones();
}

class PlayRingtone extends RingtoneEvent {
  final String uri;
  const PlayRingtone(this.uri);
}

class StopRingtone extends RingtoneEvent {
  const StopRingtone();
}
