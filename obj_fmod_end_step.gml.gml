// (This file is the End Step event of obj_fmod inside the GameMaker project)
// SR 4
audio_listener_position(camera_get_view_x(view_camera[0]) + (camera_get_view_width(view_camera[0]) / 2), camera_get_view_y(view_camera[0]) + (camera_get_view_height(view_camera[0]) / 2), 0)
fmod_update()

var len = ds_list_size(soundwatchers)
for (var i = 0; i < len; i++) {
	with (soundwatchers[| i]) {
		if released {
			ds_list_delete(other.soundwatchers, i)
			i--
			len--
			continue
		}
		if sound != noone {
			if loop_points != [-1, -1] and audio_is_playing(sound) {
				
				var audio_point = audio_sound_get_track_position(sound)
				if abs(audio_point - last_time_point) > 1 and audio_point == 0 { // reliability check. on switch, the function above seems to sometimes return 0 for a frame. god knows why.
					fail_count++
					if fail_count > 1
						last_time_point = audio_point
				}
				else {
					var changed_point = false
					fail_count = 0
					var loop_point_1 = loop_points[0] = -1 ? 0 : loop_points[0]	
					var loop_point_2 = loop_points[1] = -1 ? audio_sound_length(sound) : loop_points[1]	
				
				
					if audio_point > loop_point_2 {
						audio_point += -loop_point_2 + loop_point_1
						if !looping
							audio_stop_sound(sound)
						changed_point = true
					}
		
					if audio_point < loop_point_1 {
						audio_point = loop_point_1
						changed_point = true
					}	
					
					last_time_point = audio_point
					if changed_point
						audio_sound_set_track_position(sound, audio_point)
				}
				
			}
		}
		if stepfunc != noone and (sound == noone or (!audio_is_paused(sound)))
			stepfunc()
		if struct != noone { // soundwatchers are made for one shot sounds, since they need someone to destroy them
			if !fmod_event_instance_is_playing(struct) {
				ds_list_delete(other.soundwatchers, i)
				released = true
				i--
				len--
				struct.destroy();
				delete struct;
			}
		}
	}
}
len = ds_list_size(audiostoppers)
for (i = 0; i < len; i++) {
	var deleteself = false
	with (audiostoppers[| i]) {
		if global.frame >= deathtime { 
			deleteself = true
			if pause
				audio_pause_sound(sound)
			else
				audio_stop_sound(sound)
		}
	}
	if deleteself {
		delete audiostoppers[| i]
		ds_list_delete(audiostoppers, i)		
		i--
		len--
	}
}
