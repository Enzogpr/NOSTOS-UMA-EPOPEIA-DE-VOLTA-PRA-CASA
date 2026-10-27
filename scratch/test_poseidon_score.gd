extends SceneTree
const Score := preload("res://Ato4_Tempestade/Gameplay/PoseidonScore.gd")
var checks := 0
var failures := 0
func check(value: bool, text: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(text)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var score:=Score.new()
	root.add_child(score)
	score.setup(false,true)
	score.set_process(false)
	score.start_entry()
	check(score.section=="intro" and score.absolute_time<0,"Entry is a separate lead-in to the traversal grid")
	score.advance(float(score.sections.intro.duration)+0.15)
	check(score.section=="surge" and absf(score.absolute_time-0.15)<0.0001,"Intro crosses to traversal without dropping its fractional remainder")
	score.advance(22.0)
	check(score.section=="surge" and score.absolute_time>22,"Loop repetitions do not rewind the absolute score clock")
	score.request_section("wrecks")
	var boundary:=score.pending_at
	check(is_equal_approx(fmod(boundary,score.beat_period*4),0.0) or absf(fmod(boundary,score.beat_period*4)-score.beat_period*4)<0.0001,"Section changes are on a bar boundary")
	var saved:=score.get_snapshot()
	score.advance(2)
	check(score.section=="wrecks" and score.section_elapsed<2,"New section starts at its downbeat without resetting the absolute time")
	score.set_frozen(true)
	var at:=score.absolute_time
	score.advance(5)
	check(score.absolute_time==at,"Failure freeze prevents music advancing under the retry panel")
	score.restore(saved)
	check(score.get_snapshot()==saved and not score.frozen,"Retry restores both clip position and queued musical transition")
	score.advance(2)
	check(score.section=="wrecks","Restored queued transition happens at the same bar")
	score.request_section("escape")
	score.advance(score.pending_at-score.absolute_time+0.01)
	var accents:=[]
	score.accent.connect(func(kind): accents.append(kind))
	score.advance(3.25)
	check(accents.is_empty(),"Wind cannot release before the measured cue")
	score.advance(0.03)
	check(accents==["wind_release"],"Wind cue fires exactly once after3.273")
	score.advance(20)
	check(not score.running and score.section_elapsed==16.35,"Final section finishes at its authored duration")
	score.advance(1)
	check(accents.size()==1,"Final cue cannot repeat after completion")
	score.queue_free()
	await process_frame
	# Exercise the actual mixer clock and a complete OGG loop, with silent driver.
	var real:=Score.new()
	root.add_child(real)
	real.setup(true,false)
	real.start_traversal()
	var monotonic:=true
	var last:=0.0
	for frame in 600:
		await create_timer(1.0/60).timeout
		monotonic=monotonic and real.absolute_time>=last
		last=real.absolute_time
	check(monotonic and real.absolute_time>float(real.sections.surge.duration)+0.1 and real.loops>=1,"Audio mixer clock stays continuous through a real Vorbis loop")
	var snapshot:=real.get_snapshot()
	real.restore(snapshot)
	await create_timer(0.12).timeout
	check(real.absolute_time>=float(snapshot.absolute) and real.absolute_time<float(snapshot.absolute)+0.3,"Actual decoder resumes the saved offset without replaying the whole phrase")
	real.stop_audio()
	check(not real.voices[0].playing and not real.voices[1].playing,"All owned voices stop on exit")
	real.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	print("SCORE_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
