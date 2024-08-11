/*
(This file is a Script resource inside the GameMaker project)

This file gives gml contents to every FMOD function the Pizza Tower Switch port (v1.1.063 SR 7) uses. By the popular demand of two (2) people, here's a public version with some comments
you may do whatever you want with it, as per the license on the GitHub (WTFPL). Credit would be nice.

*This will NOT work if you just import it into Pizza Tower! to see why, read below*

The purpose of this file is not to provide a general, accurate replacement for FMOD functionality (it's not) 
but to replicate just enough to make this game work, and to allow dictating sound behavior using GML code.

From what I've learned from this game, FMOD does not have sounds, but sound "events"
events can play multiple sounds, and you can pass parameters to them that have some effect on the output.
What this file essentially does is replace this FMOD event type with my own fmod_sound type.
The game still calls all the FMOD functions but they all direct to here since it's been removed, and now all the FMOD functions now operate on the fmod_sound type.

Defining the sound list for each sound, that is, the list of every sound file associated with it, would've been exhausting to do manually. 
So what I've opted to do is mod the original game on PC to play every sound event for 8 seconds, recording it, and then correctly matching up each sound recording to a name which 
is just the event name (but slashes replaced with underscores, since you can't have those in the name).
then, in case there is no manual definition for the event's sound list, it tries searching for a sound with the event name (with underscores), which would be our recorded file.
if there is no manual behavioral (code) definition for the event, it just plays the first sound out of the sound list. The result is that every single event that just plays a single sound is covered.
Not only that, it replicates any effects the developers might've added to the original raw sound. So it works really well for a lot of them.
The rest have been defined manually. For example, the barrel bump sound event, event:/sfx/barrel/bump, can play one of 7 sound files! using this method, the sound that was recorded will get played, and none of the other 6.
So I had to manually take those files out from the FMOD bank and place them in the port, and link them to that specific event.
all the music tracks were manually defined as well.

If you want to use this, you should probably copy the sound files from the port itself by dumping the contents.

Unrelated things you should read:

Any gain past 1 seems to just not work on this runtime version!!! (2023.2.0)
I've been increasing values like it does make a difference, but it seems not to if I set it to
very large values like 5, 10, or 50. So I've started manually increasing audio gains by changing the audio file.
You may see gain values over 1 in this file still, but I'm fairly sure they do nothing.

In the port, SFX audio files are assigned to audiogroup_sfx, music audio files are assigned to audiogroup_default,
and audiogroup_special exists so John pillar's Meatphobia track can be turned up while the music is turned down. 
I don't remember why it's done like this, probably for a good reason.

I modified random parts of the Pizza Tower source code to make specific sounds behave.
over time, some of these changes may have become obsolete due to me refining the code, but be wary.
more recently, I started putting comments on relevant events, so make sure to read them.

Yeah, a ds_map or even a struct would've probably been better instead of two gigantic switch statements.

To set up left and right panning, orient the listener like so:
audio_listener_orientation(0, 0, 1, 0, -1, 0);
To disable it, you can do this:
audio_listener_orientation(0, -1, 0, 1, 0, 0);

t_state and t_anyvar1 are deprecated and should not be used for new events.
Instead, t_anyvar1 should be replaced by variables in the create function, and t_state replaced by a variable that gets reset in the on_stop function.
I fear replacing them in the events that still use them might break things...

Regarding the Noise update:
The fmod parameter "isnoise", together with "swapmode", radically changes a lot of the events. 
We check for if either are active using global.fmod_is_noise_file. To check for just isnoise, we use global.fmod_is_noise.
To check for swapmode we can use the vanilla global variable global.swapmode.
It would have been really annoying to manually replicate the behavior of some of these sounds, so some were just recorded from the game.
You really should copy the sounds from the port.

If you have any questions open an issue on this repository. You could also post bug reports there for the port. I am looking.

Happy porting,
-D
*/
enum FMOD_PAUSE_ALL_STATES {
	NORMAL,
	PAUSE_FRAME,
	RESUME_FRAME
}	

function fmod_init(num) {
	if !audio_group_is_loaded(audiogroup_sfx)
		audio_group_load(audiogroup_sfx);
	if !audio_group_is_loaded(audiogroup_special)
		audio_group_load(audiogroup_special);
	
	
	audio_falloff_set_model(audio_falloff_linear_distance);
	
	global.sounds_to_play = []
	global.sounds_to_play_delays = []
	
	global.sounds_to_change_time = []
	global.sounds_to_change_time_amounts = []
	
	global.playing_sounds = []
	global.audio_silencers_map = ds_map_create()
	
	global.musicmuffle = false;
	global.pillarfade = 0;
	global.pillarmult = 1
	global.totemfade = 0
	global.totemmult = 1;
	
	global.clones = 0;
	global.clonemult = 1;
	
	global.fmod_pause_all_state = FMOD_PAUSE_ALL_STATES.NORMAL
	global.sounds_paused_all_list = []
	
	global.fmod_is_noise_file = false;
	global.fmod_is_noise = false;
	global.fmod_swap_music_frame = false;
}

function get_fmod_name(str) {
	return string_replace(str, "event:/", "")
}

enum SILENCE_ACTIONS {
	NOTHING,
	STOP,
	PAUSE
}

function audio_silencer(inst, frames, action) constructor {
	self.frames = frames;
	self.inst = inst;
	self.action = action;
}

function silence_audio_and_act(inst, frames, action = SILENCE_ACTIONS.STOP) {
	audio_sound_gain(inst, 0, frames * (1000 / 60))
	if (action == SILENCE_ACTIONS.NOTHING)
		return;
		
	ds_map_add(global.audio_silencers_map, inst, new audio_silencer(inst, frames, action))
}


function unsilence_audio(inst, frames, gain = 1) {
	audio_sound_gain(inst, gain, frames_to_ms(frames))
	ds_map_delete(global.audio_silencers_map, inst)
}


// I found this emitter to be good for basically all sounds
function fmod_emitter() {
	var e = audio_emitter_create()	
	audio_emitter_falloff(e, 400, 800, 1)
	return e;
}


function default_on_stop_func(natural) {
	if (!natural) {
		t_state = -1
		t_anyvar1 = -1
	}
}

function default_play_func(manual_ind = -1) {
	var ind = (manual_ind != -1) ? manual_ind 
		: (select_random ? (irandom_range(0, array_length(soundlist) - 1)) : (0));
	if soundlist[ind] == -1 {
		show_debug_message("MISSING SFX WITH CREATE NUMBER:" + string(num))
		return noone;	
	}
	
	var inst;
	var play_pitch = pitch + random_range(-pitch_vary, pitch_vary);
	if (!is_3d) {
		inst = audio_play_sound(soundlist[ind], 10, looping, self.gain, bounds[0], play_pitch)	
	}
	else {
		inst = audio_play_sound_on(emitter, soundlist[ind], looping, 10, self.gain, bounds[0], play_pitch);
	}
		
	audio_sound_loop_start(inst, bounds[0])
	audio_sound_loop_end(inst, bounds[1])
	
	array_push(main_instances, inst)
	array_push(instances, inst)
	return inst;
}

function default_stopped_condition() {
	return array_length(instances) == 0	
}

function empty_func() {
}

function fmod_sound(soundlist) 
		constructor {
	self.soundlist = soundlist
	self.num = global.createnumber
	
	main_instances = []
	instances = []
	instances_to_unpause = []
	
	pitch = 1;
	function set_pitch(pitch) {
		self.pitch = pitch
		return self;
	}
	pitch_vary = 0;
	function set_pitch_vary(pitch_vary) {
		self.pitch_vary = pitch_vary
		return self;
	}
	gain = 1;
	function set_gain(gain) {
		self.gain = gain;
		return self;
	}
	select_random = false;
	function should_select_random() {
		self.select_random = true
		return self;
	}
	
	looping = false;
	function should_loop() {
		self.looping = true;
		return self;
	}
	bounds = [0, 0]
	function set_bounds(start, endp) {
		self.bounds = [start, endp];
		return self;
	}
	
	fadeout_duration = 90;
	function set_fadeout_duration(fadeout_duration) {
		self.fadeout_duration = fadeout_duration
		return self;
	}
	
	
	is_3d = false;
	emitter = noone;
	function set_3d(emitter = fmod_emitter()) {
		self.is_3d = true;
		self.emitter = emitter;
		return self;
	}
	
	max_delay = 0;
	function set_delay(delay) {
		self.max_delay = delay;
		return self;
	}
	
	on_create = method(self, empty_func)
	function set_create_func(create_func) {
		self.on_create = method(self, create_func);
		on_create(); // I think this is kinda funny.
		return self;
	}
	
	play = method(self, default_play_func)
	function set_play_func(play_func) {
		self.play = method(self, play_func);
		return self;
	}
	
	on_update = method(self, empty_func);
	function set_update_func(update_func) {
		self.on_update = method(self, update_func);
		return self;
	}
	
	on_stop = method(self, default_on_stop_func);
	function set_on_stop_func(on_stop_func) {
		self.on_stop = method(self, on_stop_func);
		return self;
	}
	
	on_state_change = method(self, empty_func);
	function set_state_func(state_func) {
		self.on_state_change = method(self, state_func);
		return self;
	}
	
	on_other_change = method(self, empty_func);
	function set_other_func(other_func) {
		self.on_other_change = method(self, other_func);
		return self;
	}
	
	on_noise_change = method(self, empty_func);
	function set_noise_func(noise_func) {
		self.on_noise_change = method(self, noise_func);
		return self;
	}

	// This is set for 3d one shot sounds, since their emitter needs to be freed.
	release_when_stopped = false;

	// The relevant instance, for music, is the instance that is relevant for time manipulation.
	// This is made so, if the game tries to change an fmod_sound's timeline position, the script will know which one it should change.
	relevant_instance = noone
	function set_relevant_instance(instance) {
		relevant_instance = instance;
	}
	function has_relevant_instance() {
		return audio_is_playing(relevant_instance)
	}
	
	is_default_stopped_condition = true // optimization
	
	// The stopped condition is the condition required for the sound to be considered stopped
	stopped_condition = method(self, default_stopped_condition);
	function set_stopped_condition(stopped_condition) {
		self.stopped_condition = method(self, stopped_condition);
		self.is_default_stopped_condition = false;
		return self;
	}
	
	t_anyvar1 = -1
	t_state = -1
	state = -1
	function stop_currently_playing_instances() {
		var len = array_length(instances)
		if len == 0
			return;
		for (var i = 0; i < len; i++) 
			audio_stop_sound(instances[i])
		instances = []
		if array_length(main_instances) != 0
			main_instances = []
		if array_length(instances_to_unpause) != 0
			instances_to_unpause = []
	}
	
	function stop(instantly) {
		var ind = array_get_index(global.sounds_to_play, self)
		if ind != -1 {
			array_delete(global.sounds_to_play, ind, 1)
			array_delete(global.sounds_to_play_delays, ind, 1)
			return;
		}
		var len = array_length(instances)
		if len == 0
			return;
		
		if (instantly) {
			stop_currently_playing_instances()
			return;	
		}
		else {
			for (var i = 0; i < len; i++)  
				silence_audio_and_act(instances[i], fadeout_duration, SILENCE_ACTIONS.STOP)
		}
	}
	

	
}


function fmod_event_instance_play(snd) {
	array_push(global.sounds_to_play, snd)
	array_push(global.sounds_to_play_delays, snd.max_delay)
}
	
