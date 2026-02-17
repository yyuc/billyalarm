import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:billyalarm/blocs/ringtone_event.dart';
import 'package:billyalarm/blocs/ringtone_state.dart';

const MethodChannel _native = MethodChannel('billyalarm/native');

class RingtoneBloc extends Bloc<RingtoneEvent, RingtoneState> {
  RingtoneBloc() : super(const RingtoneInitial()) {
    on<LoadRingtones>(_onLoadRingtones);
    on<PlayRingtone>(_onPlayRingtone);
    on<StopRingtone>(_onStopRingtone);
  }

  Future<void> _onLoadRingtones(LoadRingtones event, Emitter<RingtoneState> emit) async {
    emit(const RingtoneLoading());
    try {
      final res = await _native.invokeMethod('getRingtones');
      final List list = res as List? ?? [];
      final ringtones = list.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
      emit(RingtoneLoaded(ringtones: ringtones));
    } catch (e) {
      emit(RingtoneError('Failed to load ringtones: $e'));
    }
  }

  Future<void> _onPlayRingtone(PlayRingtone event, Emitter<RingtoneState> emit) async {
    try {
      await _native.invokeMethod('playRingtone', {'uri': event.uri});
      emit(RingtonePlaying(0)); // Placeholder index
    } catch (e) {
      emit(RingtoneError('Failed to play ringtone: $e'));
    }
  }

  Future<void> _onStopRingtone(StopRingtone event, Emitter<RingtoneState> emit) async {
    try {
      await _native.invokeMethod('stopRingtone');
      emit(const RingtoneStopped());
      // Restore loaded state
      if (state is RingtoneStopped) {
        add(const LoadRingtones());
      }
    } catch (e) {
      emit(RingtoneError('Failed to stop ringtone: $e'));
    }
  }
}
