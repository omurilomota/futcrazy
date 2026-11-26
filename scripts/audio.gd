class_name Sfx
extends Node

## Audio do jogo: pool de AudioStreamPlayers para efeitos + torcida em loop.
## Os .wav sao gerados por tools/gen_audio.py (sintese, nenhum asset externo).
##
## Buses: `SFX` (efeitos) e `Ambience` (torcida), ambos enviando para `Master`.
## Os volumes vem do gerenciador central (Settings), entao os sliders da tela de
## opcoes realmente controlam o que toca.
##
## Encerramento: `shutdown()` para todo playback, solta as referencias de stream e
## limpa o dicionario. Sem isso o AudioServer mantem AudioStreamWAV/PlaybackWAV vivos
## e o Godot reporta vazamento ao sair (issue P0).

const SOUND_IDS := [
	"kick", "hit", "bounce", "whoosh", "whistle", "goal", "event", "beep", "ui",
	"slide", "moon", "rumble", "squeak",
]
const POOL_SIZE := 14
const CROWD_PATH := "res://assets/audio/crowd.wav"

var streams: Dictionary = {}
var crowd: AudioStreamPlayer

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _intensity := 0.3
var _target := 0.3
var _crowd_db := -60.0
var _shutdown := false


func _ready() -> void:
	_rng.randomize()

	for id in SOUND_IDS:
		var path := "res://assets/audio/%s.wav" % id
		if ResourceLoader.exists(path):
			streams[id] = load(path)

	for i in POOL_SIZE:
		var ap := AudioStreamPlayer.new()
		ap.bus = GameSettings.BUS_SFX
		ap.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ap)
		_pool.append(ap)

	_start_crowd()


func _start_crowd() -> void:
	if not ResourceLoader.exists(CROWD_PATH):
		return
	var base := load(CROWD_PATH) as AudioStreamWAV
	if base == null:
		return
	# duplica o recurso: mexer no loop do cache importado vazaria estado entre cenas
	var st := base.duplicate() as AudioStreamWAV
	if st == null:
		st = base
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(round(st.get_length() * float(st.mix_rate)))

	crowd = AudioStreamPlayer.new()
	crowd.stream = st
	crowd.bus = GameSettings.BUS_AMBIENCE
	crowd.volume_db = -60.0
	crowd.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(crowd)
	crowd.play()


## Toca um efeito. pitch e multiplicado por uma variacao leve para nao repetir igual.
func play(id: String, vol_db := 0.0, pitch := 1.0) -> void:
	if _shutdown or not streams.has(id) or _pool.is_empty():
		return
	var ap := _pool[_next]
	_next = (_next + 1) % _pool.size()
	ap.stream = streams[id]
	ap.volume_db = vol_db
	ap.pitch_scale = clampf(pitch * _rng.randf_range(0.96, 1.05), 0.4, 2.4)
	ap.play()


## 0 = estadio tenso/quieto, 1 = gol, todo mundo gritando.
func set_intensity(v: float) -> void:
	_target = clampf(v, 0.0, 1.0)


func intensity() -> float:
	return _intensity


func _process(delta: float) -> void:
	_intensity = move_toward(_intensity, _target, delta * 0.9)
	if crowd == null or not crowd.playing:
		return
	var db := lerpf(-30.0, -11.0, _intensity)
	_crowd_db = move_toward(_crowd_db, db, delta * 26.0)
	crowd.volume_db = _crowd_db


## Encerra tudo e solta as referencias. Seguro para chamar mais de uma vez.
func shutdown() -> void:
	if _shutdown:
		return
	_shutdown = true
	set_process(false)

	for ap in _pool:
		if is_instance_valid(ap):
			ap.stop()
			ap.stream = null
	_pool.clear()

	if crowd != null and is_instance_valid(crowd):
		crowd.stop()
		crowd.stream = null
	crowd = null
	streams.clear()


func _exit_tree() -> void:
	shutdown()