function fmod_event_instance_stop(snd, instantly = true, scary_unknown_boolean = false) {
	if is_string(snd) {
		var soundlist = get_soundlist(get_fmod_name(snd))
		if instantly == true {
			for (var i = 0; i < array_length(soundlist); i++)  
				audio_stop_sound(soundlist[i])
		}
		else {
			for (var i = 0; i < array_length(soundlist); i++) 
				silence_audio_and_act(soundlist[i], 90, SILENCE_ACTIONS.STOP)
		}
		return;
	}
	with (snd) {
		stop(instantly);
		on_stop(false);
	}
}

function fmod_event_one_shot(str) {
	var snd = fmod_event_create_instance(str)
	fmod_event_instance_play(snd)
	return snd;
}
function fmod_event_one_shot_3d(str, _x = x, _y = y) {
	var snd = fmod_event_one_shot(str)
	snd.release_when_stopped = true;
	with (snd) {
		if is_3d
			audio_emitter_position(emitter, _x, _y, 0)
	}
}

function fmod_event_instance_set_parameter(snd, somestring, somenum, someboolean) {
	with snd {
		switch (somestring) {
			case "state":
				if somenum != t_state
					on_state_change(somenum)
				state = somenum
				t_state = somenum
				break;
			default:
				on_other_change(somenum);	
		}
	}
}

function fmod_event_instance_get_parameter(snd, somestring) {
	with snd {
		switch (somestring) {
			case "state":
				return t_state;
			default:
				print("No parameter!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
		}
	}
}

function fmod_event_instance_release(snd) {
	if (snd.is_3d) {
		snd.is_3d = false;
		audio_emitter_free(snd.emitter) 
	}
}
function fmod_event_instance_set_3d_attributes(snd, _x, _y) {
	with (snd) {
		if is_3d
			audio_emitter_position(emitter, _x, _y, 0)
	}
}
function fmod_event_instance_is_playing(snd) {
	if is_string(snd) {
		var soundlist = get_soundlist(get_fmod_name(snd))
		for (var i = 0; i < array_length(soundlist); i++)  {
			if audio_is_playing(soundlist[i]) 
				return true;
		}
		return false;
	}
	with (snd) {
		if array_get_index(global.sounds_to_play, snd) != -1 
			return true;
		if array_get_index(global.playing_sounds, snd) != -1 
			return true;
	}	
	return false;
}




function fmod_set_num_listeners(num) {
	
}
function fmod_bank_load(something, thing) {
}

function fmod_get_parameter(somestring, somenum, someboolean) {
	switch (somestring) {
		case "isnoise":
			return global.fmod_is_noise
	}
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
			var val = (1 - somenum);
			global.clonemult = val * val;
			break;
		case "isnoise":
			global.fmod_is_noise_file = somenum
			if global.fmod_is_noise != somenum {
				global.fmod_is_noise = somenum
				if global.swapmode
					global.fmod_swap_music_frame = true;
			}
			
			break;
		case "swapmode":
			global.fmod_is_noise_file = somenum || global.fmod_is_noise_file;
			break;
	}
}

function fmod_set_listener_attributes(x_1, y_2, somenum) {
	
}


function fmod_event_instance_get_timeline_pos(snd) {
	var time = 0;
	with (snd) {
		
		if has_relevant_instance()
			return audio_sound_get_track_position(relevant_instance)
		
		for (var i = 0; i < array_length(instances); i++) {
			if audio_is_playing(instances[i])
				time = max(time, audio_sound_get_track_position(instances[i]));
		}
	}
	return time;
}

function fmod_event_instance_set_timeline_pos(snd, time) {
	array_push(global.sounds_to_change_time, snd)
	array_push(global.sounds_to_change_time_amounts, time)
	/*
	with (snd) {
		if has_relevant_instance() {
			audio_sound_set_track_position(relevant_instance, time)
			return;	
		}
		
		for (var i = 0; i < array_length(instances); i++) {
			if audio_is_playing(instances[i]) 
				audio_sound_set_track_position(instances[i], time)
		}
	}
	*/
}


function fmod_update() {
	
	var silencers = []
	ds_map_values_to_array(global.audio_silencers_map, silencers)
	var silencers_len = array_length(silencers)
	for (var i = 0; i < silencers_len; i++) {
		var silencer = silencers[i];
			
		silencer.frames--;
		if (silencer.frames <= 0) {
			if (silencer.action = SILENCE_ACTIONS.STOP)
				audio_stop_sound(silencer.inst)
			else if (silencer.action == SILENCE_ACTIONS.PAUSE)
				audio_pause_sound(silencer.inst)
			ds_map_delete(global.audio_silencers_map, silencer.inst)
		}
	}
	var run_noise_func;
	if global.fmod_swap_music_frame {
		run_noise_func = true;
		global.fmod_swap_music_frame = false;
	}
	else
		run_noise_func = false;
	

	audio_group_set_gain(audiogroup_sfx, global.option_sfx_volume * global.option_master_volume, 0)
	
	var mufflemult = (global.musicmuffle == 0) ? 1 : 0.15
	global.pillarmult = Approach(global.pillarmult, global.pillarfade, 0.03)
	global.totemmult = Approach(global.totemmult, global.totemfade * 0.5, 0.05)
	
	var vol = global.option_music_volume * global.option_master_volume * mufflemult * (1 - global.totemmult) 
	audio_group_set_gain(audiogroup_default, vol * (1 - global.pillarmult), 0)
	audio_group_set_gain(audiogroup_special, vol * global.pillarmult, 0)
	
	var to_play_len = array_length(global.sounds_to_play)
	for (var i = 0; i < to_play_len; i++) {
			
		if (global.sounds_to_play_delays[i] > 0) {
			global.sounds_to_play_delays[i]--;
			continue;
		}
		var snd = global.sounds_to_play[i];	
		snd.play()
		array_push(global.playing_sounds, snd);
				
		array_delete(global.sounds_to_play, i, 1)
		array_delete(global.sounds_to_play_delays, i, 1)
		i--;
		to_play_len--;
	}
		
		

	var change_time_len = array_length(global.sounds_to_change_time);
	for (var i = 0; i < change_time_len; i++) {
		
		var snd = global.sounds_to_change_time[i];	
		var time = global.sounds_to_change_time_amounts[i];
	
	
		with (snd) {
			if has_relevant_instance() {
				audio_sound_set_track_position(relevant_instance, time)
				break;
			}
		
			for (var j = 0; j < array_length(instances); j++) {
				if audio_is_playing(instances[j]) 
					audio_sound_set_track_position(instances[j], time)
			}
		}
	
		array_delete(global.sounds_to_change_time, i, 1)
		array_delete(global.sounds_to_change_time_amounts, i, 1)
		i--;
		change_time_len--;
	}
		
		


	
	var playing_len = array_length(global.playing_sounds)
	if (global.fmod_pause_all_state == FMOD_PAUSE_ALL_STATES.PAUSE_FRAME) {
		for (var i = 0; i < playing_len; i++) {
			var snd = global.playing_sounds[i];	
			if !fmod_event_instance_get_paused(snd) {
				fmod_event_instance_set_paused(snd, true)
				array_push(global.sounds_paused_all_list, snd)
			}
		}
		global.fmod_pause_all_state = FMOD_PAUSE_ALL_STATES.NORMAL;
		
	}
	else if (global.fmod_pause_all_state == FMOD_PAUSE_ALL_STATES.RESUME_FRAME) {
		
		for (var i = 0; i < array_length(global.sounds_paused_all_list); i++) {
			var snd = global.sounds_paused_all_list[i];	
			fmod_event_instance_set_paused(snd, false)
		}
		global.sounds_paused_all_list = []
		
		global.fmod_pause_all_state = FMOD_PAUSE_ALL_STATES.NORMAL;
		
	}
	
	for (var i = 0; i < playing_len; i++) {
		var snd = global.playing_sounds[i];	
		var main_instances_len = array_length(snd.main_instances);
		if run_noise_func
			snd.on_noise_change();	
		
		for (var j = 0; j < main_instances_len; j++) {
			var inst = snd.main_instances[j];
			if !audio_is_playing(inst) {
				array_delete(snd.main_instances, j, 1);
				j--;
				main_instances_len--;
				continue;
			}
			
			if snd.looping != audio_sound_get_loop(inst)
				audio_sound_loop(inst, snd.looping)
			if (audio_sound_get_loop_start(inst) != snd.bounds[0] || audio_sound_get_loop_end(inst) != snd.bounds[1]) {
				// I can't be bothered to explain why these two lines are needed. They are.
				audio_sound_loop_start(inst, 0)
				audio_sound_loop_end(inst, 0)
					
				audio_sound_loop_start(inst, snd.bounds[0])
				audio_sound_loop_end(inst, snd.bounds[1])
			}
			if !audio_is_paused(inst) {
				if (audio_sound_get_loop_end(inst) != 0) {
					if audio_sound_get_track_position(inst) > audio_sound_get_loop_end(inst) {
						if (audio_sound_get_loop(inst))
							audio_sound_set_track_position(inst, audio_sound_get_loop_start(inst))
						else {
							audio_stop_sound(inst)
							array_delete(snd.instances, j, 1);
							j--;
							main_instances_len--;
							continue;
						}
					}
				}
				
				if audio_sound_get_track_position(inst) < audio_sound_get_loop_start(inst)
					audio_sound_set_track_position(inst, audio_sound_get_loop_start(inst))
			}

			
		}
		
		var instances_len = array_length(snd.instances);
		
		for (var j = 0; j < instances_len; j++) {
			var inst = snd.instances[j];
			if !audio_is_playing(inst) {
				array_delete(snd.instances, j, 1);
				j--;
				instances_len--;
				continue;
			}
			

		}

		var stopped = snd.is_default_stopped_condition ? instances_len == 0 : snd.stopped_condition();
		if (stopped) {
			array_delete(global.playing_sounds, i, 1);
			snd.on_stop(true);
			if (snd.release_when_stopped)
				fmod_event_instance_release(snd);
			i--;
			playing_len--;
			continue;
		}
		else
			snd.on_update()
	}
}

function fmod_event_get_length(str) {
	var soundlist = get_soundlist(get_fmod_name(str))
	var num = 1
	for (var i = 0; i < array_length(soundlist); i++) {
		if audio_sound_length(soundlist[i])	> num 
			num = audio_sound_length(soundlist[i])
	}
	return num;
}


function fmod_event_instance_set_paused(snd, paused) {
	with (snd) {
		if (paused) {
			for (var i = 0; i < array_length(instances); i++) {
				var inst = instances[i];
				if !audio_is_paused(inst) {
					audio_pause_sound_insist(inst)
					if ds_map_exists(global.audio_silencers_map, inst) {
						var silencer = ds_map_find_value(global.audio_silencers_map, inst)
						if (silencer.action == SILENCE_ACTIONS.PAUSE)
							continue;
					}
					array_push(instances_to_unpause, inst)
				}
			}

		}
		else {
			if array_length(instances_to_unpause) == 0
				return;
			
			for (var i = 0; i < array_length(instances_to_unpause); i++) {
				var inst = instances_to_unpause[i];
				audio_resume_sound(inst)
			}
			instances_to_unpause = []
		}
	}
}

