/*
(This file is a Script resource inside the GameMaker project)

this file gives gml contents to every fmod function the pizza tower switch port (v1.0.5952 SR 5) uses. this makes pizza tower's sound logic become entirely gml, allowing the game to be more easily ported to other platforms. 
by the popular demand of two (2) people, here's a public version with some comments.
you may do whatever you want with it, as per the repository's license. credit would be nice though.

some important information:

from what i've learned from this game, fmod does not have sounds, but sound "events"
events have an associated "sound list", and can play any one of them. you can also pass parameters to them that have some effect on the sound(s).
what this file does is replace this fmod event type with my own fmod_sound type.
the game still calls all the fmod functions but they all direct to here since it's been removed,
and now all the fmod functions now operate on the fmod_sound type.

defining the sound list for each event would've been exhausting. so what i've opted to do is: 
1. get a list of all the sound event names the game ever uses by going over all the strings in the code files with a Python script
2. mod the original steam game to play every event, for 8 seconds, recording it, and then correctly matching up each sound recording to a name which is just the event name using audacity
3. when looking for the sound list for an event without a manual definition, it looks for the sound file with the event's name, and creates a sound list of length 1 with it
4. when looking for the fmod_sound struct implementation of an event without a manual definition, it creates an fmod event which plays a random sound out of its sound list

these steps cover every single sound event in pizza tower that only simply plays a sound, and there are a lot.

the rest, however, have been defined manually. for example, the barrel bump sound event can play one of 7 sound files! using this method, the random sound that was recorded will get played, and none of the other 6. 
so i had to manually take those files out from the fmod bank and place them in the port. all the music tracks were manually defined as well because it would be silly to record all of them.
to anyone who wants to use this script, i leave replicating this task up to you :) 
(or you could also dump the sounds from the port if you know how, i don't mind)

about the structs:

fmod_sound:
the replacement for fmod events. each has a sound list, which is every sound that it could possibly play,
information about the gain and pitch, looping and such. some may have statefuncs, which are functions that are called
when the game tries to change the state of an event, stepfuncs, which are run on every frame by soundwatchers (see below),
otherfuncs, for anytime the game tries to change a variable that isn't state (very rare), and stopfuncs, which run when the sound is stopped.
these allow you to customize an fmod_sound easily to mimic what the original fmod event does.
there are several functions at the bottom which return "preset" fmod sounds for music,
since most of the music events are just "play an intro section and then loop this bit" like john gutter (except, in this specific case, it was defined before i made the function, so john gutter doesn't use it)
or "switch the song when the state is changed" like pizzascape.

audiostoppers:
audiostoppers fade out sounds and eventually stop/pause them. handled in obj_fmod step.

soundwatchers:
soundwatchers make sounds loop (should probably use the new gamemaker functionality for looping instead!)
and also make them run step functions. handled in obj_fmod step as well.
they are also capable of destroying sound structs when they're done playing, and this functionality is used for one shot (fire & forget) sounds.

additional notes:

* print() just leads to show_debug_message, i had a custom function for it since calling it a lot really lags gamemaker for some reason so i could easily empty the function to test the game without lag spikes.

* i did not realize the scope needed to replace fmod for this game,
and that should be a satisfactory answer to why i do x in this specific way

* i modified random parts of the pizza tower source code to make specific sounds behave.
over time, some of these changes may have become obsolete due to me refining the code,
but do not expect this to just work without any modifications

* this file might have references to other functions or variables or whatever used in the port i'm too lazy to include those figure it out

* if you have any questions open an issue on this repository. you could also post bug reports there for the port. i am looking.

* by the way. i do not randomly post .nsp links on 4chan when releasing ports, and i have never used the hard-r, like the guy claiming to be me on there. you're really weird.

11/11/2023:
* in retrospect, this code is very bad. but it should still have its uses.

happy porting,
-D
*/
function fmod_init(num) {
	global.sounds_to_play = ds_list_create()
	if !audio_group_is_loaded(audiogroup_sfx)
		audio_group_load(audiogroup_sfx);
	if !audio_group_is_loaded(audiogroup_special)
		audio_group_load(audiogroup_special);
	__global_object_depths()
	global.d_hub = 0	
	global.musicmuffle = false;
	global.pillarfade = 0;
	global.pillarmult = 1
	global.totemfade = 0
	global.totemmult = 1;
	
	global.clones = 0;
	global.clonemult = 1;
	
	global.fmod_pause_frame = false // set to true when pausing in the port 
}

function d_get_fmod_name(str) {
	return string_replace(str, "event:/", "")
}

function add_audiostopper(_sound, _deathtime, _pause = false) {
	audio_sound_gain(_sound, 0, _deathtime * (1000 / 60))
	var s = {
		sound : _sound,
		deathtime : _deathtime + global.frame,
		pause : _pause
	}
	ds_list_add(obj_fmod.audiostoppers, s)
}

// i found this emitter to be good for basically all sounds
function fmod_emitter() {
	var e = audio_emitter_create()	
	audio_emitter_falloff(e, 300, 700, 1)
	return e;
}


function change_soundwatcher_loop_points(new_points, _soundwatcher = soundwatcher) {
	if !is_struct(_soundwatcher)
		return;
	loop_points = new_points
	_soundwatcher.loop_points = new_points
}

function add_soundwatcher(points, func, _looping, sndstruct = noone) {
	
	var s = 
	{
		loop_points : points,
		sound : noone,
		stepfunc : func,
		struct : sndstruct,
		looping : _looping,
		last_time_point : 0,
		fail_count : 0,
		released : false
	}
	ds_list_add(obj_fmod.soundwatchers, s)
	return s;
	
}
function change_soundwatcher_sound(sound, _soundwatcher = soundwatcher) {
	if !is_struct(_soundwatcher)
		return;
	_soundwatcher.sound = sound
}


function fmod_sound_default_stop() {
	t_state = -1
	t_anyvar1 = -1
}

function fmod_sound_destroy() {
	if is_struct(soundwatcher)
		soundwatcher.released = true
	
	ds_list_destroy(sound_instances)
	if emitter != noone
		audio_emitter_free(emitter)
		
	released = true

}

function fmod_sound(_soundlist, _randomsnd = false, _pitch = 1, _pitch_vary = 0, _looping = false, _loop_points = noone, _only_playfunc = false, _playfunc = noone, _statefunc = noone, _stepfunc = noone, _otherfunc = noone, _stopfunc = noone) 
	constructor {
	soundlist = _soundlist
	randomsnd = _randomsnd
	looping = _looping
	emitter = noone
	// gamemaker has garbage collection and so this struct will not get destroyed until the object dereferences it or gets destroyed itself (automatically dereferencing everything it was holding)
	// we set this variable to true in fmod_sound_destroy() and it will exit any function attempted on this struct if it's true
	released = false 
	
	number = global.createnumber // for debugging
	
	// values prefixed with _t reset on fmod_sound_default_stop
	sndgain = 1 // too late to add this as a parameter :)
	loop_points = _loop_points
	only_playfunc = _only_playfunc
	pitch_vary = _pitch_vary
	pitch = _pitch
	// these values get updated with the state parameter after the statefunc is run
	state = -1
	t_state = -1

	// general purpose variables. i gave it a number because i thought i would need more.
	anyvar1 = -1
	t_anyvar1 = -1
	
	fadeout = 90 // how long to fade the sound for, in frames
	delay = 0;
	
	statefunc = _statefunc = noone ? noone : method(self, _statefunc)
	otherfunc = _otherfunc = noone ? noone : method(self, _otherfunc)
	playfunc = _playfunc = noone ? noone : method(self, _playfunc) 
	stepfunc = _stepfunc = noone ? noone : method(self, _stepfunc) 
	stopfunc = _stopfunc = noone ? method(self, fmod_sound_default_stop) : method(self, _stopfunc) 
	soundwatcher = noone
	if _loop_points != noone or stepfunc != noone  // if without a step function put [-1, -1] in loop_points to create the soundwatcher without any real loop points
		create_soundwatcher = true
	else
		create_soundwatcher = false
	
	sound_instances = ds_list_create();
	ds_list_clear(sound_instances)
	change_loop_points = method(self,  change_soundwatcher_loop_points)
	change_loop_sound = method(self,  change_soundwatcher_sound)
	destroy = method(self, fmod_sound_destroy)
}

function fmod_sound_3d(_soundlist, _randomsnd = false, _pitch = 1, _pitch_vary = 0, _looping = false, _loop_points = noone, _only_playfunc = false, _playfunc = noone, _statefunc = noone, _stepfunc = noone, _otherfunc = noone, _stopfunc = noone) 
	: fmod_sound(_soundlist, _randomsnd, _pitch, _pitch_vary, _looping, _loop_points, _only_playfunc, _playfunc, _statefunc, _stepfunc, _otherfunc, _stopfunc) 
	constructor {
		
	emitter = fmod_emitter()
}

function play_sound(soundasset, looping, pitch) {
	if emitter == noone
		return audio_play_sound(soundasset, 10, looping, sndgain, 0, pitch);
	return audio_play_sound_on(emitter, soundasset, looping, 10, sndgain, 0, pitch);
		
}

function fmod_event_instance_play(snd) {
	with (snd) {
		if released
			return;
		if create_soundwatcher {
			soundwatcher = add_soundwatcher(loop_points, stepfunc, looping)
			create_soundwatcher = false	
		}
	}
	ds_list_add(global.sounds_to_play, snd)
}
	
function fmod_event_instance_stop(snd, instant = true, keep_soundwatcher = false) {
	if is_string(snd) {
		var soundlist = d_get_soundlist(d_get_fmod_name(snd))
		if instant == true {
			for (var i = 0; i < array_length(soundlist); i++)  
				audio_stop_sound(soundlist[i])
		}
		else {
			for (var i = 0; i < array_length(soundlist); i++) 
				add_audiostopper(soundlist[i], 90)
		}
		return;
	}
	with (snd) {
		if released
			return;

		var ind = ds_list_find_index(global.sounds_to_play, snd)
		if ind != -1 
			ds_list_delete(global.sounds_to_play, ind)
		
		var len = ds_list_size(sound_instances)
		if len == 0
			return;
		
		if instant == true {
			for (var i = 0; i < len; i++) 
				audio_stop_sound(sound_instances[| i])
		}
		else {
			for (var i = 0; i < len; i++)  
				add_audiostopper(sound_instances[| i], fadeout)
		}
		if stopfunc != noone
			stopfunc()
			
		ds_list_clear(sound_instances)
		if is_struct(soundwatcher) and !keep_soundwatcher {
			soundwatcher.released = true;	
			create_soundwatcher = true
		}

	}	
}

