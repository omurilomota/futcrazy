class_name Sfx
extends Node

## Áudio do jogo: pool de AudioStreamPlayers para efeitos + torcida em loop.
## Os .wav são gerados por tools/gen_audio.py (síntese, nenhum asset externo).

const SOUND_IDS := [
	"kick", "hit", "bounce", "whoosh", "whistle", "goal", "event", "beep", "ui",
]
const POOL_SIZE := 14

var streams: Dictionary = {}
var crowd: AudioStreamPlayer

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _intensity := 0.3
var _target := 0.3
var _crowd_db := -60.0


func _ready() -> void:
	_rng.randomize()

	for id in SOUND_IDS:
		var path := "res://assets/audio/%s.wav" % id
		if ResourceLoader.exists(path):
			streams[id] = load(path)

	for i in POOL_SIZE:
		var ap := AudioStreamPlayer.new()
		ap.bus = "Master"
		add_child(ap)
		_pool.append(ap)

	_start_crowd()


func _start_crowd() -> void:
	var path := "res://assets/audio/crowd.wav"
	if not ResourceLoader.exists(path):
		return
	var st := load(path) as AudioStreamWAV
	if st == null:
		return
	# loop em frames, direto no recurso importado
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(round(st.get_length() * float(st.mix_rate)))

	crowd = AudioStreamPlayer.new()
	crowd.stream = st
	crowd.volume_db = -60.0
	add_child(crowd)
	crowd.play()


## Toca um efeito. pitch é multiplicado por uma variação leve para não repetir igual.
func play(id: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(id) or _pool.is_empty():
		return
	var ap := _pool[_next]
	_next = (_next + 1) % _pool.size()
	ap.stream = streams[id]
	ap.volume_db = vol_db
	ap.pitch_scale = clampf(pitch * _rng.randf_range(0.96, 1.05), 0.4, 2.4)
	ap.play()


## 0 = estádio tenso/quieto, 1 = gol, todo mundo gritando.
func set_intensity(v: float) -> void:
	_target = clampf(v, 0.0, 1.0)


func intensity() -> float:
	return _intensity


func _process(delta: float) -> void:
	_intensity = move_toward(_intensity, _target, delta * 0.9)
	if crowd == null:
		return
	var db := lerpf(-30.0, -11.0, _intensity)
	_crowd_db = move_toward(_crowd_db, db, delta * 26.0)
	crowd.volume_db = _crowd_db