function fmod_event_instance_get_paused(snd) {
	with (snd) {

		return array_length(instances_to_unpause) != 0
	}
	return false;
}


function fmod_event_instance_set_paused_all(paused) {
	global.fmod_pause_all_state = (paused) 
		? FMOD_PAUSE_ALL_STATES.PAUSE_FRAME 
		: FMOD_PAUSE_ALL_STATES.RESUME_FRAME;
}

function fmod_destroy() {
	
}


function get_soundlist(soundname) { 
	switch (soundname) {
		case "sfx/misc/clotheswitch":
			return [switch1]
		case "sfx/ui/fileselect":
			return [FileSelect1, FileSelect2, FileSelect3]
		case "sfx/ui/select":
			return [MenuSelect1, MenuSelect2, MenuSelect3]
		case "sfx/pep/mach":
			return [sfx_mach1, sfx_mach2, sfx_mach3, sfx_mach4]
		case "sfx/pep/jump":
			return [sfx_pep_jump, noise_jump]
		case "sfx/playerN/mach":
			return [mach, mach2step, mach3step]
		case "sfx/playerN/minijetpack":
			return [minijetpack]
		case "sfx/voice/ok":
			return [Voice_20, Voice_21, Noise5, Noise3]
		case "sfx/voice/myea":
			return [Voice_18, Voice_19, Voice_20, Voice_21, Noise3, Noise5, Noise2, Noise6]
		case "sfx/voice/noisepositive":
			return [Noise3, Noise5, Noise2, Noise6]
		case "sfx/voice/noisenegative":
			return [Noise1, Noise4]
		case "sfx/voice/hurt":
			return [Voice_10, Voice_11, Noise1, Noise4]
		case "sfx/pep/fireass":
			return [sfx_pep_fireass, noise_fireass]
		case "sfx/misc/spaceship":
			return [sfx_misc_spaceship, noise_spaceship]
		case "sfx/misc/transfo":
			return [sfx_misc_transfo, noise_transfo]
		case "sfx/voice/transfo":
			return [Voice_14, Voice_22, Voice_23]
		case "sfx/voice/outtransfo":
			return [Voice_12, Voice_18, Voice_19, Noise2, Noise3, Noise6]
		case "sfx/voice/swap":
			return [Voice_13, Voice_20, Voice_21, Noise2, Noise3, Noise5, Voice_04, Voice_06, Voice_09]
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
		case "sfx/playerN/bossdeath":
			return [bossdeath]
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
		case "sfx/playerN/fightball":
			return [noisefightball1, noisefightball2, noisefightball3, noisefightball4, noisefightball5, noisefightball6, noisefightball7, noisefightball8, noisefightball9] 
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
		case "sfx/misc/bossbeaten":
			return [BOSS_BEATEN_JINGLE, noise_defeat_boss]
		case "sfx/intro/pepgustavointro":
			return [sfx_intro_pepgustavointro, Noise_Intro_2]
		case "sfx/playerN/ghostdash":
			return [ghostdash1, ghostdash2, ghostdash3]
		case "sfx/playerN/finaljudgement_drumroll":
			return [finaljudgement2]
		case "sfx/playerN/finaljudgement_verdict":
			return [finaljudgementbad, finaljudgementgood]
		case "music/pillarmusic":
			return [mu_dungeondepth]
		case "music/intro":
			return [Pizza_Tower_OST___Time_for_a_Smackdown] 
		case "music/title":
			return [mu_title, lario_s_secret, fnaf2_secret]
		case "music/tutorial":
			return [mu_funiculi]
		case "music/pizzatime":
			return [mu_pizzatime, mu_chase, Pillar_Johns_Revenge, DISTASTEFUL_ANCHOVI_JC_RE_EDIT_v5c, World_Wide_Noise_v6_yo_how_many_times_am_i_just_gonna_keep_chan, mu_lap3_noise]
		case "music/hub":
			return [mu_hub, Pizza_Tower_OST___Tuesdays, mu_hub3, pizza_tower___industrial_hub, mu_hub4]
		case "music/w1/entrancetitle":
			return [entrance, entrance_noise]
		case "music/w1/entrance": 
			return [Unearthly_Blues, Pizza_Tower_OST___The_Noises_Jam_Packed_Radical_Anthem]
		case "music/w1/entrancesecret": 
			return [Pizza_Tower___Entrance_Secret_V1]
		case "music/w1/medievaltitle":
			return [medieval, pizzascape_noise]
		case "music/w1/medieval": 
			return [mu_medievalentrance, Pizza_Tower_OST___Cold_Spaghetti]
		case "music/w1/medievalsecret": 
			return [mu_medievalsecret]
		case "music/w1/ruintitle":
			return [ruin, ancient_noise]
		case "music/w1/ruin":
			return [mu_ruin, mu_ruinremix]
		case "music/w1/ruinsecret":
			return [mu_ruinsecret]
		case "music/w1/dungeontitle":
			return [dungeon, bloodsauce_noise]
		case "music/w1/dungeon":
			return [Pizza_Tower___Dungeon_Freakshow_v222]
		case "music/w1/dungeonsecret":
			return [mu_dungeonsecret]
		case "music/w2/deserttitle":
			return [oregano, oregano_noise]
		case "music/w2/desert":
			return [mu_desert, mu_ufo]
		case "music/w2/desertsecret":
			return [mu_desertsecret]
		case "music/w2/saloontitle":
			return [saloon, cowboy_noise]
		case "music/w2/saloon":
			return [mu_saloon]
		case "music/w2/saloonsecret":
			return [mu_saloonsecret]
		case "music/w2/farmtitle":
			return [mort_farm, mort_the_noise]
		case "music/w2/farm":
			return [mu_farm, Pizza_Tower___Whats_on_the_Kids_Menu]
		case "music/w2/farmsecret":
			return [mu_farmsecret]
		case "music/w2/graveyardtitle":
			return [graveyard, wasteyard_noise]
		case "music/w2/graveyard":
			return [mu_graveyard]
		case "music/w2/graveyardsecret":
			return [Pizza_Tower___An_Undead_Secret]
		case "music/w3/beachtitle":
			return [beach, plage_noise]
		case "music/w3/beach":
			return [mu_beach]
		case "music/w3/beachsecret":
			return [Pizza_Tower___A_Secret_in_the_Sands]
		case "music/w3/foresttitle":
			return [gnome, lario_noise]
		case "music/w3/forest":
			return [Pizza_Tower___mmm_yess_put_the_tree_on_my_pizza, mu_gustavo, mu_forest]
		case "music/w3/forestsecret":
			return [Pizza_Tower___A_Secret_in_The_Trees]
		case "music/w3/golftitle":
			return [good_eating, golf_noise]
		case "music/w3/golf":
			return [mu_minigolf]
		case "music/w3/golfsecret":
			return [Pizza_Tower___A_Secret_Hole_in_One]
		case "music/w3/spacetitle":
			return [spacetitle, deep_dish_noise]
		case "music/w3/space":
			return [Pizza_Tower_OST___Extraterrestrial_Wahwahs]
		case "music/w3/spacesecret":
			return [mu_pinballsecret]
		case "music/w4/freezertitle":
			return [freezer, freezer_noise]
		case "music/w4/freezer":
			return [_39_Don_t_Preheat_Your_Oven_Because_If_You_Do_The_Song_Won_t_Pla, Pizza_Tower___Celcius_Troubles, Pizza_Tower_OST___On_the_Rocks]
		case "music/w4/freezersecret":
			return [Pizza_Tower___A_Frozen_Secret]
		case "music/w4/industrialtitle":
			return [factory, factory_noise]
		case "music/w4/industrial":
			return [mu_industrial, Pizza_Tower_OST___Peppinos_Sauce_Machine]
		case "music/w4/industrialsecret":
			return [Pizza_Tower___An_Industry_Secret]
		case "music/w4/sewertitle":
			return [sewer, toxic_noise]
		case "music/w4/sewer":
			return [mu_sewer]
		case "music/w4/sewersecret":
			return [secret_sewer]
		case "music/w4/streettitle":
			return [pig_city, city_noise]
		case "music/w4/street":
			return [Pizza_Tower_OST___Bite_the_Crust, Pizza_Tower_OST___Way_of_the_Italian, mu_dungeondepth2]
		case "music/w4/streetsecret":
			return [Pizza_Tower___A_Secret_In_These_Streets]
		case "music/w5/chateautitle":
			return [chateau, scary_noise]
		case "music/w5/chateau":
			return [Pizza_Tower_OST___Theres_a_Bone_in_my_Spaghetti]
		case "music/w5/kidspartytitle":
			return [kids_party, kidsparty_noise]
		case "music/w5/kidsparty":
			return [Pizza_Tower_OST___Tunnely_Shimbers]
		case "music/w5/kidspartysecret":
			return [Pizza_Tower___A_Secret_You_Dont_Want_To_Find]
		case "music/w5/wartitle":
			return [war, war_noise]
		case "music/w5/war":		
			return [mu_war]
		case "music/w5/warsecret":
			return [Pizza_Tower___A_War_Secret]
		case "music/boss/pepperman":
			return [Pizza_Tower_OST___Pepperman_Strikes]
		case "music/boss/vigilante":
			return [mu_vigilante, duel]
		case "music/boss/noise":
			return [Pizza_Tower_OST___Pumpin_Hot_Stuff, Pizza_Tower_OST___Doise_At_the_Door_1_]
		case "music/boss/noisette":
			return [mus_noisette]
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
			return [Pizza_Tower_OST___Bye_Bye_There, byebyethere_remix_2_new_mix]
		case "music/w5/finalhallway":
			return [pt_scary_ambient_draft_1]
		case "music/boss/pizzaface":
			return [Pizza_Tower_OST___Unexpectancy_Part_1_of_3, Pizza_Tower_OST___Unexpectancy_Part_2_of_3, Pizza_Tower_OST___Unexpectancy_Part_3_of_3, UNEXPECTANCY_CLASCYJITTO_I_GATCHA_PASSWORD_REMIX_v2]
		case "sfx/ending/towercollapsetrack":
			return [Pizza_Tower___Pizza_Pie_ing_slight_remaster, Voice_13, Voice_05, BrickSniff1, Noise3, sfx_noisette_voice2]
		case "sfx/ending/johnending":
			return [sfx_ending_johnending, noise_john_ending]
		case "music/credits":
			return [Pizza_Tower_OST___Receiding_Hairline_Celebration_Party, mu_minigolf, mu_funiculi, _59_BONUS_Choosing_the_Toppings, New_Noise_Resolutionz_v4]
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
		case "music/soundtest/entrancenoise":
			return [Pizza_Tower_OST___The_Noises_Jam_Packed_Radical_Anthem]
		case "music/soundtest/doise":
			return [Pizza_Tower_OST___Doise_At_the_Door_1_]
		case "music/soundtest/pizzatimenoise":
			return [DISTASTEFUL_ANCHOVI_JC_RE_EDIT_v5c]
		case "music/soundtest/lap2noise":
			return [World_Wide_Noise_v6_yo_how_many_times_am_i_just_gonna_keep_chan]
		case "music/soundtest/pizzaheadnoise":
			return [UNEXPECTANCY_CLASCYJITTO_I_GATCHA_PASSWORD_REMIX_v2]
		case "music/soundtest/noisefinalescape":
			return [byebyethere_remix_2_new_mix]
		case "music/soundtest/creditsnoise":
			return [New_Noise_Resolutionz_v4]
		case "music/soundtest/lap3noise":
			return [mu_lap3_noise]
		case "music/soundtest/secretworld":
			return [Secret_Lockin_v1a]
		case "music/soundtest/halloweenrace":
			return [Final_The_Runner_10_15_2023_Halloween_Event_2023_1_]
		case "music/soundtest/halloweenstart":
			return [The_Bone_Rattler]
		case "music/soundtest/halloweenpause":
			return [Spacey_Pumpkins]
		case "music/halloween2023":
			return [The_Bone_Rattler, Final_The_Runner_10_15_2023_Halloween_Event_2023_1_]
		case "music/secretworldtitle":
			return [secret_level_intro]
		case "music/secretworld":
			return [Secret_Lockin_v1a]
		case "music/characterselect":
			return [_64_BONUS_Move_It__Boy]
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
	
	var soundname = get_fmod_name(soundpath)
	var soundlist = get_soundlist(soundname)

	switch (soundname) {
		default:
			return new fmod_sound(soundlist).should_select_random() // this will work for most sounds. the rest of the entries here are for sounds who need more than this
		case "sfx/pep/rollgetup":
			return new fmod_sound(soundlist).set_gain(1.3)
		case "sfx/voice/noisepositive":
		case "sfx/voice/noisenegative":
			return new fmod_sound(soundlist).set_3d().set_pitch_vary(0.05).set_gain(0.55)
			.set_play_func(function () {
				if !global.fmod_is_noise {
					default_play_func(irandom_range(0, array_length(soundlist) - 1))
					return;
				}
				pitch = 0.5
				default_play_func(irandom_range(0, array_length(soundlist) - 1))
			})
		case "sfx/voice/noisescream":
			return new fmod_sound(soundlist).set_3d().set_pitch_vary(0.02).set_play_func(function () {
				if !global.fmod_is_noise_file {
					default_play_func()
					return;
				}
				pitch = 0.5
				default_play_func()
			})
		case "sfx/voice/fakepeppositive":
		case "sfx/voice/fakepepnegative":
			return new fmod_sound(soundlist).set_3d().should_select_random().set_pitch_vary(0.05)
		case "sfx/misc/clotheswitch":
			return new fmod_sound(soundlist).should_select_random().set_pitch_vary(0.15).set_bounds(0, 0.4)
		case "sfx/noise/balloon":
			return new fmod_sound(soundlist).should_loop().set_gain(2)
		case "sfx/ui/angelmove":
		case "sfx/pizzahead/thunder":
		case "sfx/voice/vigiduel":
		case "sfx/voice/fakepepscream":
		case "sfx/fakepep/taunt":
			return new fmod_sound(soundlist).set_pitch_vary(0.15)
		case "sfx/pizzahead/beatdown":
			return new fmod_sound(soundlist).set_pitch_vary(0.15).set_gain(1.2)
		case "sfx/misc/elevatorsqueak":	
		case "sfx/pep/screamboss":
			return new fmod_sound(soundlist).set_pitch_vary(0.04).set_play_func(function (){
				if array_length(instances) != 0 // game plays this twice for no reason
					return;
				default_play_func()	
			})
		case "sfx/voice/peppermansnicker":
		case "sfx/voice/vigiangry":
			return new fmod_sound(soundlist).set_pitch(0.95).set_pitch_vary(0.15)
		case "sfx/voice/peppermanscared":
			return new fmod_sound(soundlist).set_pitch(1.05).set_pitch_vary(0.1)
		case "sfx/pep/groundpound":
			return new fmod_sound(soundlist).set_gain(0.8)
		case "sfx/playerN/firemouthjump":
			return new fmod_sound(soundlist).set_fadeout_duration(15);
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
			return new fmod_sound(soundlist).set_3d().should_select_random().should_loop()
		case "sfx/voice/pizzahead":
			return new fmod_sound(soundlist).set_3d().set_gain(2.3)
		case "sfx/barrel/bump":
			return new fmod_sound(soundlist).set_3d().set_gain(1.8)
	

		case "sfx/misc/bossbeaten":
			return new fmod_sound(soundlist).set_gain(1.2).set_play_func(function () {
				default_play_func(global.fmod_is_noise_file)	
			})
		case "sfx/voice/mrsticklaugh":
		case "sfx/voice/pig":
		
		case "sfx/noise/fightball":
		case "sfx/playerN/fightball":
		case "sfx/pep/slipbump":
		case "sfx/pep/slipend":
			return new fmod_sound(soundlist).set_3d().should_select_random()
		case "sfx/pep/uppercut":
			return new fmod_sound(soundlist).set_3d().should_select_random().set_pitch(1.2).set_pitch_vary(0.1)
		case "sfx/voice/pizzagranny":
			return new fmod_sound(soundlist).set_3d().should_select_random().set_pitch(1.1).set_pitch_vary(0.1)
		case "sfx/pep/gotsupertaunt":
			return new fmod_sound(soundlist).set_gain(1.1)
		case "sfx/enemies/noisegoblinbow":
			return new fmod_sound(soundlist).set_gain(0) // seems to be quiet in the original game...
		case "sfx/misc/toppinhelp":
		case "sfx/rat/ratdead":
		case "sfx/misc/thundercloud":
		case "sfx/misc/kashing":
		case "sfx/enemies/kill":
		case "sfx/ratmount/ball":
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
		case "sfx/pep/machslideboost":
		case "sfx/enemies/comingoutground":
		case "sfx/enemies/batwing":
		case "sfx/enemies/ninjakicks":
		case "sfx/misc/sniffbump":
		case "sfx/pep/bombbounce":
		case "sfx/enemies/pizzardelectricity":
		case "sfx/pep/superjumpcancel":
		case "sfx/misc/golfbump":
		case "sfx/misc/golfpunch":
		case "sfx/enemies/killingblow":
		case "sfx/misc/rockbreak":
			return new fmod_sound(soundlist).set_3d();
		case "sfx/pep/bombfuse":
			return new fmod_sound(soundlist).set_3d().set_gain(1.1)
		case "sfx/misc/mushroombounce":
			return new fmod_sound(soundlist).set_3d().set_gain(2.2);
		case "sfx/kingghost/move":
			var emitter = audio_emitter_create()
			audio_emitter_falloff(emitter, 200, 400, 1)
			return new fmod_sound(soundlist).set_3d(emitter).set_gain(0.8).set_play_func(function() {
				stop_currently_playing_instances()
				default_play_func()
			});
		case "sfx/pep/hurt":
			return new fmod_sound(soundlist).set_3d().should_select_random().set_pitch_vary(0.1).set_play_func(function () {
				default_play_func()
				if global.fmod_is_noise {
					var guitar = audio_play_sound(hurt, 10, false, 0.6, 0, random_range(-0.1, 0.1));
					array_push(instances, guitar);
				}
			})
		case "sfx/hub/gusbrickfightball":
		case "sfx/misc/collect":
		case "sfx/misc/bellcollect":
		case "sfx/enemies/coughing":
		case "sfx/enemies/escapespawn":
		case "sfx/pep/parry":
		case "sfx/antigrav/bump":
		case "sfx/playerN/minigunshot":
			return new fmod_sound(soundlist).set_3d().should_select_random().set_pitch_vary(0.1)
		case "sfx/voice/gushurt":
		case "sfx/voice/gusok":
			return new fmod_sound(soundlist).set_3d().should_select_random().set_pitch_vary(0.2).set_gain(0.6)
		case "sfx/voice/enemyrarescream":
			return new fmod_sound(soundlist).set_3d().should_select_random().set_pitch_vary(0.25)
		case "sfx/voice/myea":
			return new fmod_sound(soundlist).set_3d().set_pitch_vary(0.2).set_play_func(function () {
				default_play_func(global.fmod_is_noise * 4 + irandom_range(0, 3))
			});
		case "sfx/voice/transfo":
			return new fmod_sound(soundlist).set_3d().set_pitch_vary(0.1).set_play_func(function () {
				if global.fmod_is_noise
					return;
				default_play_func(irandom_range(0, 2))
			});
		case "sfx/voice/ok":
		case "sfx/voice/hurt":
			return new fmod_sound(soundlist).set_3d().set_pitch_vary(0.1).set_gain(0.6).set_play_func(function () {
				self.gain = global.fmod_is_noise ? 0.4 : 0.6;
				default_play_func(global.fmod_is_noise * 2 + irandom_range(0, 1))
			});
		case "sfx/voice/swap": 
			return new fmod_sound(soundlist).set_3d().set_play_func(function () {
				default_play_func(state * 3 + irandom_range(0, 2))
			});
		case "sfx/voice/outtransfo":
			return new fmod_sound(soundlist).set_3d().set_pitch_vary(0.1).set_play_func(function () {
				default_play_func(global.fmod_is_noise * 3 + irandom_range(0, 2))
			});
		case "sfx/misc/transfo":
		case "sfx/misc/spaceship":
		case "sfx/pep/jump":
			return new fmod_sound(soundlist).set_play_func(function () {
				default_play_func(global.fmod_is_noise)	
			})
		case "sfx/pep/fireass":
		case "sfx/ending/johnending":
		case "sfx/intro/pepgustavointro":
		case "music/finalescape":
		case "music/w1/entrancetitle":
		case "music/w1/medievaltitle":
		case "music/w1/ruintitle":
		case "music/w1/dungeontitle":
		case "music/w2/deserttitle":
		case "music/w2/saloontitle":
		case "music/w2/farmtitle":
		case "music/w2/graveyardtitle":
		case "music/w3/beachtitle":
		case "music/w3/foresttitle":
		case "music/w3/golftitle":
		case "music/w3/spacetitle":
		case "music/w4/freezertitle":
		case "music/w4/industrialtitle":
		case "music/w4/sewertitle":
		case "music/w4/streettitle":
		case "music/w5/chateautitle":
		case "music/w5/kidspartytitle":
		case "music/w5/wartitle":
			return new fmod_sound(soundlist).set_play_func(function () {
				default_play_func(global.fmod_is_noise_file)	
			})
		
		case "sfx/voice/mrstick":
		case "sfx/voice/brickok":
		case "sfx/enemies/presentfall":
			return new fmod_sound(soundlist).set_3d().should_select_random().set_pitch_vary(0.2)
		case "sfx/pipe/bump":	
			return new fmod_sound(soundlist).set_3d().should_select_random().set_gain(2.5)
		case "sfx/pep/mach":
			return new fmod_sound(soundlist).set_3d().set_play_func(function() {
				if t_state >= 1 {
					stop_currently_playing_instances()
					var inst = audio_play_sound_on(emitter, soundlist[t_state - 1], true, 10)
					array_push(instances, inst)
				}
			}).set_state_func(function(new_state) {
				if fmod_event_instance_is_playing(self) {
					stop_currently_playing_instances()
					if new_state == 0
						return;
					var inst = audio_play_sound_on(emitter, soundlist[new_state - 1], true, 10)
					array_push(instances, inst)
				}
			});
		case "sfx/playerN/mach":
			return new fmod_sound(soundlist).set_3d().should_loop().set_create_func(function () {
				ind = 0;
				grounded = true;
				ground_sfx = noone;
				play_ground_sound = function () {
					var roll_sound = (ind == 1) ? soundlist[1] : soundlist[2];
					var pitch = (ind == 3) ? 1.2 : 1;

					ground_sfx = audio_play_sound_on(emitter, roll_sound, true, 10, 0.12, 0, pitch)
						
					audio_sound_loop_end(ground_sfx, 4.95)
					array_push(instances, ground_sfx)	
				}
			}).set_play_func(function() {
				stop_currently_playing_instances()
				if ind >= 1 {
					var inst = audio_play_sound_on(emitter, soundlist[0], true, 10, 1)
					switch (ind) {
						case 1:
							set_bounds(0.13, 9.25)
							break;
						case 2:
							set_bounds(9.73, 16.66)
							break;
						case 3:
							set_bounds(16.66, 0)
							break;
					}
					array_push(instances, inst)
					array_push(main_instances, inst)
					
					if grounded
						play_ground_sound()
				}
			}).set_state_func(function(new_state) {
				if fmod_event_instance_is_playing(self) {
					ind = new_state;
					play();
				}
			}).set_other_func(function(new_grounded) {
				if new_grounded != grounded {
					grounded = new_grounded;
					if fmod_event_instance_is_playing(self) {
						if !grounded {
							audio_stop_sound(ground_sfx);
							ground_sfx = noone;	
						}
						else
							play_ground_sound()
					}
				}
			});
		case "sfx/playerN/bossdeath":
			return new fmod_sound(soundlist).set_3d().set_create_func(function () {
				sfx = noone	
			}).set_play_func(function () {
				stop_currently_playing_instances()
				sfx = audio_play_sound(soundlist[0], 10, true)
				audio_sound_loop_start(sfx, 1.84)
				audio_sound_loop_end(sfx, 3.58)
				array_push(instances, sfx)
			}).set_state_func(function (new_state) {
				if sfx == noone || new_state != 1
					return;
				audio_sound_loop(sfx, false)
				audio_sound_set_track_position(sfx, 3.64)
			})
		case "sfx/playerN/divebomb":
			return new fmod_sound(soundlist).set_3d().should_loop().set_bounds(0.13, 8)
		case "sfx/playerN/wallbounce":
			return new fmod_sound(soundlist).set_3d().set_pitch_vary(0.1);
		case "sfx/playerN/minijetpack":
			return new fmod_sound(soundlist).set_3d().set_create_func(function () {
				play_jetpack_sound = function (state) {
					if state == 0 {
						var inst = audio_play_sound_on(emitter, soundlist[0], true, 10, 1, 0.02)
						audio_sound_loop_start(inst, 0.53)
						audio_sound_loop_end(inst, 3.46)
						array_push(instances, inst)
						
					}
					else if state == 1 {
						stop_currently_playing_instances()
						var inst = audio_play_sound_on(emitter, soundlist[0], false, 10, 1, 3.60)
						array_push(instances, inst)
					}
				}
			}).set_play_func(function () {
				play_jetpack_sound(state)
			}).set_state_func(function (new_state) {
				play_jetpack_sound(new_state)
			});
		case "sfx/playerN/minigunloop":
			return new fmod_sound(soundlist).set_play_func(function () {
				var inst = audio_play_sound(soundlist[0], 10, true, 1.2)
				array_push(instances, inst)
				audio_sound_loop_start(inst, 0.5)
			}).set_state_func(function (new_state) {
				if new_state == 1 {
					for (var i = 0; i < array_length(instances); i++) {
						silence_audio_and_act(instances[i], 30, SILENCE_ACTIONS.STOP)	
					}
				}
			})
		case "sfx/misc/hamkuff":
			return new fmod_sound(soundlist).set_3d().should_loop()
				.set_play_func(function() {
					return;
				})
				.set_state_func(function (newstate) {
					stop_currently_playing_instances()
					t_state = newstate;
					
					var inst = audio_play_sound_on(emitter, soundlist[newstate], newstate != 2, 10, newstate == 2 ? 1.4 : 1)
					array_push(instances, inst)
				});
		case "sfx/pep/step":
		case "sfx/pep/stepinshit":
		case "sfx/pizzahead/uzi":
		case "sfx/pep/punch":
			return new fmod_sound(soundlist).set_3d().set_pitch_vary(0.1).set_gain(0.8)
		case "sfx/pizzahead/fishing":
			return new fmod_sound(soundlist).set_3d().set_fadeout_duration(10)
		case "sfx/pep/taunt":
			return new fmod_sound(soundlist).set_pitch_vary(0.06)
		case "sfx/pep/freefall":
			return track_loop_intro(soundlist, [2, 0])
		case "sfx/misc/breakdancemusic":
			return new fmod_sound(soundlist).should_loop()
		case "sfx/pep/superjump":
			return new fmod_sound(soundlist).set_3d().set_create_func(function () {
				timer = -1;
			}).set_play_func(function () {
				timer = 25;
				var inst = audio_play_sound_on(emitter, soundlist[0], false, 10)
				array_push(instances, inst)
			}).set_state_func(function (new_state) {
				if (new_state == 1) {
					stop_currently_playing_instances()
					var inst = audio_play_sound_on(emitter, soundlist[2], false, 10, 0.7)
					array_push(instances, inst)
				}
			}).set_update_func(function () {
				if timer != -1 {
					timer -= 1
					if timer == 0 && t_state != 1 {
						var inst = audio_play_sound_on(emitter, soundlist[1], true, 10)
						array_push(instances, inst)
					}
				}
			})
		case "sfx/pep/pizzapepper":
			return new fmod_sound(soundlist).set_3d().set_gain(1.65).should_loop().set_play_func(function () {
				stop_currently_playing_instances()
				default_play_func()
			}).set_state_func(function(new_state) {
				if (array_length(instances) != 1)
					return;
				if new_state == 1 {
					silence_audio_and_act(instances[0], 30, SILENCE_ACTIONS.STOP)	
					instances = [];	
				}
			})
		case "sfx/pep/tumble":
			return new fmod_sound(soundlist).set_3d().set_play_func(function () {
				looping = false;
				default_play_func(0)
			}).set_state_func(function(new_state) {
				if (new_state == 1) {
					looping = true;
					default_play_func(1)
					set_bounds(0.6, 0)
				}
				else if (new_state == 2) {
					looping = false;
					stop_currently_playing_instances()
					default_play_func(2)
				}
			})
		case "sfx/ratmount/mach":
			return new fmod_sound(soundlist).set_3d().should_loop().set_create_func(function () {
				grounded = false;
				set_bounds(0, 7.38)	
			}).set_play_func(function () {
				var ind;
				if state == 0
					ind = 0;
				if (state == 1) {
					if (!grounded)
						ind = 1;
					else
						ind = 2;
				}
				set_bounds(0, 7.38)	
				var inst = audio_play_sound_on(emitter, soundlist[ind], true, 10, 0.8, 0)	
				array_push(main_instances, inst)
				array_push(instances, inst)
			}).set_state_func(function (new_state) {
				if (array_length(instances) != 1 || new_state != 1)
					return;
				
				var ind = (grounded) ? 2 : 1;
				var offset = audio_sound_get_track_position(instances[0])
				
				stop_currently_playing_instances()
				var inst = audio_play_sound_on(emitter, soundlist[ind], true, 10, 0.8, offset)	
				array_push(instances, inst)
				array_push(main_instances, inst)
				
				
			}).set_other_func(function (grounded) {
				if (array_length(instances) != 1 || t_state != 1)
					return;
				
				if (grounded != self.grounded) {
					self.grounded = grounded;
					var offset = audio_sound_get_track_position(instances[0])
					var ind = (grounded) ? 2 : 1;
					stop_currently_playing_instances()
					var inst = audio_play_sound_on(emitter, soundlist[ind], true, 10, 0.8, offset)	
					array_push(instances, inst)
					array_push(main_instances, inst)
				
				}
			}).set_update_func(function () {
				if (array_length(instances) != 1)
					return;
				if audio_sound_get_track_position(instances[0]) >= 0.46 {
					set_bounds(0.46, 7.38)	
				}
			})
		case "sfx/ratmount/groundpound":
			return new fmod_sound(soundlist).set_3d().set_play_func(function () {
				set_bounds(0, 2)
				default_play_func()
			}).set_state_func( function(new_state)  {
				if (array_length(instances) != 1)
					return;
				if (new_state == 1) {
					silence_audio_and_act(instances[0], 20, SILENCE_ACTIONS.STOP)
					var inst = audio_play_sound_on(emitter, soundlist[0], looping, 10, 0, 2.76)	
					audio_sound_gain(inst, 1, frames_to_ms(20))
					instances[0] = inst;
					main_instances[0] = inst;
					set_bounds(2.76, 5.07)
				}
			});
		
		case "sfx/misc/golfjingle":
			return new fmod_sound(soundlist).set_gain(2).set_play_func(function () {
				default_play_func(t_state)
			});
		
		case "sfx/misc/mrpinch":
			return new fmod_sound(soundlist).set_3d().set_play_func(function () {
				
			}).set_state_func(function (new_state) {
				stop_currently_playing_instances();
				var inst = audio_play_sound_on(emitter, soundlist[new_state], false, 10)
				array_push(instances, inst)
			})
		
		case "sfx/pep/ghostspeed":
			return new fmod_sound(soundlist).set_3d().set_play_func(function () {
				if state == 0
					return;
				var ind = state - 1
				var inst = audio_play_sound_on(emitter, soundlist[ind], true, 1)
				array_push(instances, inst)
			}).set_state_func(function (new_state) {
				if array_length(instances) == 0
					return;
				stop_currently_playing_instances()
			}).set_gain(1.3).set_fadeout_duration(2)
		
		case "sfx/kingghost/loop":
			return track_loop_intro(soundlist, [0.8, 6.85]).set_3d();
		case "sfx/fakepep/chase":
			return new fmod_sound(soundlist).set_3d().should_loop();
		
		case "sfx/fakepep/superjumpclonerelease":
			return new fmod_sound(soundlist).set_3d();
		case "sfx/fakepep/flailing":
			return new fmod_sound(soundlist).set_3d().set_fadeout_duration(7).set_create_func(function () {
				audio_emitter_falloff(emitter, 900, 1100, 1)
			}).set_play_func(function() {
				gain = global.clonemult * 0.6;
				default_play_func();
			});
		case "sfx/fakepep/bodyslam":
		case "sfx/fakepep/headoff":
		case "sfx/fakepep/headthrow":
		case "sfx/fakepep/mach":
		case "sfx/fakepep/grab":
		case "sfx/fakepep/deform":
		case "sfx/fakepep/reform":
			return new fmod_sound(soundlist).set_3d().set_fadeout_duration(7).set_create_func(function () {
				audio_emitter_falloff(emitter, 900, 1100, 1)
			}).set_play_func(function() {
				gain = global.clonemult * 0.7;
				default_play_func();
			});
		case "sfx/fakepep/superjump":
			return new fmod_sound(soundlist).set_3d().set_create_func(function () {
				audio_emitter_falloff(emitter, 900, 1100, 1)	
			}).set_fadeout_duration(7).set_play_func(function() {
				gain = global.clonemult * 1.1
				default_play_func(state);
			}).set_state_func(function (new_state) {
				if (array_length(instances) == 0)
					return;
				stop_currently_playing_instances()
			});
		
		case "sfx/ui/percentagemove":
			return new fmod_sound(soundlist).set_play_func(function () {
				pitch = 1 + state
				default_play_func()
			})
		/* this sound apparently never plays in the game
		case "sfx/enemies/cannongoblin":
			var s = new fmod_sound_3d(soundlist, false)
			s.delay = 40
			return s;
		*/
		
		
		case "sfx/pizzahead/tvthrow":
			return new fmod_sound(soundlist).set_state_func(function(new_state) {
				if array_length(instances) != 1
					return;
				var inst = instances[0]
				switch (new_state) {
					case 0:
					case 2:
						audio_sound_set_track_position(inst, 0)
						break;
					case 1:
						audio_sound_gain(inst, 0.7, 0)
						audio_sound_set_track_position(inst, 3.33)
						break;
					case 3:
						audio_sound_gain(inst, 1.2, 0)
						audio_sound_set_track_position(inst, 5)
						break;
				}	
			})
		case "sfx/pizzahead/finale":
			return new fmod_sound(soundlist).set_create_func(function () {
				wind = noone	
			}).set_state_func(function(new_state) {
				if array_length(instances) == 0
					return;
				var pause = (new_state % 2 == 1)
				fmod_event_instance_set_paused(self, pause)
				if pause {
					wind = audio_play_sound(soundlist[1], false, true, 2, 1)
					audio_sound_set_track_position(wind, 1)
					array_push(instances, wind)
				}
				else {
					if wind != noone
						audio_stop_sound(wind)
				}
				
			})
		case "sfx/pizzaface/shower":
			return new fmod_sound(soundlist).set_3d().should_loop().set_state_func(function (new_state) {
				stop_currently_playing_instances()
				var inst = audio_play_sound_on(emitter, soundlist[new_state], false, 10)
				array_push(instances, inst)
			})
		case "sfx/playerN/finaljudgement_drumroll":
			return new fmod_sound(soundlist).should_loop().set_bounds(0.1, 4.6).set_state_func(function (new_state) {
				if (new_state == 1) {
					stop_currently_playing_instances()
					var inst = audio_play_sound(soundlist[0], 10, false, 1, 4.65)
					array_push(instances, inst)
				}
					
			});
		case "sfx/playerN/finaljudgement_verdict":
			return new fmod_sound(soundlist).set_play_func(function () {
				// state is set AFTER playing....
			}).set_state_func(function (new_state) {
				var inst = audio_play_sound(soundlist[new_state], 10, false)
				array_push(instances, inst)
			})
		case "sfx/misc/versusscreen":
			return new fmod_sound(soundlist).set_delay(33)
		case "music/intro":
			return new fmod_sound(soundlist).set_gain(0).set_state_func(function(new_state) {
				if (array_length(instances) != 1)
					return;
				if (new_state == 0) {
					if t_anyvar1 == 0
						silence_audio_and_act(instances[0], 60, SILENCE_ACTIONS.STOP)
					else
						audio_pause_sound(instances[0])	
				}
				else if (new_state == 1)  {
					audio_sound_set_track_position(instances[0], 0)	
					audio_sound_gain(instances[0], 1, 1000/60)	
					audio_resume_sound(instances[0])
					t_anyvar1 = 0;
				}
			});
			
		// In the port, this event is taken out of obj_music and is handled manually in obj_title because
		// of the added complexity of the port menu's music.
		case "music/title":
			return new fmod_sound(soundlist).set_create_func(function() {
				timer = 0;
				songs = [noone, noone, noone];
			}).set_play_func(function() {
				on_create()
				songs[0] = audio_play_sound(soundlist[0], 10, true, 0.6)	
				audio_sound_loop_end(songs[0], 4.83)
				array_push(instances, songs[0])
				
				songs[1] = audio_play_sound(soundlist[1], 10, true, 0, 0)	
				songs[2] = audio_play_sound(soundlist[2], 10, true, 0, 0)	
				array_push(instances, songs[1])
				array_push(instances, songs[2])
				
				audio_pause_sound_insist(songs[1])
				audio_pause_sound_insist(songs[2])
				
			}).set_state_func(function(new_state) {
				if (timer != -1 && !audio_is_playing(songs[0]) 
						|| !audio_is_playing(songs[1])
						|| !audio_is_playing(songs[2])) 
					return;
					
				if (new_state == 1) {
					unsilence_audio(songs[0], 60)
					silence_audio_and_act(songs[1], 60, SILENCE_ACTIONS.PAUSE)
					silence_audio_and_act(songs[2], 60, SILENCE_ACTIONS.PAUSE)
					
					audio_resume_sound(songs[0])
				}
				else if (new_state == 2) {
					silence_audio_and_act(songs[0], 60, SILENCE_ACTIONS.PAUSE)
					unsilence_audio(songs[1], 60)
					silence_audio_and_act(songs[2], 60, SILENCE_ACTIONS.NOTHING)
					
					audio_resume_sound(songs[1])
					audio_resume_sound(songs[2])
				}
				else if (new_state == 3) {
					silence_audio_and_act(songs[0], 60, SILENCE_ACTIONS.PAUSE)
					silence_audio_and_act(songs[1], 60, SILENCE_ACTIONS.NOTHING)
					unsilence_audio(songs[2], 60)
					audio_resume_sound(songs[1])
					audio_resume_sound(songs[2])
				}

			}).set_update_func(function() {
				if (timer == -1 || !audio_is_playing(songs[0]))
					return;
				
				
					
				if (t_state == 1) {
					if timer == 0
						audio_sound_gain(songs[0], 1, 0)
					timer += 1
					if timer == 20 {
						audio_sound_loop_points(songs[0], 13.25, 133.25)
						audio_sound_set_track_position(songs[0], 13.25)
						timer = -1;
					}
				}
			});
			
		case "music/pizzatime":
			return new fmod_sound(soundlist).set_create_func(function() {
				song = noone
				noise_song = noone
				song_gain = 1;
				noise_song_gain = 1;
			}).set_play_func(function () {
				stop_currently_playing_instances()
				
				song_gain = 1;
				noise_song_gain = 0.7;
				
				song = audio_play_sound(soundlist[0], 10, true, !global.fmod_is_noise * song_gain)
				audio_sound_loop_points(song, 53 + 1/3, 2 * 60 + 45 + 1/3)
				
				noise_song = audio_play_sound(soundlist[3], 10, true, global.fmod_is_noise * noise_song_gain)
				audio_sound_loop_points(noise_song, 47.39, 60 + 53.30)
				
				array_push(instances, song)
				array_push(instances, noise_song)
	
				

				if global.fmod_is_noise
					set_relevant_instance(noise_song)	
				else
					set_relevant_instance(song)
			}).set_state_func(function (new_state) {
				if (new_state == 1) {
					silence_audio_and_act(song, 60, SILENCE_ACTIONS.STOP)
					silence_audio_and_act(noise_song, 60, SILENCE_ACTIONS.STOP)
					
					song = audio_play_sound(soundlist[0], 10, false, 0, 2 * 60 + 50.7)
					noise_song = audio_play_sound(soundlist[3], 10, false, 0, 2 * 60 + 16.23)
					array_push(instances, song)
					array_push(instances, noise_song)
					

					if global.fmod_is_noise {
						set_relevant_instance(noise_song)
						unsilence_audio(noise_song, 30, noise_song_gain)
					}
					else {
						set_relevant_instance(song)
						unsilence_audio(song, 30, song_gain)	
					}

				}
				else if (new_state == 2) {
					silence_audio_and_act(song, 30, SILENCE_ACTIONS.STOP)
					silence_audio_and_act(noise_song, 30, SILENCE_ACTIONS.STOP)
					
					song = audio_play_sound(soundlist[1], 10, true, 0)
					audio_sound_loop_points(song, 40.85, 168.85)
					
					noise_song = audio_play_sound(soundlist[4], 10, true, 0)
					audio_sound_loop_points(noise_song, 37.36, 2 * 60 + 9.34)
					
					array_push(instances, song)
					array_push(instances, noise_song)
					
					if global.fmod_is_noise {
						set_relevant_instance(noise_song)
						unsilence_audio(noise_song, 30)
					}
					else {
						set_relevant_instance(song)
						unsilence_audio(song, 30)	
					}
						
					song_gain = 1;
					noise_song_gain = 1;	
				}
				else if (new_state == 3) {
					if !global.option_lap3
						return;
					silence_audio_and_act(song, 60, SILENCE_ACTIONS.STOP)
					silence_audio_and_act(noise_song, 60, SILENCE_ACTIONS.STOP)
					
					song = audio_play_sound(soundlist[2], 10, true, 0)
					noise_song = audio_play_sound(soundlist[5], 10, true, 0)
					
					audio_sound_loop_points(noise_song, 10.66, 60 + 38.66)

					array_push(instances, song)
					array_push(instances, noise_song)
					
					song_gain = 1;
					noise_song_gain = 1;

					if global.fmod_is_noise {
						set_relevant_instance(noise_song)
						unsilence_audio(noise_song, 30, noise_song_gain)
					}
					else {
						set_relevant_instance(song)
						unsilence_audio(song, 30, song_gain)	
					}
					
					
				}
			}).set_noise_func(function () {
				if (global.fmod_is_noise) {
					set_relevant_instance(noise_song)
					unsilence_audio(noise_song, 30, noise_song_gain)
					silence_audio_and_act(song, 30, SILENCE_ACTIONS.NOTHING)
				}
				else {
					set_relevant_instance(song)
					unsilence_audio(song, 30, song_gain)
					silence_audio_and_act(noise_song, 30, SILENCE_ACTIONS.NOTHING)
				}
				
			});
			
		// For this to not break, in scr_music_util, add:
		/*
		case tower_soundtest:
		case street_intro:
			s = -1;
			break;
		*/
		case "music/hub":
			return new fmod_sound(soundlist).set_fadeout_duration(120).set_create_func(function () {
				hub = 0;	
				song = noone;
			}).set_play_func(function() {
				if hub == -1
					return;
				
				stop_currently_playing_instances()
				song = audio_play_sound(soundlist[hub], 10, true)
				array_push(instances, song)
			}).set_update_func(function () {
				if !audio_is_playing(song)
					return;
				var trackpos = audio_sound_get_track_position(song)
				if trackpos >= 153.7 {
					var end_inst = clone_and_play(song, true)
					array_push(instances, end_inst)
					audio_sound_set_track_position(song, (trackpos - 153.7) + 2.15)

				}	
			}).set_other_func(function (hubnum) {

				
				if (hubnum == -1) {
					stop_currently_playing_instances()
					return;
				}
				if !audio_is_playing(song) {
					hub = hubnum
					play()
					return;	
				}
				if (hub == hubnum)
					return;
				hub = hubnum
				var pos = audio_sound_get_track_position(song)
				silence_audio_and_act(song, 60, SILENCE_ACTIONS.STOP)
				song = audio_play_sound(soundlist[hubnum], 10, true, 0, pos)
				array_push(instances, song)
				audio_sound_gain(song, 1, frames_to_ms(60))
			}).set_on_stop_func(function () {
				should_play = false;	
			})
		
		case "music/w1/entrance": // john gutter
			return new fmod_sound(soundlist).should_loop().set_create_func(function () {
				song = noone
				noise_song = noone
			}).set_update_func(function() {
				if song == noone || noise_song == noone
					return;
				var trackpos = audio_sound_get_track_position(song)
				if trackpos >= 212.38 {
					audio_sound_set_track_position(song, (trackpos - 212.38) + 42.47)
					var endsound = audio_play_sound(soundlist[0], 10, false, audio_sound_get_gain(song))
					audio_sound_set_track_position(endsound, trackpos)
				}
			}).set_play_func(function () {
				stop_currently_playing_instances()
				song = audio_play_sound(soundlist[0], 10, true, !global.fmod_is_noise_file)
				noise_song = audio_play_sound(soundlist[1], 10, true, 0.5 * global.fmod_is_noise_file)
				audio_sound_loop_points(noise_song, 0.0, 113.68)
				array_push(instances, song)
				array_push(instances, noise_song)
				
			})
		
		case "music/w1/medieval": // pizzascape
			return swap_two_tracks_intro(soundlist, [2.6, 117.39], [18.28, 123.42], 2)
		case "music/w1/ruin": // ancient cheese
			return swap_two_tracks_intro(soundlist, [0, 112], [0, 0])
		case "music/w2/desert": // oregano desert
			return swap_two_tracks_intro(soundlist, [0, 0], [0, 60 * 3 + 40], 1)
		case "music/w1/dungeon": // bloodsauce dungeon
			return new fmod_sound(soundlist).should_loop().set_bounds(0, 212)
		case "music/w2/graveyard":
			return track_loop_intro(soundlist, [42, 60 * 3 + 39])
		case "music/w2/farm":
			return swap_two_tracks_intro(soundlist, [0, 0], [0, 0], 1, true)
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
		case "music/w5/finalhallway":
		case "music/w2/saloon":
		case "music/w4/sewer":
		case "music/pillarmusic":
		case "sfx/pep/cross":
		case "music/tutorial":
		case "sfx/misc/windloop":
			return new fmod_sound(soundlist).should_loop();
		case "music/peppinohouse":
			return new fmod_sound(soundlist).should_loop().set_gain(2);
		case "music/characterselect":
			return new fmod_sound(soundlist).set_play_func(function () {
				var inst = audio_play_sound(soundlist[0], 10, true, 1, 29.9)
				array_push(instances, inst)
				audio_sound_loop_start(inst, 31.08)
				audio_sound_loop_end(inst, 2 * 60 + 39.75)
			})
		case "music/secretworld":
			return new fmod_sound(soundlist).should_loop();
		case "music/boss/fakepep":
			return new fmod_sound(soundlist).set_play_func(function () {
				stop_currently_playing_instances()
				default_play_func()	
			}).should_loop();
		case "music/w3/beach":
			return track_loop_intro(soundlist, [2.08, 2 * 60 + 47.64]) // at this point i got tired of saying what levels these are, figure it out
		case "music/w3/forest": 
			return swap_three_tracks_intro(soundlist, [0, 60 * 2 + 42.76], [0, 0], [0, 0])
		case "music/w3/golf":
			return new fmod_sound(soundlist).should_loop().set_bounds(0, 3 * 60 + 27.03)
		
		case "music/w3/space":
			return track_loop_intro(soundlist, [3.5, 3 * 60 + 26.71])
		case "music/w4/freezer": // in order for this to work, in obj_noisejetpack, the lines resetting the state to 1 at the bottom were removed.
			return swap_three_tracks_intro(soundlist, [0, 2 * 60 + 18.24], [0, 0], [0, 0], true)
		case "music/w4/industrial":
			return swap_two_tracks_intro(soundlist, [0, 2 * 60 + 23.98], [0.2, 2 * 60 + 8.19], 1, true)
		case "music/w4/street":
			return swap_three_tracks_intro(soundlist, [17.34, 2 * 60 + 38.04], [0.02, -1], [0, 0], true)
		case "music/w5/chateau":
			return new fmod_sound(soundlist).should_loop().set_bounds(0, 3 * 60 + 1.60)
		
		case "music/w5/kidsparty":
			return track_loop_intro(soundlist, [54.91, 60 * 3 + 50.21])
		
		case "music/w5/kidspartychase":
			return new fmod_sound(soundlist).set_fadeout_duration(30)
			.set_create_func(function () {
				timer = -1;	
			}).set_play_func(function() {
				stop_currently_playing_instances()
				timer = 27	
				var inst = audio_play_sound(soundlist[0], 10, false)
				array_push(instances, inst);
			}).set_update_func(function () {
				if timer != -1 {
					timer -= 1
					if timer == 0 {
						var inst = audio_play_sound(soundlist[1], 10, true)
						array_push(instances, inst);
					}
				}
			}).set_on_stop_func(function (natural) {
				timer = -1;	
			}).set_stopped_condition(function () {
				return array_length(instances) == 0 && timer == -1
			})
		case "music/w5/war":
			return track_loop_intro(soundlist, [14.14, 4 * 60 + 14.12])
		
		case "music/boss/pepperman":
			return track_loop_intro(soundlist, [2.44, 60 + 53.6]).set_state_func(function (new_state) {
				if array_length(instances) != 1
					return;
				if new_state == 1	
					audio_sound_gain(instances[0], 0.3, 400)
				else
					audio_sound_gain(instances[0], 1, 400)
			}).set_fadeout_duration(9)
			
		case "music/boss/vigilante":
			return new fmod_sound(soundlist).set_create_func(function () {
				song = noone;
				wind = noone;
			}).set_play_func(function() {
				stop_currently_playing_instances()
				song = audio_play_sound(soundlist[0], 10, true);
				audio_sound_loop_start(song, 0.02)
				audio_sound_loop_end(song, 2 * 60 + 40.02);
				array_push(instances, song)
			}).set_state_func(function (new_state) {
				show_debug_message(new_state)
				if (!audio_is_playing(song))
					return;
					
				var wind_gain = new_state;
				if (wind_gain == 0 && audio_is_playing(wind)) {
					audio_stop_sound(wind)
				}
					
				if (!audio_is_playing(wind)) {
					wind = audio_play_sound(soundlist[1], 10, true, 0, 12);
					array_push(instances, wind)
				}
				
		
				
				// for some reason, after beating the fight, the sets the state to 0.95 and then 0.9.
				// this resulted in it being slightly heard after you win. we do this check to prevent that.
				if wind_gain > 0.89
					wind_gain = 1
					
				
				
				audio_sound_gain(song, 1 - wind_gain, 0)
				audio_sound_gain(wind, wind_gain * 1.2, 0)	
				
			})
			
		case "music/boss/noise":
			return new fmod_sound(soundlist).set_fadeout_duration(10).set_create_func(function () {
				song = noone;
			}).set_play_func(function () {
				stop_currently_playing_instances()
				var gain = !global.fmod_is_noise_file ? 1 : 0.75
				song = audio_play_sound(soundlist[global.fmod_is_noise_file], 0, true, gain)
				array_push(instances, song)
			})
			.set_update_func(function() {
				if (global.fmod_is_noise_file)
					return;
				var trackpos = audio_sound_get_track_position(song)
				if trackpos >= (60 * 2 + 13.71) {
					var end_inst = clone_and_play(instances[0], true)
					array_push(instances, end_inst)
					audio_sound_loop(end_inst, false)
					audio_sound_set_track_position(instances[0], trackpos - 60 * 2 + 13.71)
				}
			});
			
		case "music/boss/fakepepambient":
			return new fmod_sound(soundlist).set_play_func(function() {
				if (array_length(instances) != 0)// game plays this twice for no reason
					return;
				var inst = audio_play_sound(soundlist[0], 10, true, 0);
				audio_sound_gain(inst, 0.8, frames_to_ms(90))
				array_push(instances, inst)
			})
			
		case "music/boss/pizzaface":
			return new fmod_sound(soundlist).should_loop().set_play_func(function () {
				set_bounds(0, 60 * 2 + 38.4);
				stop_currently_playing_instances()
				phase_3_index = 2 + global.fmod_is_noise_file
				song_progress = 0;
				default_play_func();
			}).set_state_func(function(new_state) {
				if (array_length(instances) != 1)
					return;
				if new_state <= song_progress
					exit;
				song_progress = new_state;
				
				switch (song_progress) {
					// pizzaface opens up
					case 1: 
						silence_audio_and_act(instances[0], 10, SILENCE_ACTIONS.STOP)
						var inst = audio_play_sound(soundlist[1], 10, true, 0)
						instances[0] = inst;
						main_instances[0] = inst;
						audio_sound_gain(instances[0], 1, 166)
						set_bounds(19.23, 38.45)
						break;
					// gun phase
					case 1.4: // WHY. why 1.4. why not 1.5 if you have an intermediate state. what the fuck.
						audio_sound_set_track_position(instances[0], 38.45)
						set_bounds(0.03, 60 * 2 + 56.43)
						break;
					// pizzaface brings the other bosses
					case 2:
						silence_audio_and_act(instances[0], 30, SILENCE_ACTIONS.STOP)
						var inst = audio_play_sound(soundlist[phase_3_index], 10, true, 0)
						instances[0] = inst;
						main_instances = []
						audio_sound_gain(inst, 1, 166)
						
						if global.fmod_is_noise_file {
							audio_sound_loop_start(inst, 9.60)
							audio_sound_loop_end(inst, 14.4)
						}
						else {
							audio_sound_loop_end(inst, 60 * 3 + 21.60)
						}
						
						set_bounds(0, 60 * 3 + 21.60)
						break;
					// peppino beats up the bosses
					case 3:
						silence_audio_and_act(instances[0], 30, SILENCE_ACTIONS.STOP)
						var inst = audio_play_sound(soundlist[phase_3_index], 10, true, 0)
						instances[0] = inst;
						main_instances[0] = inst;
						audio_sound_gain(instances[0], 1, 166)
						var forwardskip = !global.fmod_is_noise_file ? 42 : 13.8
						audio_sound_set_track_position(instances[0], forwardskip)
						break;
					// peppino beats up pizzaface
					case 4:
						silence_audio_and_act(instances[0], 30, SILENCE_ACTIONS.STOP)
						var inst = audio_play_sound(soundlist[phase_3_index], 10, true, 0)
						instances[0] = inst;
						main_instances[0] = inst;
						unsilence_audio(instances[0], 30)
						var start_bound = !global.fmod_is_noise_file ? 60 * 3 + 21.60 : 60 * 3
						var end_bound = !global.fmod_is_noise_file ? 60 * 4 + 19.20 : 60 * 3 + 38.40
						audio_sound_set_track_position(instances[0], start_bound)
						set_bounds(start_bound, end_bound)
						break;
					// peppino really beats up pizzaface
					case 5:
						silence_audio_and_act(instances[0], 60, SILENCE_ACTIONS.STOP)
						if global.fmod_is_noise_file
							break;
						looping = false;
						var inst = audio_play_sound(soundlist[phase_3_index], 10, false, 0)
						instances[0] = inst;
						main_instances[0] = inst;
						audio_sound_gain(instances[0], 1, 333)
						audio_sound_set_track_position(instances[0], 60 * 4 + 19.20)
						set_bounds(60 * 4 + 19.20, 0)
						break;
				}
			}).set_update_func(function () {
				if array_length(instances) != 1
					return;
				switch (song_progress) {
					case 3:
						if !global.fmod_is_noise_file {
							if audio_sound_get_track_position(instances[0]) > 48
								set_bounds(48, 60 * 3 + 21.60)
						}
						else {
							if audio_sound_get_track_position(instances[0]) > 19.2
								set_bounds(19.2, 60 * 3)
						}
						break;
					case 4:
						if !global.fmod_is_noise_file && audio_sound_get_track_position(instances[0]) > 60 * 3 + 26.40
							set_bounds(60 * 3 + 26.40, 60 * 4 + 19.20)
						break;
				}	
			});
		case "sfx/ending/towercollapsetrack":
			return new fmod_sound(soundlist).set_gain(0).set_create_func(function () {
				song = noone
				timer = 0;
			}).set_play_func(function () {
				song = default_play_func()	
			}).set_update_func(function () {
				if !audio_is_playing(song)
					return;
				timer++;
				if (timer == 150) {
					audio_sound_set_track_position(song, 6.5)
					audio_sound_gain(song, 1, frames_to_ms(120))	
				}
				else if (timer == 570) {
					var inst = audio_play_sound(soundlist[1 + global.fmod_is_noise_file * 3], 10, false, 1)	
					array_push(instances, inst)
				}
				else if (timer == 670) {
					var inst = audio_play_sound(soundlist[2 + global.fmod_is_noise_file * 3], 10, false, 0.6)	
					array_push(instances, inst)
				}
				else if (timer == 670) {
					if !global.fmod_is_noise_file {
						var inst = audio_play_sound(soundlist[3], 10, false, 0.6)	
						array_push(instances, inst)
					}
				}
				else if (timer == 960)
					silence_audio_and_act(song, 180, SILENCE_ACTIONS.STOP)	
				
			})
		case "music/credits":
			return new fmod_sound(soundlist).set_create_func(function () {
				songs = [noone, noone, noone, noone];
				ind = 0;
			}).set_play_func(function () {
				songs[0] = audio_play_sound(soundlist[!global.fmod_is_noise_file ? 0 : 4], 10, false)
				songs[1] = audio_play_sound(soundlist[1], 10, false)
				songs[2] = audio_play_sound(soundlist[2], 10, false)
				songs[3] = audio_play_sound(soundlist[3], 10, false)
				audio_pause_sound_insist(songs[1])
				audio_pause_sound_insist(songs[2])
				audio_pause_sound_insist(songs[3])
				array_push(instances, songs[0])
				array_push(instances, songs[1])
				array_push(instances, songs[2])
				array_push(instances, songs[3])
				ind = 0;
			}).set_update_func(function () {
				if (audio_is_playing(songs[ind]))
					return;
				if (ind == 0) {
					audio_resume_sound(songs[1])
					ind++;
				}
				else if (ind == 1) {
					audio_resume_sound(songs[2])
					ind++;	
				}
				else if (ind == 2) {
					audio_resume_sound(songs[3])
					ind++;	
				}
			
			})
		case "music/finalrank":
			return new fmod_sound(soundlist).should_loop().set_play_func(function () {
				if global.fmod_is_noise_file
					return;
				default_play_func()
			}).set_state_func(function (new_state) {
				if ((array_length(instances) == 0) && !global.fmod_is_noise_file) || new_state != 1
					return;
				stop_currently_playing_instances()
				var inst = audio_play_sound(soundlist[1], 10, true)	
				array_push(instances, inst)
			})
		case "music/rank":
			return new fmod_sound(soundlist).set_delay(3).set_create_func(function() {
				rank = 0;
			}).set_play_func(function() {
				// no idea why rank is like this. so stupid
				var ind = rank - 0.5
				if ind <= 4
					ind = 4 - ind
				default_play_func(ind)
			}).set_other_func(function(rank) {
				self.rank = rank;
			});

		case "music/halloweenpause":
			return swap_two_tracks_intro(soundlist, [0, 0], [0, 0], 1, true).set_update_func(function () {
				if array_length(instances) != 2
					return;
				if audio_sound_get_track_position(instances[0]) > (1 * 60 + 27.25) {
					var trackpos = audio_sound_get_track_position(instances[0])
					var endsound = audio_play_sound(soundlist[0], 10, false, audio_sound_get_gain(instances[0]))
					audio_sound_set_track_position(endsound, trackpos)
					audio_sound_set_track_position(instances[0], trackpos - (1 * 60 + 27.25))
				}	
			})
		case "music/pause":

			return swap_two_tracks_intro(soundlist, [0, 0], [0, 0], 1, true) 
			
		case "music/halloween2023":
			return new fmod_sound(soundlist).set_create_func(function() {
				ind = 0;
				song = noone;

				play_the_thing = function() {
					var gain = (ind == 1) ? 0.32 : 1;
					var inst = audio_play_sound(soundlist[ind], 10, true, gain)
					if (ind == 0) {
						audio_sound_loop_start(inst, 7.68)
						audio_sound_loop_end(inst, 1 * 60 + 51.86)
						
					}
					array_push(instances, inst)
					
					song = inst;
				}
				
			}).set_play_func(function () {
				play_the_thing();
			}).set_state_func(function (new_state) {
				ind = new_state
				if (!audio_is_playing(song))
					return;
				stop_currently_playing_instances()
				play_the_thing();
				
			}).set_update_func(function () {
				if (!audio_is_playing(song))
					return;
				if state == 1 {
					if audio_sound_get_track_position(song) > 3 * 60 + 44 {
						var end_sound = clone_and_play(song, true)
						array_push(instances, end_sound)
						audio_sound_set_track_position(song, audio_sound_get_track_position(song) - 3 * 60 + 44)
					}
				}

			}).set_on_stop_func(function (natural) {
				state = 0;	
			}) 
			.set_fadeout_duration(30);
		


	}
}


function track_loop_intro(soundlist, bounds) {
	var s = new fmod_sound(soundlist).should_loop()
		.set_play_func(function() {
			set_bounds(0, 0)
			default_play_func()
		})
		.set_update_func(function() {
			if (array_length(instances) == 0 || t_anyvar1 != -1)
				return;
			if audio_sound_get_track_position(instances[0]) > new_points[0] {
				set_bounds(new_points[0], new_points[1]);
				t_anyvar1 = 0	
			}	
		})
	s.new_points = bounds
	return s;

}

function swap_two_tracks_intro(soundlist, bounds1, bounds2, state_to_check = 1, pause_until_play = false) {
	
	var s = new fmod_sound(soundlist).set_create_func(function () {
		songs = [noone, noone]
	}).set_play_func(function () {
		stop_currently_playing_instances()
		songs[0] = audio_play_sound(soundlist[0], 10, true, 1)
		songs[1] = audio_play_sound(soundlist[1], 10, true, 0)
		array_push(instances, songs[0])
		array_push(instances, songs[1])

		audio_sound_loop_start(songs[0], bounds1[0])
		audio_sound_loop_end(songs[0], bounds1[1])
		
		audio_sound_loop_start(songs[1], bounds2[0])
		audio_sound_loop_end(songs[1], bounds2[1])
		if (pause_until_play) {
			audio_pause_sound_insist(songs[1])
		}
	}).set_state_func(function (new_state) {
		if !audio_is_playing(songs[0]) || !audio_is_playing(songs[1])
			return;
			
		var action = (pause_until_play) ? SILENCE_ACTIONS.PAUSE : SILENCE_ACTIONS.NOTHING
		if (new_state == 0) {
			unsilence_audio(songs[0], 60)
			silence_audio_and_act(songs[1], 60, action)
			if (pause_until_play)
				audio_resume_sound(songs[0])
		}
		else if (new_state == state_to_check) {
			silence_audio_and_act(songs[0], 60, action)
			unsilence_audio(songs[1], 60)
			if (pause_until_play)
				audio_resume_sound(songs[1])
		}

	});
	s.bounds1 = bounds1;
	s.bounds2 = bounds2;
	s.pause_until_play = pause_until_play;
	s.state_to_check = state_to_check;
	return s;
}

function swap_three_tracks_intro(soundlist, bounds1, bounds2, bounds3, pause_until_play = false) {
	var s = new fmod_sound(soundlist).set_create_func(function () {
		songs = [noone, noone, noone]
	}).set_play_func(function () {
		stop_currently_playing_instances()

		songs[0] = audio_play_sound(soundlist[0], 10, true, 1)
		songs[1] = audio_play_sound(soundlist[1], 10, true, 0)
		songs[2] = audio_play_sound(soundlist[2], 10, true, 0)
		
		array_push(instances, songs[0])
		array_push(instances, songs[1])
		array_push(instances, songs[2])

		audio_sound_loop_start(songs[0], bounds1[0])
		audio_sound_loop_end(songs[0], bounds1[1])
		
		audio_sound_loop_start(songs[1], bounds2[0])
		audio_sound_loop_end(songs[1], bounds2[1])
		
		audio_sound_loop_start(songs[2], bounds3[0])
		audio_sound_loop_end(songs[2], bounds3[1])
		
		set_relevant_instance(songs[0])
		
		if (pause_until_play) {
			audio_pause_sound_insist(songs[1])
			audio_pause_sound_insist(songs[2])
		}
	}).set_state_func(function (new_state) {
		if !audio_is_playing(songs[0]) || !audio_is_playing(songs[1]) || !audio_is_playing(songs[2])
			return;
	
		var action = (pause_until_play) ? SILENCE_ACTIONS.PAUSE : SILENCE_ACTIONS.NOTHING
		
		if (new_state == 0) {
			unsilence_audio(songs[0], 60)
			silence_audio_and_act(songs[1], 60, action)
			silence_audio_and_act(songs[2], 60, action)
			set_relevant_instance(songs[0])
			if (pause_until_play)
				audio_resume_sound(songs[0])
		}
		else if (new_state == 1) {
			silence_audio_and_act(songs[0], 60, action)
			unsilence_audio(songs[1], 60)
			silence_audio_and_act(songs[2], 60, action)
			set_relevant_instance(songs[1])
			if (pause_until_play)
				audio_resume_sound(songs[1])
		}
		else if (new_state == 2) {
			silence_audio_and_act(songs[0], 60, action)
			silence_audio_and_act(songs[1], 60, action)
			unsilence_audio(songs[2], 60)
			set_relevant_instance(songs[2])
			if (pause_until_play)
				audio_resume_sound(songs[2])
		}
			
	}).set_update_func(function () {

	});
	s.bounds1 = bounds1;
	s.bounds2 = bounds2;
	s.bounds3 = bounds3;
	s.pause_until_play = pause_until_play;
	return s;
	
}


function frames_to_ms(frames) {
	return frames * (1000 / 60)
}

function clone_and_play(inst, no_loop) {
	var asset = asset_get_index(audio_get_name(inst))
	var new_inst = audio_play_sound(asset, 10, audio_sound_get_loop(inst) && !no_loop, audio_sound_get_gain(inst), audio_sound_get_track_position(inst), audio_sound_get_pitch(inst))
	return new_inst
}

// For some reason, some sounds will not pause if you try to right after they're played. So we must insist.
function audio_pause_sound_insist(inst) {
	while (audio_is_playing(inst) && !audio_is_paused(inst)) {
		audio_pause_sound(inst)	
	}
}

function audio_sound_loop_points(inst, start, endp) {
	audio_sound_loop_start(inst, 0)
	audio_sound_loop_end(inst, 0)
	audio_sound_loop_start(inst, start)
	audio_sound_loop_end(inst, endp)
}	

// the game still has remnants of old code which calls audio_* functions. 
// this doesn't do anything for sounds played by fmod, but it does affect our sounds.
// we do not want this. i globally replaced all mentions of these functions with cooler variants.
// much cooler
function audio_stop_all_cool() { }
function audio_resume_all_cool() { }
function audio_pause_all_cool() { }