function fmod_event_one_shot(str) {
	var snd = fmod_event_create_instance(str)
	with (snd) {
		if !is_struct(soundwatcher)
			soundwatcher = add_soundwatcher([-1, -1], noone, looping, self) // see comment in the soundwatchers' for loop
		else
			soundwatcher.struct = self
	}
	fmod_event_instance_play(snd)
	return snd;
}
function fmod_event_one_shot_3d(str, _x = x, _y = y) {
	var snd = fmod_event_one_shot(str)
	with (snd) {
		if emitter != noone
			audio_emitter_position(emitter, _x, _y, 0)
	}
}

function fmod_event_instance_set_parameter(snd, somestring, somenum, someboolean) {
	with snd {
		if released
			return;
		switch (somestring) {
			case "state":
				if statefunc != noone and somenum != state
					statefunc(somenum);
				state = somenum
				t_state = somenum
				break;
			default:
				if otherfunc != noone
					otherfunc(somenum);	
		}
	}
}

function fmod_event_instance_get_parameter(snd, somestring) {
	with snd {
		switch (somestring) {
			case "state":
				return state;
			default:
				print("No parameter!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
		}
	}
}

function fmod_event_instance_release(snd) {
	with (snd) {
		if released
			return;
		destroy();
	}
	delete snd
}
function fmod_event_instance_set_3d_attributes(snd, _x, _y) {
	with (snd) {
		if released
			return;
		if emitter != noone
			audio_emitter_position(emitter, _x, _y, 0)
	}
}
function fmod_event_instance_is_playing(snd) {
	if is_string(snd) {
		var soundlist = d_get_soundlist(d_get_fmod_name(snd))
		for (var i = 0; i < array_length(soundlist); i++)  {
			if audio_is_playing(soundlist[i]) 
				return true;
		}
		return false;
	}
	with (snd) {
		if released
			return false;
		
		var ind = ds_list_find_index(global.sounds_to_play, snd)
		if ind != -1 
			return true;
			
		var len = ds_list_size(sound_instances)
		if len == 0
			return false
	
		for (var i = 0; i < len; i++) {
			if audio_is_playing(sound_instances[| i]) 
				return true;
		}
		

		
	}	
	return false;
}

function fmod_event_instance_set_paused(snd, paused) {
	with (snd) {
		if released
			return;
		if paused {
			for (var i = 0; i < ds_list_size(sound_instances); i++)
				audio_pause_sound(sound_instances[| i])	
		}
		else {
			for (var i = 0; i < ds_list_size(sound_instances); i++) 
				audio_resume_sound(sound_instances[| i])
		}
	}
}

function fmod_event_instance_get_paused(snd) {
	with (snd) {
		if released
			return false;
		for (var i = 0; i < ds_list_size(sound_instances); i++) {
			if audio_is_paused(sound_instances[| i])
				return true;
		}
		return false;
	}
	return false;
}




function fmod_set_num_listeners(num) {
	
}
function fmod_bank_load(something, thing) {
}

function fmod_set_parameter(somestring, somenum, someboolean) {
	switch (somestring) {
		case "musicmuffle":
			global.musicmuffle = somenum;
			break;
		case "pillarfade":
			global.pillarfade = somenum;
			break;
		case "totem":
			global.totemfade = somenum;
			break;
		case "clones":
			global.clonemult = 1 - somenum
			break;
	}
}

function fmod_set_listener_attributes(x_1, y_2, somenum) {
	
}


function fmod_event_instance_get_timeline_pos(snd) {
	with (snd) {
		if released
			return 0;
		for (var i = 0; i < ds_list_size(sound_instances); i++) {
			if audio_is_playing(sound_instances[| i])
				return audio_sound_get_track_position(sound_instances[| i]);
		}
	}
	return 0;
}

function fmod_event_instance_set_timeline_pos(snd, time) {
	with (snd) {
		if released
			return;
		for (var i = 0; i < ds_list_size(sound_instances); i++) {
			if audio_is_playing(sound_instances[| i]) 
				audio_sound_set_track_position(sound_instances[| i], time)
		}
	}
}


function fmod_update() {
	// there is a small period between playing a sound and calling the pause function on that sounds where it will be ignored.
	// to fix this, if we need to pause a sound that is played on the pause frame, it is added to these arrays, and paused in two frames. yes, 1 was not enough.
	// what happens if we pause a frame after a sound has played? i don't know!
	static events_to_pause = []
	static sounds_to_pause = []
	audio_group_set_gain(audiogroup_sfx, global.option_sfx_volume * global.option_master_volume, 0)
	
	var mufflemult = (global.musicmuffle == 0) ? 1 : 0.15
	global.pillarmult = Approach(global.pillarmult, global.pillarfade, 0.03)
	global.totemmult = Approach(global.totemmult, global.totemfade * 0.5, 0.05)
	
	var vol = global.option_music_volume * global.option_master_volume * mufflemult * (1-global.totemmult) 
	audio_group_set_gain(audiogroup_default, vol * (1 - global.pillarmult), 0)
	audio_group_set_gain(audiogroup_special, vol * global.pillarmult, 0)
	
	var elen = array_length(events_to_pause);
	for (var i = 0; i < elen; i++) {
		var s = events_to_pause[i]
		s.time--;
		if s.time == 0 {
			fmod_event_instance_set_paused(s.event, true)	
			array_delete(events_to_pause, i, 1)
			elen--;
			i--;	
		}
	}
		
	var slen = array_length(sounds_to_pause);
	for (var i = 0; i < slen; i++) {
		var s = sounds_to_pause[i]
		s.time--;
		if s.time == 0 {
			audio_pause_sound(s.sound)	
			array_delete(sounds_to_pause, i, 1)
			slen--;
			i--;
		}
	}

	var len = ds_list_size(global.sounds_to_play)
	for (var i = 0; i < len; i++) {
		var snd = global.sounds_to_play[| i]
		with (snd) {
			if released {
				ds_list_delete(global.sounds_to_play, i)
				len--
				i--
				continue;
			}
			if delay != 0 {
				delay--
				continue
			}
			print(string(snd.number) + " played")
			var playingsound = noone;
			if !(only_playfunc and playfunc != noone) {
				var arrlen = array_length(soundlist)
				if randomsnd == false {
					for (var j = 0; j < arrlen; j++) {
						playingsound = play_sound(soundlist[j], looping, pitch + random_range(-pitch_vary, pitch_vary))
						ds_list_add(sound_instances, playingsound)
						if global.fmod_pause_frame
							array_push(sounds_to_pause, { sound : playingsound, time : 2 })
					}
			
				}
				else {
					var playind = (arrlen == 1) ? 0 : irandom_range(0, arrlen - 1)
					playingsound = play_sound(soundlist[playind], looping, pitch + random_range(-pitch_vary, pitch_vary))
					ds_list_add(sound_instances, playingsound)	
					if global.fmod_pause_frame
						array_push(sounds_to_pause, { sound : playingsound, time : 2 })
				}

			}
			if is_struct(soundwatcher) and playingsound != noone 
				change_loop_sound(playingsound)
			if playfunc != noone {
				playfunc(playingsound);
				if only_playfunc and global.fmod_pause_frame {
					array_push(events_to_pause, { event : snd, time : 2 } )
				}
			}
			ds_list_delete(global.sounds_to_play, i)
			len--
			i--
		}
	}
	global.fmod_pause_frame = false

}

function fmod_event_get_length(str) {
	soundlist = d_get_soundlist(d_get_fmod_name(str))
	var num = 1
	for (var i = 0; i < array_length(soundlist); i++) {
		if audio_sound_length(soundlist[i])	> num 
			num = audio_sound_length(soundlist[i])
	}
	return num;
}

function fmod_event_instance_set_paused_all(paused) {
	if paused
		audio_pause_all()
	else
		audio_resume_all()
}

function fmod_destroy() {
	
}


function d_get_soundlist(soundname) { 
	switch (soundname) {
		case "sfx/misc/clotheswitch":
			return [switch1]
		case "sfx/ui/fileselect":
			return [FileSelect1, FileSelect2, FileSelect3]
		case "sfx/ui/select":
			return [MenuSelect1, MenuSelect2, MenuSelect3]
		case "sfx/pep/mach":
			return [sfx_mach1, sfx_mach2, sfx_mach3, sfx_mach4]
		case "sfx/voice/myea":
			return [Voice_18, Voice_19, Voice_20, Voice_21]
		case "sfx/voice/hurt":
			return [Voice_10, Voice_11]
		case "sfx/voice/transfo":
			return [Voice_14, Voice_22, Voice_23]
		case "sfx/voice/outtransfo":
			return [Voice_12, Voice_18, Voice_19]
		case "sfx/voice/gushurt":
			return [Voice_01, Voice_02]
		case "sfx/voice/brickok":
			return [BrickSniff1, BrickSniff2, BrickSniff3]
		case "sfx/voice/gusok":
			return [Voice_04, Voice_05, Voice_06, Voice_07, Voice_08, Voice_09]
		case "sfx/voice/pizzagranny":
			return [PizzaGranny1, PizzaGranny2, PizzaGranny3]
		case "sfx/pep/punch":
			return [sfx_punch]
		case "sfx/pep/superjump":
			return [sfx_superjumpprep, sfx_superjumphold, sfx_superjumprelease]
		case "sfx/misc/breakblock":
			return [sfx_breakblock1, sfx_breakblock2]
		case "sfx/hub/gusbrickfightball":
			return [sfx_enemies_killingblow, sfx_punch]
		case "sfx/pep/uppercut":
			return [uppercut2]
		case "sfx/enemies/tribaldance":
			return [TRIBALDANCE]
		case "sfx/pep/step":
			return [sfx_step]
		case "sfx/misc/versusscreen":
			return [boss_introduction]
		case "sfx/ratmount/mach":
			return [ratmount1, ratmount2air, ratmount2]
		case "sfx/ratmount/groundpound":
			return [ratmountgroundpound]
		case "sfx/misc/golfjingle":
			return [JINGLE_0, JINGLE_1, JINGLE_2, JINGLE_3]
		case "sfx/voice/mrstick":
			return[MrStick1, MrStick4, MrStick5]
		case "sfx/voice/mrsticklaugh":
			return[MrStick2, MrStick3]
		case "sfx/voice/enemyrarescream":	
			return [enemyrarescream, enemyrarescream2]
		case "sfx/barrel/bump":
			return [barrelbump1, barrelbump2, barrelbump3, barrelbump4, barrelbump5, barrelbump6, barrelbump7]
		case "sfx/voice/pig":
			return [PigOink1, PigOink2, PigOink3]
		case "sfx/pep/tumble":
			return [sfx_tumble2, sfx_tumble3, sfx_tumble4]
		case "sfx/misc/mushroombounce":
			return [mushroom1, mushroom2, mushroom3] 
		case "sfx/pep/ghostspeed":
			return [GHOST_SPEED_0, GHOST_SPEED_1, GHOST_SPEED_2]
		case "sfx/misc/mrpinch":
			return [sfx_misc_mrpinch, mrpinch2]
		case "sfx/pipe/bump":
			return [pipebump1, pipebump2, pipebump3, pipebump4]
		case "sfx/fakepep/superjump":
			return [sfx_fakepep_superjump, fakepepsuperjump2]
		case "sfx/misc/toppingot":
			return [sfx_enemies_minijohnpunch]
		case "sfx/noise/fightball":
			return [noisefightball1, noisefightball2, noisefightball3, noisefightball4, noisefightball5, noisefightball6, noisefightball7, noisefightball8, noisefightball9] 
		case "sfx/voice/noisepositive":
			return [Noise3, Noise5, Noise2, Noise6]
		case "sfx/voice/noisenegative":
			return [Noise1, Noise4]
		case "sfx/voice/fakepeppositive":
			return [fakepeppositive1, fakepeppositive2, fakepeppositive3]
		case "sfx/voice/fakepepnegative":
			return [fakepepnegative1, fakepepnegative2]
		case "sfx/voice/pizzahead":
			return [pizzaheadlaugh_01, pizzaheadlaugh_02, pizzaheadlaugh_03, pizzaheadlaugh_04, pizzaheadlaugh_05, pizzaheadlaugh_06, pizzaheadlaugh_07, pizzaheadlaugh_08, pizzaheadlaugh_09]
		case "sfx/pep/slipbump":
			return [slipnslide1, slipnslide2, slipnslide3, slipnslide4, slipnslide5, slipnslide6, slipnslide7, slipnslide8]
		case "sfx/pep/slipend":
			return [slipnslideend, slipnslideend2, slipnslideend3]
		case "sfx/pizzaface/shower":
			return [pizzafaceshower1, pizzafaceshower2, pizzafaceshower3, pizzafaceshower4, pizzafaceshower5]
		case "sfx/pizzahead/finale":
			return [sfx_pizzahead_finale, sfx_misc_windloop]
		case "sfx/misc/hamkuff":
			return [hamkuff1, hamkuff2, hamkuff3]
		case "sfx/ui/comboup":
			return [sfx_ui_comboup, comboup1]
		case "sfx/misc/halloweenpumpkin":
			return [pumpkin]
		case "music/pillarmusic":
			return [mu_dungeondepth]
		case "music/intro":
			return [Pizza_Tower_OST___Time_for_a_Smackdown] 
		case "music/title":
			return [mu_title, lario_s_secret, fnaf2_secret]
		case "music/tutorial":
			return [mu_funiculi]
		case "music/pizzatime":
			return [mu_pizzatime, sfx_enemies_johndead, mu_chase, Pillar_Johns_Revenge]
		case "music/hub":
			return [mu_hub, Pizza_Tower_OST___Tuesdays, mu_hub3, pizza_tower___industrial_hub, mu_hub4]
		case "music/w1/entrancetitle":
			return [entrance]
		case "music/w1/entrance": 
			return [Unearthly_Blues]
		case "music/w1/entrancesecret": 
			return [Pizza_Tower___Entrance_Secret_V1]
		case "music/w1/medievaltitle":
			return [medieval]
		case "music/w1/medieval": 
			return [mu_medievalentrance, Pizza_Tower_OST___Cold_Spaghetti]
		case "music/w1/medievalsecret": 
			return [mu_medievalsecret]
		case "music/w1/ruintitle":
			return [ruin]
		case "music/w1/ruin":
			return [mu_ruin, mu_ruinremix]
		case "music/w1/ruinsecret":
			return [mu_ruinsecret]
		case "music/w1/dungeontitle":
			return [dungeon]
		case "music/w1/dungeon":
			return [Pizza_Tower___Dungeon_Freakshow_v222]
		case "music/w1/dungeonsecret":
			return [mu_dungeonsecret]
		case "music/w2/deserttitle":
			return [oregano]
		case "music/w2/desert":
			return [mu_desert, mu_ufo]
		case "music/w2/desertsecret":
			return [mu_desertsecret]
		case "music/w2/saloontitle":
			return [saloon]
		case "music/w2/saloon":
			return [mu_saloon]
		case "music/w2/saloonsecret":
			return [mu_saloonsecret]
		case "music/w2/farmtitle":
			return [mort_farm]
		case "music/w2/farm":
			return [mu_farm, Pizza_Tower___Whats_on_the_Kids_Menu]
		case "music/w2/farmsecret":
			return [mu_farmsecret]
		case "music/w2/graveyardtitle":
			return [graveyard]
		case "music/w2/graveyard":
			return [mu_graveyard]
		case "music/w2/graveyardsecret":
			return [Pizza_Tower___An_Undead_Secret]
		case "music/w3/beachtitle":
			return [beach]
		case "music/w3/beach":
			return [mu_beach]
		case "music/w3/beachsecret":
			return [Pizza_Tower___A_Secret_in_the_Sands]
		case "music/w3/foresttitle":
			return [gnome]
		case "music/w3/forest":
			return [Pizza_Tower___mmm_yess_put_the_tree_on_my_pizza, mu_gustavo, mu_forest]
		case "music/w3/forestsecret":
			return [Pizza_Tower___A_Secret_in_The_Trees]
		case "music/w3/golftitle":
			return [good_eating]
		case "music/w3/golf":
			return [mu_minigolf]
		case "music/w3/golfsecret":
			return [Pizza_Tower___A_Secret_Hole_in_One]
		case "music/w3/spacetitle":
			return [spacetitle]
		case "music/w3/space":
			return [Pizza_Tower_OST___Extraterrestrial_Wahwahs]
		case "music/w3/spacesecret":
			return [mu_pinballsecret]
		case "music/w4/freezertitle":
			return [freezer]
		case "music/w4/freezer":
			return [_39_Don_t_Preheat_Your_Oven_Because_If_You_Do_The_Song_Won_t_Pla, Pizza_Tower___Celcius_Troubles, Pizza_Tower_OST___On_the_Rocks]
		case "music/w4/freezersecret":
			return [Pizza_Tower___A_Frozen_Secret]
		case "music/w4/industrialtitle":
			return [factory]
		case "music/w4/industrial":
			return [mu_industrial, Pizza_Tower_OST___Peppinos_Sauce_Machine]
		case "music/w4/industrialsecret":
			return [Pizza_Tower___An_Industry_Secret]
		case "music/w4/sewertitle":
			return [sewer]
		case "music/w4/sewer":
			return [mu_sewer]
		case "music/w4/sewersecret":
			return [secret_sewer]
		case "music/w4/streettitle":
			return [pig_city]
		case "music/w4/street":
			return [Pizza_Tower_OST___Bite_the_Crust, Pizza_Tower_OST___Way_of_the_Italian, mu_dungeondepth2]
		case "music/w4/streetsecret":
			return [Pizza_Tower___A_Secret_In_These_Streets]
		case "music/w5/chateautitle":
			return [chateau]
		case "music/w5/chateau":
			return [Pizza_Tower_OST___Theres_a_Bone_in_my_Spaghetti]
		case "music/w5/kidspartytitle":
			return [kids_party]
		case "music/w5/kidsparty":
			return [Pizza_Tower_OST___Tunnely_Shimbers]
		case "music/w5/kidspartysecret":
			return [Pizza_Tower___A_Secret_You_Dont_Want_To_Find]
		case "music/w5/wartitle":
			return [war]
		case "music/w5/war":		
			return [mu_war]
		case "music/w5/warsecret":
			return [Pizza_Tower___A_War_Secret]
		case "music/boss/pepperman":
			return [Pizza_Tower_OST___Pepperman_Strikes]
		case "music/boss/vigilante":
			return [mu_vigilante, duel]
		case "music/boss/noise":
			return [Pizza_Tower_OST___Pumpin_Hot_Stuff]
		case "music/boss/noisette":
			return [noisette]
		case "music/boss/fakepep":
			return [mu_fakepep]
		case "music/boss/fakepepambient":
			return [PIZZA_TOWER_THyrzzryzryEME_SONG]
		case "music/rank":
			return [mu_rankd, mu_rankc, mu_rankb, mu_ranka, mu_ranks, prank]
		case "music/halloweenpause":
			return [Spacey_Pumpkins, fnaf2_secret]
		case "music/pause":
			return [Pizza_Tower___Leaning_Dream, lario_s_secret]
		case "music/w5/kidspartychase":
			return [CHASE_THEME_INTRO, CHASE_THEME_LOOP]
		case "music/finalescape":
			return [Pizza_Tower_OST___Bye_Bye_There]
		case "music/w5/finalhallway":
			return [pt_scary_ambient_draft_1]
		case "music/boss/pizzaface":
			return [Pizza_Tower_OST___Unexpectancy_Part_1_of_3, Pizza_Tower_OST___Unexpectancy_Part_2_of_3, Pizza_Tower_OST___Unexpectancy_Part_3_of_3]
		case "sfx/ending/towercollapsetrack":
			return [Pizza_Tower___Pizza_Pie_ing_slight_remaster, Voice_13, Voice_05]
		case "music/credits":
			return [Pizza_Tower_OST___Receiding_Hairline_Celebration_Party, mu_minigolf, mu_funiculi]
		case "music/finalrank":
			return [mu_dungeondepth2, Pizza_Tower_OST___Hip_to_be_Italian]
		case "music/timesup":
			return [Pizza_Tower_OST___Your_Fat_Ass_Slows_You_Down]
		case "music/soundtest/intro":
			return [Pizza_Tower_OST___Time_for_a_Smackdown]
		case "music/soundtest/pizzadeluxe":
			return [mu_title]
		case "music/soundtest/funiculi":
			return [mu_funiculi]
		case "music/soundtest/pizzatime":
			return [mu_pizzatime]
		case "music/soundtest/lap":
			return [mu_chase]
		case "music/soundtest/mondays":
			return [mu_hub]
		case "music/soundtest/unearthly":
			return [Unearthly_Blues]
		case "music/soundtest/hotspaghetti":
			return [mu_medievalentrance]
		case "music/soundtest/coldspaghetti":
			return [Pizza_Tower_OST___Cold_Spaghetti]
		case "music/soundtest/theatrical":
			return [mu_ruin]
		case "music/soundtest/putonashow":
			return [mu_ruinremix]
		case "music/soundtest/dungeon":
			return [Pizza_Tower___Dungeon_Freakshow_v222]
		case "music/soundtest/pepperman":
			return [Pizza_Tower_OST___Pepperman_Strikes]
		case "music/soundtest/tuesdays":
			return [Pizza_Tower_OST___Tuesdays]
		case "music/soundtest/oregano":
			return [mu_desert]
		case "music/soundtest/ufo":
			return [mu_ufo]
		case "music/soundtest/tombstone":
			return [mu_graveyard]
		case "music/soundtest/mort":
			return [mu_farm]
		case "music/soundtest/kidsmenu":
			return [Pizza_Tower___Whats_on_the_Kids_Menu]
		case "music/soundtest/yeehaw":
			return [mu_saloon]
		case "music/soundtest/vigilante":
			return [mu_vigilante]
		case "music/soundtest/wednesdays":
			return [mu_hub3]
		case "music/soundtest/tropical":
			return [mu_beach]
		case "music/soundtest/forest1":
			return [Pizza_Tower___mmm_yess_put_the_tree_on_my_pizza]
		case "music/soundtest/gustavo":
			return [mu_gustavo]
		case "music/soundtest/forest2":
			return [mu_forest]
		case "music/soundtest/goodeatin":
			return [mu_minigolf]
		case "music/soundtest/extraterrestial":
			return [Pizza_Tower_OST___Extraterrestrial_Wahwahs]
		case "music/soundtest/noise":
			return [Pizza_Tower_OST___Pumpin_Hot_Stuff]
		case "music/soundtest/thursdays":
			return [pizza_tower___industrial_hub]
		case "music/soundtest/tubular":
			return [mu_sewer]
		case "music/soundtest/engineer":
			return [mu_industrial]
		case "music/soundtest/saucemachine":
			return [Pizza_Tower_OST___Peppinos_Sauce_Machine]
		case "music/soundtest/bitethecrust":
			return [Pizza_Tower_OST___Bite_the_Crust]
		case "music/soundtest/wayoftheitalian":
			return [Pizza_Tower_OST___Way_of_the_Italian]
		case "music/soundtest/preheat":
			return [_39_Don_t_Preheat_Your_Oven_Because_If_You_Do_The_Song_Won_t_Pla]
		case "music/soundtest/celsius":
			return [Pizza_Tower___Celcius_Troubles]
		case "music/soundtest/plains":
			return [Pizza_Tower_OST___On_the_Rocks]
		case "music/soundtest/fakepep":
			return [mu_fakepep]
		case "music/soundtest/fridays":
			return [mu_hub4]
		case "music/soundtest/chateau":
			return [Pizza_Tower_OST___Theres_a_Bone_in_my_Spaghetti]
		case "music/soundtest/tunnely":
			return [Pizza_Tower_OST___Tunnely_Shimbers]
		case "music/soundtest/thousand":
			return [mu_war]
		case "music/soundtest/unexpectancy1":
			return [Pizza_Tower_OST___Unexpectancy_Part_1_of_3]
		case "music/soundtest/unexpectancy2":
			return [Pizza_Tower_OST___Unexpectancy_Part_2_of_3]
		case "music/soundtest/unexpectancy3":
			return [Pizza_Tower_OST___Unexpectancy_Part_3_of_3]
		case "music/soundtest/bye":
			return [Pizza_Tower_OST___Bye_Bye_There]
		case "music/soundtest/notime":
			return [Pizza_Tower_OST___Receiding_Hairline_Celebration_Party]
		case "music/soundtest/meatphobia":
			return [mu_dungeondepth2]
		case "music/soundtest/mayhem":
			return [Pizza_Tower_OST___Pizza_Mayhem_Instrumental]
		case "music/soundtest/mayhem2":
			return [_58_Pizza_Mayhem]
		case "music/soundtest/lap3":
			return [Pillar_Johns_Revenge]
		case "music/halloween2023":
			return [The_Bone_Rattler, Final_The_Runner_10_15_2023_Halloween_Event_2023_1_]
		case "music/secretworldtitle":
			return [secret_level_intro]
		case "music/secretworld":
			return [Secret_Lockin_v1a]
		default:
			var asset = asset_get_index(string_replace_all(soundname, "/", "_"))
			if asset == -1
				print("MISSING ASSET! " + soundname)
			return [asset]
	}
}

function fmod_event_create_instance(soundpath) { 
	global.createnumber++
	print(soundpath + " created, " + string(global.createnumber) + ".")
	
	var soundname = d_get_fmod_name(soundpath)
	soundlist = d_get_soundlist(soundname)
	
	switch (soundname) {
		default:
			return new fmod_sound(soundlist, true) // this will work for most sounds. the rest of the entries here are for sounds who need more than this
		case "sfx/pep/rollgetup":
			var s = new fmod_sound(soundlist)
			s.sndgain = 1.3
			return s;
		case "sfx/voice/noisepositive":
		case "sfx/voice/noisenegative":
		case "sfx/voice/fakepeppositive":
		case "sfx/voice/fakepepnegative":
			return new fmod_sound_3d(soundlist, true, 1, 0.05)
		case "sfx/misc/clotheswitch":
			return new fmod_sound(soundlist, false, 1, 0.15, false, [0, 0.4])
		case "sfx/ui/angelmove":
		case "sfx/pizzahead/thunder":
		case "sfx/voice/vigiduel":
		case "sfx/voice/fakepepscream":
		case "sfx/fakepep/taunt":
			return new fmod_sound(soundlist, false, 1, 0.15)
		case "sfx/pizzahead/beatdown":
			var s = new fmod_sound(soundlist, false, 1, 0.15)
			s.sndgain = 1.2
			return s;
		case "sfx/misc/elevatorsqueak":	
		case "sfx/pep/screamboss":
			return new fmod_sound(soundlist, false, 1, 0.04, false, [-1, -1], function() {
				if t_anyvar1 == 1 // game plays this twice for no reason
					return;
				var playingsound = play_sound(soundlist[0], true, 1);
				ds_list_add(sound_instances, playingsound);
				t_anyvar1 = 1
			})
		case "sfx/voice/peppermansnicker":
		case "sfx/voice/vigiangry":
			return new fmod_sound(soundlist, false, 0.95, 0.15)
		case "sfx/voice/peppermanscared":
			return new fmod_sound(soundlist, false, 1.05, 0.1)
		case "sfx/pep/machroll":
		case "sfx/rat/ratsniff":
		case "sfx/enemies/axethrow":
		case "sfx/enemies/tribaldance":
		case "sfx/misc/halloweenpumpkin":
		case "sfx/monsters/cheeseloop":
		case "sfx/monsters/puppetfly":
		case "sfx/enemies/homing":
		case "sfx/misc/instanttemp":
		case "sfx/pizzaface/moving":
			return new fmod_sound_3d(soundlist, true, 1, 0, true)
		case "sfx/voice/pizzahead":
			var s = new fmod_sound_3d(soundlist, true)
			s.sndgain = 2.3
			return s;
		case "sfx/barrel/bump":
			var s = new fmod_sound_3d(soundlist, true)
			s.sndgain = 2
			return s;
		case "sfx/voice/mrsticklaugh":
		case "sfx/voice/pig":
		case "sfx/voice/transfo":
		case "sfx/voice/outtransfo":
		case "sfx/noise/fightball":
		case "sfx/pep/slipbump":
		case "sfx/pep/slipend":
			return new fmod_sound_3d(soundlist, true)
		case "sfx/pep/uppercut":
			return new fmod_sound_3d(soundlist, true, 1.2, 0.1)
		case "sfx/voice/pizzagranny":
			return new fmod_sound_3d(soundlist, true, 1.1, 0.1)
		case "sfx/pep/gotsupertaunt":
			var s = new fmod_sound(soundlist)
			s.sndgain = 1.1
			return s;
		case "sfx/misc/toppinhelp":
		case "sfx/rat/ratdead":
		case "sfx/misc/thundercloud":
		case "sfx/misc/kashing":
		case "sfx/enemies/kill":
		case "sfx/ratmount/ball":
		case "sfx/enemies/noisegoblinbow":
		case "sfx/misc/mrstickhat":
		case "sfx/misc/ufo":
		case "sfx/misc/teleporterstart":
		case "sfx/enemies/projectile":
		case "sfx/misc/explosion":
		case "sfx/misc/piranhabite":
		case "sfx/monsters/robotstep":
		case "sfx/monsters/sausagestep":
		case "sfx/enemies/piranha":
		case "sfx/enemies/alarm":
		case "sfx/hub/gusrun":
		case "sfx/enemies/johnghost":
		case "sfx/misc/mushroombounce":
		case "sfx/pep/machslideboost":
		case "sfx/enemies/comingoutground":
		case "sfx/enemies/batwing":
		case "sfx/enemies/ninjakicks":
		case "sfx/misc/sniffbump":
			return new fmod_sound_3d(soundlist)
		case "sfx/kingghost/move":
			var s = new fmod_sound(soundlist, false, 1, 0, false, [-1, -1], true, function() {
				fmod_event_instance_stop(self, true, true)
				var playingsound = play_sound(soundlist[0], false, 1)
				ds_list_add(sound_instances, playingsound)
			})
			with (s) {
				emitter = audio_emitter_create()
				audio_emitter_falloff(emitter, 200, 400, 1)
			}
			return s;
		case "sfx/hub/gusbrickfightball":
		case "sfx/misc/collect":
		case "sfx/misc/bellcollect":
		case "sfx/pep/hurt":
		case "sfx/enemies/coughing":
		case "sfx/enemies/escapespawn":
		case "sfx/pep/parry":
		case "sfx/antigrav/bump":
			return new fmod_sound_3d(soundlist, true, 1, 0.1)
		case "sfx/voice/enemyrarescream":
		case "sfx/voice/myea":
		case "sfx/voice/hurt":
		case "sfx/voice/gushurt":
		case "sfx/voice/gusok":
		case "sfx/voice/mrstick":
		case "sfx/voice/brickok":
		case "sfx/enemies/presentfall":
			return new fmod_sound_3d(soundlist, true, 1, 0.2)
		case "sfx/pipe/bump":	
			var s = new fmod_sound_3d(soundlist, true);
			s.sndgain = 2.5
			return s;
		case "sfx/pep/mach":
			return new fmod_sound_3d(soundlist, false, 1, 0, true, [-1, -1], true, 
			function() {
				if t_state >= 1 {
					var playingsound = audio_play_sound_on(emitter, soundlist[t_state - 1], looping, 10)	
					ds_list_add(sound_instances, playingsound)
					
				}
			}, function(newstate) {
				if newstate == t_state and t_state != -1
					return;
				if fmod_event_instance_is_playing(self) {
					fmod_event_instance_stop(self)
					if newstate == 0
						return;
					var playingsound = audio_play_sound_on(emitter, soundlist[newstate - 1], looping, 10)	
					ds_list_add(sound_instances, playingsound)
				}
			}) 
		case "sfx/misc/hamkuff":
			return new fmod_sound_3d(soundlist, false, 1, 0, true, [-1, -1], true,
			function() {
				return;
			}, function (newstate) {
				if newstate == t_state
					return;
				fmod_event_instance_stop(self, true, true) 
				t_state = newstate;
				var playingsound = audio_play_sound(soundlist[newstate], 10, newstate != 2, newstate == 2 ? 1.4 : 1)
				ds_list_add(sound_instances, playingsound)	
				
			})
		case "sfx/pep/step":
		case "sfx/pep/stepinshit":
		case "sfx/pizzahead/uzi":
			return new fmod_sound_3d(soundlist, false, 1, 0.1)
		case "sfx/pizzahead/fishing":
			var s = new fmod_sound_3d(soundlist)
			s.fadeout = 10;
			return s;
		case "sfx/pep/taunt":
			return new fmod_sound(soundlist, undefined, 1, 0.06)
		case "sfx/pep/freefall":
			return track_loop_intro(soundlist, [2, -1])
		case "sfx/pep/punch":
			return new fmod_sound_3d(soundlist, undefined, 1, 0.1)
		case "sfx/misc/breakdancemusic":
			return new fmod_sound(soundlist, undefined, undefined, undefined, true)
		case "sfx/pep/superjumpcancel":
			return new fmod_sound_3d(soundlist, false, 1, 0, undefined, undefined, true, function() {
				var playingsound = audio_play_sound(soundlist[0], 10, false, 1)
				ds_list_add(sound_instances, playingsound)	
			})
		case "sfx/pep/superjump":
			return new fmod_sound_3d(soundlist, undefined, undefined, undefined, undefined, [-1, -1], true,
			function() {
				t_anyvar1 = 25
				var playingsound = play_sound(soundlist[0], false, 1)
				ds_list_add(sound_instances, playingsound)
				change_loop_sound(playingsound)
			}, function(newstate) {
				if newstate == state
					return;
				fmod_event_instance_stop(self)
				t_anyvar1 = -1
				var playingsound = play_sound(soundlist[2], false, 1)
				ds_list_add(sound_instances, playingsound)	
			}, function() {
				if t_anyvar1 != -1 {
					t_anyvar1 -= 1
					if t_anyvar1 == 0 {
						var playingsound = play_sound(soundlist[1], true, 1)
						ds_list_add(sound_instances, playingsound)	
					}
				}
			}, function() {
				t_anyvar1 = -1	
			})
		case "sfx/pep/pizzapepper":
			var s = new fmod_sound_3d(soundlist, false, 1, 0, true, undefined, true, 
			function() {
				fmod_event_instance_stop(self, true, true)
				var playingsound = play_sound(soundlist[0], true, 1)
				ds_list_add(sound_instances, playingsound)
				t_anyvar1 = playingsound
			}, 
			function (newstate) {
				if t_state == newstate or t_anyvar1 == -1
					return;
				if newstate == 1
					add_audiostopper(t_anyvar1, 30)	
			})
			s.sndgain = 1.65
			return s;
		case "sfx/pep/tumble":
			return new fmod_sound_3d(soundlist, false, 1, 0, true, [-1, -1], true, function () {
				var playingsound = play_sound(soundlist[0], false, 1)
				ds_list_add(sound_instances, playingsound)
			}, function (newstate) {
				if newstate == t_state 
					return;
				if newstate == 1 {
					var playingsound = play_sound(soundlist[1], true, 1)
					ds_list_add(sound_instances, playingsound)
					change_loop_sound(playingsound)
					change_loop_points([0.6, -1])
				}
				else if (newstate == 2) {
					fmod_event_instance_stop(self)
					var playingsound = play_sound(soundlist[2], false, 1)
					ds_list_add(sound_instances, playingsound)
				}
			})
		case "sfx/ratmount/mach":
			return new fmod_sound_3d(soundlist, false, 1, 0, false, [0.46, 7.38], true, 
			function() {
				if t_anyvar1 >= 0 {
					var ind = state == 0 ? 0 : t_anyvar1
					var playingsound = audio_play_sound_on(emitter, soundlist[ind], looping, 10, 1)	
					ds_list_add(sound_instances, playingsound)
					change_loop_sound(playingsound)
				}
			}, function (newstate) {
				if state == newstate
				|| is_undefined(sound_instances[| 0])
					return;
					
				if newstate == 1 {
					var ind = t_anyvar1 + 1
					var offset = fmod_event_instance_get_timeline_pos(self)
					
				}
				else {
					ind = 0
					offset = 0	
				}
				fmod_event_instance_stop(self)
				var playingsound = audio_play_sound_on(emitter, soundlist[ind], looping, 10, state, offset)	
				ds_list_add(sound_instances, playingsound)
				change_loop_sound(playingsound)
					
			}, 
			function () {
				if fmod_event_instance_get_timeline_pos(self) > 0.46
					looping = true
			}, 
			function(grounded) {
				if (grounded == t_anyvar1 and t_anyvar1 != -1)
					return;
				if fmod_event_instance_is_playing(self) && state != 0 {
					var ind = grounded + 1
					var offset = fmod_event_instance_get_timeline_pos(self)
					fmod_event_instance_stop(self)
					var playingsound = audio_play_sound_on(emitter, soundlist[ind], looping, 10, state, offset)	
					ds_list_add(sound_instances, playingsound)
					change_loop_sound(playingsound)
				}
				t_anyvar1 = grounded
			})
		case "sfx/ratmount/groundpound":
			return new fmod_sound_3d(soundlist, false, 1, 0, true, [0, 2], false, 
			function () {
				if t_state != 1
					change_loop_points([0, 2])
				else {
					change_loop_points([2.76, 5.07])
				}
			}, 
			function(newstate) {
				if (newstate == t_state and t_anyvar1 != -1) or is_undefined(sound_instances[| 0])
					return;
				if newstate == 1 and fmod_event_instance_is_playing(self) {
					add_audiostopper(sound_instances[| 0], 10)
					var playingsound = audio_play_sound_on(emitter, soundlist[0], looping, 10, 0, 2.3)	
					looping = false
					audio_sound_gain(playingsound, 1, 10 * 1000/60)
					sound_instances[| 0] = playingsound
					change_loop_sound(playingsound)
					change_loop_points([2.76, 5.07])
				}
			}, function() {
				if t_state != 1 or is_undefined(sound_instances[| 0])
					return;
				
				if audio_sound_get_track_position(sound_instances[| 0]) > 2.76
					looping = true
			})
		case "sfx/misc/golfjingle":
			var s = new fmod_sound(soundlist, false, 1, 0, false, [-1, -1], true, function() {
				var playingsound = play_sound(soundlist[state], false, 1)	
				ds_list_add(sound_instances, playingsound)
			})
			s.sndgain = 2
			return s;
		case "sfx/misc/mrpinch":
			return new fmod_sound_3d(soundlist, false, 1, 0, true, [-1, -1], true, 
			function () {
				var playingsound = play_sound(soundlist[0], true, 1)
				ds_list_add(sound_instances, playingsound)
			}, function(newstate) {
				if newstate == t_state or newstate == 0
					return;
				fmod_event_instance_stop(self, true, true)
				var playingsound = play_sound(soundlist[1], false, 1)
				ds_list_add(sound_instances, playingsound)
			})
		case "sfx/pep/ghostspeed":
			var s = new fmod_sound_3d(soundlist, false, 1, 0, true, [-1, -1], true, 
			function () {
				if state == 0
					return;
				var ind = state - 1
				var playingsound = play_sound(soundlist[ind], true, 1)
				sound_instances[| 0] = playingsound
			}, function(newstate) {
				if newstate == state or newstate == 0
					return;
				if !is_undefined(sound_instances[| 0])
					audio_stop_sound(sound_instances[| 0])
			})
			s.sndgain = 1.3
			s.fadeout = 2
			return s;
		case "sfx/kingghost/loop":
			return track_loop_intro_3d(soundlist, [0.8, 6.85])
		case "sfx/fakepep/chase":
			return new fmod_sound_3d(soundlist, false, 1, 0, true)
		case "sfx/fakepep/superjumpclonerelease":
			var s = new fmod_sound_3d(soundlist, false, 1, 0, false, [-1, -1], true, function () {
				fmod_event_instance_stop(self, true, true)
				var playingsound = play_sound(soundlist[0], false, 1)
				ds_list_add(sound_instances, playingsound)
			})
			s.sndgain = 5
			return s;
		case "sfx/fakepep/bodyslam":
		case "sfx/fakepep/flailing":
		case "sfx/fakepep/headoff":
		case "sfx/fakepep/headthrow":
		case "sfx/fakepep/mach":
		case "sfx/fakepep/grab":
			var s = new fmod_sound_3d(soundlist, false, 1, 0, false)
			s.fadeout = 7
			s.sndgain = global.clonemult
			return s;
		case "sfx/fakepep/deform":
		case "sfx/fakepep/reform":
			var s = new fmod_sound_3d(soundlist, false, 1, 0, false, undefined, true, function() {
				fmod_event_instance_stop("event:/sfx/fakepep/reform", true)
				var playingsound = play_sound(soundlist[0], false, 1)
				ds_list_add(sound_instances, playingsound)
			})
			s.fadeout = 7
			s.sndgain = global.clonemult
			return s;
		case "sfx/fakepep/superjump":
			return new fmod_sound(soundlist, false, 1, 0, false, [-1, -1], true, function () {
				sndgain = min(global.clonemult * 3, 1)
				var playingsound = play_sound(soundlist[state], false, 1)	
				sound_instances[| 0] = playingsound
			}, function(newstate) {
				if !is_undefined(sound_instances[| 0])
					audio_stop_sound(sound_instances[| 0])
			})
		case "sfx/ui/percentagemove":
			return new fmod_sound(soundlist, false, 1, 0, false, [-1, -1], true, function() {
				var pitch = 1 + state
				play_sound(soundlist[0], false, pitch)
			})
		/* this sound apparently never plays in the game
		case "sfx/enemies/cannongoblin":
			var s = new fmod_sound_3d(soundlist, false)
			s.delay = 40
			return s;
		*/
		case "sfx/pizzahead/tvthrow":
			return new fmod_sound(soundlist, false, 1, 0, false, [-1, -1], false, 
			function () {
				return;	
			}, function (newstate) {
				if newstate == t_state
					return;
				switch (newstate) {
					case 0:
					case 2:
						fmod_event_instance_set_timeline_pos(self, 0)
						break;
					case 1:
						fmod_event_instance_set_timeline_pos(self, 3.33)
						break;
					case 3:
						fmod_event_instance_set_timeline_pos(self, 5)
						break;
				}	
			})
		case "sfx/pizzahead/finale":
			return new fmod_sound(soundlist, false, 1, 0, false, [-1, -1], false, undefined,
			function(newstate) {
				if newstate == state
					return;
				var pause = (newstate % 2 == 1)
				fmod_event_instance_set_paused(self, pause)
				if pause {
					t_anyvar1 = audio_play_sound(soundlist[1], false, true, 1.6, 1)
					audio_sound_set_track_position(t_anyvar1, 1)
					ds_list_add(sound_instances, t_anyvar1)
				}
				else {
					if t_anyvar1 != -1
						audio_stop_sound(t_anyvar1)
				}
				
			})
		case "sfx/pizzaface/shower":
			return new fmod_sound_3d(soundlist, false, 1, 0, false, [-1, -1], true, 
			function() {
				var playingsound = play_sound(soundlist[0], true, 1)
				ds_list_add(sound_instances, playingsound)
			}, 
			function(newstate) {
				if newstate == t_state
					return;
				fmod_event_instance_stop(self, true, true);
				var playingsound = play_sound(soundlist[newstate], false, 1)
				ds_list_add(sound_instances, playingsound)
			})
		case "sfx/misc/versusscreen":
			var s = new fmod_sound(soundlist)
			s.delay = 33
			return s;
		case "music/intro":
			return new fmod_sound(soundlist, undefined, undefined, undefined, undefined, undefined, undefined, function(playingsound = noone) {
				audio_sound_gain(playingsound, 0, 0)
			}, function(newstate) {
				if is_undefined(sound_instances[| 0]) or t_state == newstate
					exit
				if newstate == 0 {
					if t_anyvar1 != 1 {
						audio_pause_sound(sound_instances[| 0])	
						audio_sound_set_track_position(sound_instances[| 0], 0)	
					}
					else
						add_audiostopper(sound_instances[| 0], 60)
				}
				else {
					audio_resume_sound(sound_instances[| 0])
					audio_sound_gain(sound_instances[| 0], 1, 1000/60)
					audio_sound_set_track_position(sound_instances[| 0], 0)	
					t_anyvar1 = 1
				}
			})
		case "music/title":
			return new fmod_sound(soundlist, undefined, undefined, undefined, true, [0, 4.83], true, function() {
				statetimer = 0	
				var playingsound = audio_play_sound(soundlist[0], 10, true, 0.6)	
				ds_list_add(sound_instances, playingsound)
				ds_list_add(sound_instances, noone)
				change_loop_sound(playingsound)
				change_loop_points([0, 4.83])
			}, function (newstate) {
				if newstate == 3 {
					add_audiostopper(sound_instances[| 1], 60)
					return;
				}
				if newstate == t_state or !variable_struct_exists(self, "statetimer")
					return;

				if newstate == 2 {
					audio_sound_gain(sound_instances[| 0], 0, 1000)
					
					if !is_undefined(ds_list_find_value(sound_instances, 1)) 
					&& audio_is_playing(sound_instances[| 1])
						var offset = audio_sound_get_track_position(sound_instances[| 1])
					else
						offset = 0
					var playingsound = audio_play_sound(soundlist[is_holiday(true) ? 2 : 1], true, 1, 0, offset)
					audio_sound_gain(playingsound, 1, 1000)
					sound_instances[| 1] = playingsound
				}
				else if newstate == 1 && statetimer > 20 {
					audio_sound_gain(sound_instances[| 1], 0, 1000)
					audio_sound_gain(sound_instances[| 0], 1, 1000)
				}	
			}, function() {
				if !variable_struct_exists(self, "statetimer")
					return;
				if (t_state == 1) {
					if statetimer == 0
						audio_sound_gain(sound_instances[| 0], 1, 0)
					statetimer += 1
					if statetimer == 20
						change_loop_points([13.25, 133.25])
				}
			})
		case "music/tutorial":
			return new fmod_sound(soundlist, undefined, undefined, undefined, true)
		case "music/pizzatime":
			var s = new fmod_sound(soundlist, false, undefined, undefined, false, [-1, -1], true,
			function () {
				t_anyvar1 = play_sound(soundlist[0], false, 1)
				ds_list_add(sound_instances, t_anyvar1)	
				var playingsound = play_sound(soundlist[1], false, 1)
				ds_list_add(sound_instances, playingsound)	
			}, 
			function(newstate) {
				if t_state >= newstate
					return;
				if (newstate == 1) {
					audio_sound_gain(t_anyvar1, 0, 1000)
					t_anyvar1 = audio_play_sound(soundlist[0], 10, false, 0, 170.7)
					audio_sound_gain(t_anyvar1, 1, 1000)
					ds_list_add(sound_instances, t_anyvar1)
				}
				else if (newstate == 2) {
					audio_sound_gain(t_anyvar1, 0, 500)
					t_anyvar1 = audio_play_sound(soundlist[2], 10, true, 0)
					audio_sound_gain(t_anyvar1, 1, 500)
					ds_list_add(sound_instances, t_anyvar1)	
				}
				else if (newstate == 3) {
					if !global.option_lap3
						return;
					audio_sound_gain(t_anyvar1, 0, 500)
					var playingsound = audio_play_sound(soundlist[3], 10, true, 0)
					audio_sound_gain(playingsound, 1, 500)
					ds_list_add(sound_instances,playingsound)	
				}
			}, function() {
				// we run this step function for levels which have an escape so long (like golf) where the song has to loop
				var pos = 0
				if t_state == 0 {
					if audio_is_playing(t_anyvar1) {
						var pos = audio_sound_get_track_position(t_anyvar1)
						if pos > 165 + 1/3 
							audio_sound_set_track_position(t_anyvar1, (165 + 1/3) - pos + 53 + 1/3)
					}
				}
				else if t_state == 2 {
					if audio_is_playing(t_anyvar1) {
						pos = audio_sound_get_track_position(t_anyvar1)
						if pos > 168.85
							audio_sound_set_track_position(t_anyvar1, (168.85) - pos + 40.85)
					}
				}
				
			})
			s.sndgain = 1.3
			return s;
		case "music/hub":
			var s = new fmod_sound(soundlist, undefined, undefined, undefined, true, [-1, -1], true,
			function () {
				anyvar1 = global.d_hub
				var playingsound = audio_play_sound(soundlist[anyvar1], 10, true)
				ds_list_add(sound_instances, playingsound)
				audio_pause_sound(playingsound)
				change_loop_sound(playingsound)
			}, undefined,
			function () {
				if ds_list_size(sound_instances) == 0 or !audio_is_playing(sound_instances[| 0])
					return;
				var trackpos = audio_sound_get_track_position(sound_instances[| 0])
				if trackpos >= 153.7 {
					audio_sound_set_track_position(sound_instances[| 0], (trackpos - 153.7) + 2.15)
					audio_sound_gain(sound_instances[| 0], 0, 0)
					audio_sound_gain(sound_instances[| 0], 1, 1000/60)
					var endsound = audio_play_sound(mu_hub, 10, false)
					audio_sound_set_track_position(endsound, trackpos)	
				}
				
			},
			function(hubnum) {
				if hubnum == anyvar1 or hubnum == -1
					return;
					
				global.d_hub = hubnum
				if is_undefined(sound_instances[| 0])
					return;
				var pos = audio_sound_get_track_position(sound_instances[| 0])
				if pos != 0 {
					for (var i = 0; i < ds_list_size(sound_instances); i++)
						audio_stop_sound(sound_instances[| i])
					sound_instances[| 0] = audio_play_sound(soundlist[hubnum], 10, false, 0, pos)
					change_loop_sound(sound_instances[| 0])
					audio_sound_gain(sound_instances[| 0], 1, 1000)
					var sndfade = audio_play_sound(soundlist[anyvar1], 10, false, 1, pos)
					audio_sound_gain(sndfade, 0, 1000)
				}
				
				anyvar1 = hubnum
				
			})
			s.fadeout = 120
			return s;
		case "music/w1/entrance": // john gutter
			var s = new fmod_sound(soundlist, undefined, undefined, undefined, true, [-1, -1], undefined, undefined, undefined, function() {
				
				if is_undefined(ds_list_find_value(sound_instances, 0))
					return;
				var trackpos = audio_sound_get_track_position(sound_instances[| 0])
				if trackpos >= 212.38 {
					audio_sound_set_track_position(sound_instances[| 0], (trackpos - 212.38) + 42.47)
					var endsound = audio_play_sound(Unearthly_Blues, 10, false)
					audio_sound_set_track_position(endsound, trackpos)
				}
			})
			s.sndgain = 1.2
			return s;
		case "music/w1/medieval": // pizzascape
			return swap_two_tracks_intro(soundlist, [2.6, 117.39], [18.28, 123.42], 2)
		case "music/w1/ruin": // ancient cheese
			return swap_two_tracks_intro(soundlist, [0, 112], [-1, -1])
		case "music/w2/desert": // oregano desert
			return swap_two_tracks_intro(soundlist, [-1, -1], [0, 60 * 3 + 40], 1)
		case "music/w1/dungeon": // bloodsauce dungeon
			return new fmod_sound(soundlist, undefined, undefined, undefined, true, [0, 212])
		case "music/w2/graveyard":
			return track_loop_intro(soundlist, [42, 60 * 3 + 39])
		case "music/w2/farm":
			return swap_two_tracks_intro(soundlist, [-1, -1], [-1, -1], 1, true)
		case "music/w1/entrancesecret": // secrets
		case "music/w1/medievalsecret":
		case "music/w1/ruinsecret":
		case "music/w1/dungeonsecret":
		case "music/w2/desertsecret":
		case "music/w2/saloonsecret":
		case "music/w2/farmsecret":
		case "music/w2/graveyardsecret":
		case "music/w3/beachsecret":
		case "music/w3/forestsecret":
		case "music/w3/golfsecret":
		case "music/w3/spacesecret":
		case "music/w4/freezersecret":
		case "music/w4/industrialsecret":
		case "music/w4/sewersecret":
		case "music/w4/streetsecret":
		case "music/w5/kidspartysecret":
		case "music/w5/warsecret":
		case "music/w2/saloon":
		case "music/w4/sewer":
		case "music/pillarmusic":
		case "sfx/pep/cross":
			return new fmod_sound(soundlist, false, 1, 0, true)
		case "music/boss/fakepep":
		case "music/secretworld":
			var s = new fmod_sound(soundlist, false, 1, 0, true)
			s.sndgain = 1.25
			return s;
		case "music/w3/beach":
			return track_loop_intro(soundlist, [2.08, 2 * 60 + 47.64]) // at this point i got tired of saying what levels these are, figure it out
		case "music/w3/forest": 
			return swap_three_tracks_intro(soundlist, [0, 60 * 2 + 42.76], [-1, -1], [-1, -1])
		case "music/w3/golf":
			return new fmod_sound(soundlist, undefined, undefined, undefined, true, [0, 3 * 60 + 27.03])
		case "music/w3/space":
			return track_loop_intro(soundlist, [3.5, 3 * 60 + 26.71])
		case "music/w4/freezer":
			return swap_three_tracks_intro(soundlist, [0, 2 * 60 + 18.24], [-1, -1], [-1, -1], true)
		case "music/w4/industrial":
			return swap_two_tracks_intro(soundlist, [0, 2 * 60 + 23.98], [0.2, 2 * 60 + 8.19], 1, true)
		case "music/w4/street":
			return swap_three_tracks_intro(soundlist, [17.34, 2 * 60 + 38.04], [0.02, -1], [-1, -1], true)
		case "music/w5/chateau":
			return new fmod_sound(soundlist, undefined, undefined, undefined, true, [0, 3 * 60 + 1.60])
		case "music/w5/kidsparty":
			return track_loop_intro(soundlist, [54.91, 60 * 3 + 50.21])
		case "music/w5/kidspartychase":
			var s = new fmod_sound(soundlist, undefined, undefined, undefined, true, [-1, -1], true,
			function() {
				t_anyvar1 = 27
				var playingsound = audio_play_sound(soundlist[0], 10, false)
				ds_list_add(sound_instances, playingsound)	
			}, undefined,
			function() {
				if t_anyvar1 != -1 {
					t_anyvar1 -= 1
					if t_anyvar1 == 0 {
						var playingsound = audio_play_sound(soundlist[1], 10, true)
						ds_list_add(sound_instances, playingsound)	
					}
				}
			})
			s.fadeout = 10
			return s;
		case "music/w5/war":
			return track_loop_intro(soundlist, [14.14, 4 * 60 + 14.12])
		case "music/boss/pepperman":
			var s = track_loop_intro(soundlist, [2.44, 60 + 53.6])
			with (s) {
				fadeout = 6
				statefunc = method(self, function(newstate) {
					if newstate == t_state or is_undefined(sound_instances[| 0])
						return;
					
					if newstate == 1	
						audio_sound_gain(sound_instances[| 0], 0.3, 400)
					else
						audio_sound_gain(sound_instances[| 0], 1, 400)
				})
			}
			
			return s;
		case "music/boss/vigilante":
			return new fmod_sound(soundlist, false, undefined, undefined, true, [0.02, 2 * 60 + 40.02], true, 
			function() {
				change_loop_points([-1, -1])
				var playingsound = audio_play_sound(soundlist[0], 10, true, 1)
				ds_list_add(sound_instances, playingsound)
				change_loop_sound(playingsound)
				playingsound = audio_play_sound(soundlist[1], 10, true, 0)
				ds_list_add(sound_instances, playingsound)
				t_anyvar1 = 0
			}, function(newstate) {
				if t_state == -1
				or is_undefined(ds_list_find_value(sound_instances, 0)) 
				or is_undefined(ds_list_find_value(sound_instances, 1)) 
				or newstate == t_anyvar1
					return;
				audio_sound_gain(sound_instances[| 0], 1 - newstate, 0)
				audio_sound_gain(sound_instances[| 1], newstate * 1.2, 0)
			})
		case "music/boss/noise":
			return new fmod_sound(soundlist, undefined, undefined, undefined, true, [-1, -1], undefined, undefined, undefined, function() {
				if is_undefined(ds_list_find_value(sound_instances, 0))
					return;
				var trackpos = audio_sound_get_track_position(sound_instances[| 0])
				if trackpos >= (60 * 2 + 13.71) {
					audio_sound_set_track_position(sound_instances[| 0], trackpos - 60 * 2 + 13.71)
					var endsound = audio_play_sound(soundlist[0], 10, false, 1, trackpos)
				}
			})
		case "music/boss/fakepepambient":
			return new fmod_sound(soundlist, false, 1, 0, true, [-1, -1], true, function() {
				if t_anyvar1 == 1 // game plays this twice for no reason
					return;
				sndgain = 0
				var playingsound = play_sound(soundlist[0], true, 1);
				audio_sound_gain(playingsound, 1, 1500)
				ds_list_add(sound_instances, playingsound);
				t_anyvar1 = 1
			})
		case "music/boss/pizzaface":
			return new fmod_sound(soundlist, false, 1, 0, true, [0, 60 * 2 + 38.4], true, function() {
				sndgain = 1
				var playingsound = play_sound(soundlist[0], true, 1)	
				t_anyvar1 = playingsound
				ds_list_add(sound_instances, playingsound);
				change_loop_sound(playingsound)
			}, function(newstate) {
				if newstate == state or t_anyvar1 == -1
					return;
				switch (newstate) {
					case 1:
						add_audiostopper(t_anyvar1, 10)
						sndgain = 0
						var playingsound = play_sound(soundlist[1], true, 1)	
						t_anyvar1 = playingsound
						audio_sound_gain(playingsound, 1, 166)
						ds_list_add(sound_instances, playingsound);
						change_loop_sound(playingsound)
						change_loop_points([19.23, 38.45])
						break;
					case 1.4: // WHY. why 1.4. why not 1.5 if you have an intermediate state. what the fuck.
						audio_sound_set_track_position(t_anyvar1, 38.45)
						if is_struct(soundwatcher)
							soundwatcher.last_time_point = 38.45
						
						change_loop_points([0.03, 60 * 2 + 56.43])
						break;
					case 2:
						add_audiostopper(t_anyvar1, 30)
						var playingsound = play_sound(soundlist[2], false, 1)	
						t_anyvar1 = playingsound
						audio_sound_gain(playingsound, 1, 166)
						ds_list_add(sound_instances, playingsound);
						change_loop_sound(playingsound)
						change_loop_points([0, 60 * 3 + 21.60])
						break;
					case 3:
						add_audiostopper(t_anyvar1, 30)
						var playingsound = play_sound(soundlist[2], true, 1)
						t_anyvar1 = playingsound
						audio_sound_gain(playingsound, 1, 166)
						audio_sound_set_track_position(playingsound, 42)
						if is_struct(soundwatcher)
							soundwatcher.last_time_point = 42
						ds_list_add(sound_instances, playingsound);
						change_loop_sound(playingsound)
						change_loop_points([0, 60 * 3 + 21.60])
						break;
					case 4:
						add_audiostopper(t_anyvar1, 30)
						var playingsound = play_sound(soundlist[2], true, 1)	
						t_anyvar1 = playingsound
						audio_sound_gain(playingsound, 1, 333)
						audio_sound_set_track_position(playingsound, 60 * 3 + 21.60)
						if is_struct(soundwatcher)
							soundwatcher.last_time_point = 60 * 3 + 21.60
						ds_list_add(sound_instances, playingsound);
						change_loop_sound(playingsound)
						change_loop_points([60 * 3 + 21.60, 60 * 4 + 19.20])
						break;
					case 5:
						add_audiostopper(t_anyvar1, 60)
						var playingsound = play_sound(soundlist[2], false, 1)	
						t_anyvar1 = playingsound
						audio_sound_gain(playingsound, 1, 333)
						audio_sound_set_track_position(t_anyvar1, 60 * 4 + 19.20)
						if is_struct(soundwatcher)
							soundwatcher.last_time_point = 60 * 4 + 19.20
						ds_list_add(sound_instances, playingsound);
						change_loop_sound(playingsound)
						change_loop_points([60 * 4 + 19.20, -1])
						break;
				}
				
			}, function() {
				if loop_points[0] != 0 or t_anyvar1 == -1
					return;
				switch (t_state) {
					case 3:
						if audio_sound_get_track_position(t_anyvar1) > 48
							change_loop_points([48, 60 * 3 + 21.60])
						break;
					case 4:
						if audio_sound_get_track_position(t_anyvar1) > 60 * 3 + 26.40
							change_loop_points(60 * 3 + 26.40, 60 * 4 + 19.20)
						break;
				}
			})
		case "sfx/ending/towercollapsetrack":
			return new fmod_sound(soundlist, false, 1, 0, false, [-1, -1], true, 
			function() {
				sndgain = 0
				var playingsound = play_sound(soundlist[0], false, 1)
				sndgain = 1
				ds_list_add(sound_instances, playingsound)
				t_anyvar1 = -60
				
			}, undefined, 
			function() {
				if t_anyvar1 == 901 or is_undefined(sound_instances[| 0])
					return;
				t_anyvar1++;
				if t_anyvar1 == 90 {
					audio_sound_set_track_position(sound_instances[| 0], 6.5)
					audio_sound_gain(sound_instances[| 0], 1, 2000)	
				}
				else if t_anyvar1 == 505 {
					var playingsound = play_sound(soundlist[1], false, 1)	
					ds_list_add(sound_instances, playingsound)
				}
				else if t_anyvar1 == 605 {
					var playingsound = play_sound(soundlist[2], false, 1)	
					ds_list_add(sound_instances, playingsound)
				}
				else if t_anyvar1 == 900 {
					add_audiostopper(sound_instances[| 0], 180)
				}
				
			})
		case "music/w5/finalhallway":
			return new fmod_sound(soundlist, false, 1, 0, true)
		case "music/credits":
			return new fmod_sound(soundlist, false, 1, 0, false, [-1, -1], true, function() {
				var playingsound = play_sound(soundlist[0], false, 1)
				sndgain = 1
				ds_list_add(sound_instances, playingsound)
				t_anyvar1 = 0
			}, undefined, 
			function () {
				if t_anyvar1 == -1 or t_anyvar1 == 2
					return;
				if !fmod_event_instance_is_playing(self) {
					if t_anyvar1 == 0 {
						var playingsound = play_sound(soundlist[1], false, 1)
						ds_list_add(sound_instances, playingsound)
						t_anyvar1 = 1
					}
					else {
						var playingsound = play_sound(soundlist[2], true, 1)
						ds_list_add(sound_instances, playingsound)
						t_anyvar1 = 2
					}
				}
			})
		case "music/finalrank":
			return new fmod_sound(soundlist, false, 1, 0, true, [-1, -1], true, function() {
				var playingsound = play_sound(soundlist[0], true, 1)	
				ds_list_add(sound_instances, playingsound)
			}, function (newstate) {
				if newstate != 1 or newstate == state
					return;
				fmod_event_instance_stop(self, true, true)
				var playingsound = play_sound(soundlist[1], true, 1)	
				ds_list_add(sound_instances, playingsound)
			})
		case "music/rank":
			var s = new fmod_sound(soundlist, undefined, undefined, undefined, undefined, undefined, true, 
			function() {
				if (t_anyvar1 == -1)
					return;
					
				// no idea why _rank is like this. so stupid
				var ind = t_anyvar1 - 0.5
				if ind <= 4
					ind = 4 - ind

				var ranksound = audio_play_sound(soundlist[ind], 10, false)
				ds_list_add(sound_instances, ranksound)
				audio_pause_sound(sound_instances[| 0])
			}, undefined, 
			function() {
				if is_undefined(sound_instances[| 0])
					return;
				if audio_is_paused(sound_instances[| 0])
					audio_resume_sound(sound_instances[| 0])
			}, 
			function(_rank) {
				t_anyvar1 = _rank
			})
			s.delay = 5
			return s;
		case "music/halloweenpause":
			return new fmod_sound(soundlist, false, undefined, undefined, true, [-1, -1], true, 
			function() {
				var playingsound = audio_play_sound(soundlist[0], 10, true, 1)
				ds_list_add(sound_instances, playingsound)
				playingsound = audio_play_sound(soundlist[1], 10, true, 0)
				ds_list_add(sound_instances, playingsound)
				save_points = [0, 0]
			}, function(newstate) {
				if t_state == -1
				or is_undefined(ds_list_find_value(sound_instances, 0)) 
				or is_undefined(ds_list_find_value(sound_instances, 1)) 
				or state == newstate
					return;
				if newstate == 1 {
					audio_sound_gain(sound_instances[| 0], 0, 1000)
					audio_sound_gain(sound_instances[| 1], 1, 1000)
					save_points[0] = audio_sound_get_track_position(sound_instances[| 0]) + 1
					audio_sound_set_track_position(sound_instances[| 1], save_points[1])
				}
				else {
					audio_sound_gain(sound_instances[| 0], 1, 1000)
					audio_sound_gain(sound_instances[| 1], 0, 1000)
				
					audio_sound_set_track_position(sound_instances[| 0], save_points[0])
					save_points[1] = audio_sound_get_track_position(sound_instances[| 1]) + 1	
				
				}
			}, function() {
				if is_undefined(ds_list_find_value(sound_instances, 0))
					return;
				if audio_sound_get_track_position(sound_instances[| 0]) > (1 * 60 + 27.25) {
					var trackpos = audio_sound_get_track_position(sound_instances[| 0])
					var endsound = audio_play_sound(soundlist[0], 10, false, audio_sound_get_gain(sound_instances[| 0]))
					audio_sound_set_track_position(endsound, trackpos)
					audio_sound_set_track_position(sound_instances[| 0], trackpos - (1 * 60 + 27.25))
				}
			})
		case "music/pause":
			return swap_two_tracks_intro(soundlist, [-1, -1], [-1, -1], 1, true) // fyi: in the port,
			// this is played 1 frame after the pause
		case "music/halloween2023":
			return new fmod_sound(soundlist, false, undefined, undefined, true, [-1, 1 * 60 + 51.86], true, 
			function() {
				var playingsound = audio_play_sound(soundlist[0], 10, true, 1)
				ds_list_add(sound_instances, playingsound)
				change_loop_sound(playingsound)
				t_anyvar1 = 0
			}, function(newstate) {
				if state == newstate || is_undefined(sound_instances[| 0])
					return;
				if newstate == 1 {
					audio_stop_sound(sound_instances[| 0])
					sound_instances[| 0] = audio_play_sound(soundlist[1], 10, true)
				}
				else {
					audio_stop_sound(sound_instances[| 0])
					sound_instances[| 0] = audio_play_sound(soundlist[0], 10, true)
					change_loop_sound(sound_instances[| 0])
					change_loop_points([-1, 1 * 60 + 51.86])
					t_anyvar1 = 0
				}
			}, function() {
				if state == 1 {
					if audio_sound_get_track_position(sound_instances[| 0]) > 3 * 60 + 44 {
						var trackpos = audio_sound_get_track_position(sound_instances[| 0])
						var endsound = audio_play_sound(soundlist[1], 10, false, audio_sound_get_gain(sound_instances[| 0]))
						audio_sound_set_track_position(endsound, trackpos)
						audio_sound_set_track_position(sound_instances[| 0], trackpos - 3 * 60 + 44)
					}
				}
				else {
					if t_anyvar1 != 0 or is_undefined(ds_list_find_value(sound_instances, 0))
						return;
					if audio_sound_get_track_position(sound_instances[| 0]) > 7.68 {
						change_loop_points([7.68, 1 * 60 + 51.86]);
						t_anyvar1 = 1	
					}
				}
			}, undefined,
			function() {
				change_loop_points([-1, 1 * 60 + 51.86])
			})
			

	}
}


function track_loop_intro(_soundlist, _loop_points1) {
	var s = new fmod_sound(_soundlist, false, undefined, undefined, true, [-1, -1], false, 
	function() {
		change_loop_points([-1, -1])
		t_anyvar1 = 0
	}, undefined,
	function () {
		if t_anyvar1 != 0 or is_undefined(ds_list_find_value(sound_instances, 0))
			return;
		if audio_sound_get_track_position(sound_instances[| 0]) > loop_points1[0] {
			change_loop_points(loop_points1);
			t_anyvar1 = 1	
		}
	})
	s.loop_points1 = _loop_points1
	return s;

}

function track_loop_intro_3d(_soundlist, _loop_points1) {
	var s = new fmod_sound_3d(_soundlist, false, undefined, undefined, true, [-1, -1], false, 
	function() {
		change_loop_points([-1, -1])
		t_anyvar1 = 0
	}, undefined,
	function () {
		if t_anyvar1 != 0 or is_undefined(ds_list_find_value(sound_instances, 0))
			return;
		if audio_sound_get_track_position(sound_instances[| 0]) > loop_points1[0] {
			change_loop_points(loop_points1);
			t_anyvar1 = 1	
		}
	})
	s.loop_points1 = _loop_points1
	return s;

}

function swap_two_tracks_intro(_soundlist, _loop_points1, _loop_points2, _checkstate = 1, _pause_until_play = false) {
	var s = new fmod_sound(_soundlist, false, undefined, undefined, true, [-1, -1], true, 
	function() {
		change_loop_points([-1, -1])
		var playingsound = audio_play_sound(soundlist[0], 10, true, 1)
		ds_list_add(sound_instances, playingsound)
		change_loop_sound(playingsound)
		playingsound = audio_play_sound(soundlist[1], 10, true, 0)
		ds_list_add(sound_instances, playingsound)
		if pause_until_play
			save_points = [0, 0]
		t_anyvar1 = 0
	}, function(newstate) {
		if t_state == -1
		or is_undefined(ds_list_find_value(sound_instances, 0)) 
		or is_undefined(ds_list_find_value(sound_instances, 1)) 
		or state == newstate
			return;
		if newstate == checkstate {
			audio_sound_gain(sound_instances[| 0], 0, 1000)
			audio_sound_gain(sound_instances[| 1], 1, 1000)
			change_loop_points(loop_points2);
			change_loop_sound(sound_instances[| 1])
			if pause_until_play {
				save_points[0] = audio_sound_get_track_position(sound_instances[| 0]) + 1
				audio_sound_set_track_position(sound_instances[| 1], save_points[1])
			}
		}
		else {
			audio_sound_gain(sound_instances[| 0], 1, 1000)
			audio_sound_gain(sound_instances[| 1], 0, 1000)
			change_loop_points(loop_points1);
			change_loop_sound(sound_instances[| 0])
			if pause_until_play {
				audio_sound_set_track_position(sound_instances[| 0], save_points[0])
				save_points[1] = audio_sound_get_track_position(sound_instances[| 1]) + 1	
			}
		}
	}, function() {
		if t_anyvar1 != 0 or is_undefined(ds_list_find_value(sound_instances, 0))
			return;
		if audio_sound_get_track_position(sound_instances[| 0]) > loop_points1[0] {
			change_loop_points(loop_points1);
			t_anyvar1 = 1	
		}
	})
	s.checkstate = _checkstate
	s.loop_points1 = _loop_points1
	s.loop_points2 = _loop_points2
	s.pause_until_play = _pause_until_play
	return s;
}

function swap_three_tracks(_soundlist, _loop_points1, _loop_points2, _loop_points3, _pause_until_play = false) {
	var s = new fmod_sound(_soundlist, false, undefined, undefined, true, [-1, -1], true, 
	function() {
		change_loop_points([-1, -1])
		var playingsound = audio_play_sound(soundlist[0], 10, true, 1)
		ds_list_add(sound_instances, playingsound)
		change_loop_sound(playingsound)
		playingsound = audio_play_sound(soundlist[1], 10, true, 0)
		ds_list_add(sound_instances, playingsound)
		playingsound = audio_play_sound(soundlist[2], 10, true, 0)
		ds_list_add(sound_instances, playingsound)
		if pause_until_play
			save_points = [0, 0, 0]

	}, function(newstate) {
		if is_undefined(ds_list_find_value(sound_instances, 0)) 
		or is_undefined(ds_list_find_value(sound_instances, 1)) 
		or is_undefined(ds_list_find_value(sound_instances, 2))
		or newstate == t_state
			return;
		if newstate == 0 {
			audio_sound_gain(sound_instances[| 0], 1, 1000)
			audio_sound_gain(sound_instances[| 1], 0, 1000)
			audio_sound_gain(sound_instances[| 2], 0, 1000)
			change_loop_points(loop_points1);
			change_loop_sound(sound_instances[| 0])

		}
		else if newstate == 1 {
			audio_sound_gain(sound_instances[| 0], 0, 1000)
			audio_sound_gain(sound_instances[| 1], 1, 1000)
			audio_sound_gain(sound_instances[| 2], 0, 1000)
			change_loop_points(loop_points2);
			change_loop_sound(sound_instances[| 1])
		}
		else {
			audio_sound_gain(sound_instances[| 0], 0, 1000)
			audio_sound_gain(sound_instances[| 1], 0, 1000)
			audio_sound_gain(sound_instances[| 2], 1, 1000)
			change_loop_points(loop_points3);
			change_loop_sound(sound_instances[| 2])
		}
		if pause_until_play {
			if t_state != -1
				save_points[t_state] = audio_sound_get_track_position(sound_instances[| t_state]) + 1
			audio_sound_set_track_position(sound_instances[| newstate], save_points[newstate])
		}
	})
	s.loop_points1 = _loop_points1
	s.loop_points2 = _loop_points2
	s.loop_points3 = _loop_points3
	s.pause_until_play = _pause_until_play
	return s;
}
function swap_three_tracks_intro(_soundlist, _loop_points1, _loop_points2, _loop_points3, pause_until_play = false) {
	var s = swap_three_tracks(_soundlist, [0, _loop_points1[1]], _loop_points2, _loop_points3, pause_until_play);
	with (s) {
		stepfunc = method(self, function () {
			if t_anyvar1 != -1 or is_undefined(ds_list_find_value(sound_instances, 0))
				return;
			if audio_sound_get_track_position(sound_instances[| 0]) > loop_points1[0] {
				change_loop_points(loop_points1);
				t_anyvar1 = 1	
			}
			
		}) 
	}
	s.loop_points1 = _loop_points1
	return s;
	
}

// the game still has remnants of old code which calls audio_stop_all. this didn't do anything for sounds played by fmod, but it does stop our sounds. we do not want this. i globally replaced all mentions of audio_stop_all with this function. much cooler
function audio_stop_all_cool() {
	
}
