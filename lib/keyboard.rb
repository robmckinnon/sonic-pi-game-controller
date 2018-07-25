use_debug false
use_cue_logging false

set :resolution, 0.0625
set :steps, 2
set :syn, :sine if get[:syn].nil?
set :syn_pointer, 0 if get[:syn_pointer].nil?
set :mode, :chords if get[:mode].nil?
set :modes, [:notes, :chords, :drums]
set :mode_pointer, 0 if get[:mode_pointer].nil?
set :octave_shift, (0 + current_octave) if get[:octave_shift].nil?

# buttons
X = '/osc/b/a'
CIRCLE = '/osc/b/b'
SQUARE = '/osc/b/x'
TRIANGLE = '/osc/b/y'
L1 = '/osc/b/leftshoulder'
R1 = '/osc/b/rightshoulder'
SHARE = '/osc/b/back'
OPTIONS = '/osc/b/start'
LEFT_ANALOG_PRESS = '/osc/b/leftstick'
RIGHT_ANALOG_PRESS = '/osc/b/rightstick'

# axis
LEFT_HORIZONTAL = '/osc/a/leftx'
LEFT_VERTICAL = '/osc/a/lefty'
RIGHT_HORIZONTAL = '/osc/a/rightx'
RIGHT_VERTICAL = '/osc/a/righty'
L1_PRESS = '/osc/a/lefttrigger'
R1_PRESS = '/osc/a/righttrigger'

# hats
PAD_LEFT = '/osc/b/dpleft'
PAD_RIGHT = '/osc/b/dpright'
PAD_UP = '/osc/b/dpup'
PAD_DOWN = '/osc/b/dpdown'

define :button_down do |key|
  puts 'button down'
  case key
  when OPTIONS
    increment_mode_select
  when PAD_RIGHT
    increment_syn_select(1)
  when PAD_LEFT
    increment_syn_select(-1)
  when PAD_UP
    increment_octave_shift(1)
  when PAD_DOWN
    increment_octave_shift(-1)
  else
    note_down key
  end
end

define :button_up do |key|
  puts 'button up'
  case key
  when LEFT_ANALOG_PRESS
    mute_synth LEFT_VERTICAL
  when RIGHT_ANALOG_PRESS
    mute_synth RIGHT_VERTICAL
  else
    mute_synth key
  end
end

define :on_osc do |key|
  use_real_time
  val = sync key
  val[0]
end

define :on_midi do |key|
  use_real_time
  sync key
end

define :atom_key_for do |key, id|
  if !get[id].key?(key)
    sym = [key, id].flatten.join('_').gsub('/','_').to_sym
    set(id, get[id].put(key, sym).to_hash)
  end
  get[id][key]
end

[:note_id, :sample_id, :synth_id, :down_id, :step_id, :drum_id].each do |some_id|
  set some_id, {}
  define some_id do |string_key|
    atom_key_for(string_key, some_id)
  end
end

[
  [SQUARE,   :c4, :elec_snare],
  [X,        :d4, :bd_fat],
  [CIRCLE,   :e4, :elec_fuzz_tom],
  [TRIANGLE, :f4, :drum_tom_mid_hard],
  [L1,       :g4, :elec_cymbal],
  [R1,       :a4, :elec_twip],
  [L1_PRESS, :b4, :elec_hollow_kick],
  [R1_PRESS, :c5, :elec_soft_kick]
].each do |key, note, drum|
  set(note_id(key), note)
  set(drum_id(key), drum)
end

define :osc_send_notes do |values|
  if !(values[:note] && values[:note].is_a?(Float))
    msg = '/' + values.entries.flatten.join('/')
    osc_send '0.0.0.0', 57121, msg, 1
  end
end

define :synth_name do |s|
  if (s && s.methods.include?(:name))
    s.name
  elsif (s && s.nodes[0])
    s.nodes[0].name
  else
    nil
  end
end

define :synth_name_unchanged? do |s|
  case get[:syn]
  when :piano, :pluck
    false
  else
    current_synth_name = synth_name(s)
    if unchanged = current_synth_name && current_synth_name.end_with?(get[:syn].to_s)
      unchanged
    else
      puts "non-matching synth name: #{current_synth_name}"
      unchanged
    end
  end
end

define :synth_started? do |s|
  s && (s.running? || s.state == :pending)
end

define :play_sample do |key, add_to_seq|
  s = get[drum_id(key)]
  puts ['drum', s].join(' - ')
  set(down_id(key), [vt, step_time, s, :sample]) if add_to_seq
  sample s
end

define :play_synth do |key, add_to_seq, values|
  set(down_id(key), [vt, step_time, values, :synth]) if add_to_seq
  puts [get[:syn], values].join(' - ')
  amp = values.delete(:amp) || 1
  s = get[synth_id(key)] # get saved synth
  if synth_started?(s) && synth_name_unchanged?(s)
    puts 'control synth'
    control s, values, amp: amp # reuse existing synth
  else
    puts 'new synth'
    if synth_started?(s)
      kill s # kill old synth process, in order to change synth name
    end
    s = synth get[:syn], values, amp: amp, sustain: 100
    set(synth_id(key), s) # save synth for reuse
  end
  # osc_send_notes(values)
end

define :step_time do
  step = quantise(rt(current_time.to_f) % get[:steps], get[:resolution])
  step
end

define :mute_synth do |key|
  s = get[synth_id(key)]
  puts 'get[down_id(key)]'
  puts key
  puts get[down_id(key)]
  if (get[down_id(key)])
    t, start, values, type = get[down_id(key)]
    duration = vt - t
    duration = quantise(duration, get[:resolution])
    puts ['step_start', start].join(' ')
    puts ['duration', duration].join(' ')
    puts ['values', values].join(' ')
    set(step_id(start), [duration, values, type])
  end
  if synth_started?(s)
    case get[:syn]
    when :piano, :pluck
      # no mute as they continue play after release
    else
      puts ["mute_synth",key].join(' - ')
      control s, amp: 0, amp_slide: 0.2 # mute synth
    end
  end
end

define :reset_index do |index, length|
  if index >= length
    0
  elsif index < 0
    (length - 1)
  else
    index
  end
end

define :osc_send_msg do |msg|
  osc_send "0.0.0.0", 57121, msg, 1
end

IGNORE_SYNTH = {
  bnoise: true, chipnoise: true, cnoise: true,
  gnoise: true, noise: true, pnoise: true,
  sound_in: true, sound_in_stereo: true
}

SYNTH_LIST = synth_names.to_a.reject{|n| IGNORE_SYNTH[n]}

define :increment_syn_select do |increment|
  p = get[:syn_pointer] + increment
  p = reset_index p, SYNTH_LIST.length
  set :syn_pointer, p
  set :syn, SYNTH_LIST[p]
  puts SYNTH_LIST[p]
  osc_send_msg "/synth/#{SYNTH_LIST[p]}"
end

define :increment_mode_select do
  p = get[:mode_pointer] + 1
  p = reset_index p, get[:modes].length
  set :mode_pointer, p
  set :mode, get[:modes][p]
  osc_send_msg "/mode/#{get[:mode]}"
end

define :increment_octave_shift do |increment|
  shift = get[:octave_shift] + increment
  shift = -5 if shift < -5
  shift = 4 if shift > 4
  set(:octave_shift, shift)
  puts "current octave"
  puts get[:octave_shift]
end

define :note_down do |key|
  case get[:mode]
  when :notes
    note = get[note_id(key)] + (get[:octave_shift] * 12)
    play_synth key, true, note: note if note
  when :chords
    note = get[note_id(key)] + (get[:octave_shift] * 12)
    play_synth key, true, notes: chord(note, :major) if note
  when :drums
    play_sample key, true
  end
end

define :axis_note do |val|
  ((val/32767.0*36+72) - 30).round(1)
end

define :midi_synth_select do |value|
  index = ((value / 127.0) * SYNTH_LIST.length).ceil - 1
  puts "index #{index}"
  puts "syn_pointer #{get[:syn_pointer]}"
  offset = index - get[:syn_pointer]
  puts "offset #{offset}"
  if offset > 0
    offset.times{ increment_syn_select(1) }
  elsif offset < 0
    (offset.abs - 1).times{ increment_syn_select(-1) }
  end
end

define :asdr_time do |type, value|
  time_in_beats = if value == 0
                    0
                  elsif value < 64
                    (value / 64.0).round(1)
                  elsif value == 64
                    1
                  else
                    ((value - 64) / 64.0 * 4).round(1) + 1
                  end
  set(type, time_in_beats)
end

live_loop :midi_control do
  control, value = on_midi('/midi/mio2_din_1/0/1/control_change')
  case control
  when 81
    midi_synth_select(value)
  when 18
    asdr_time :attack, value
  when 19
    asdr_time :delay, value
  when 86
    asdr_time :sustain, value
  when 87
    asdr_time :release, value
  when 88
    set(:hold_note, value == 64)
    set(:drum_keys, value == 127)
  when 89
    if (value > 0)
      set(:cutoff, ((value / 127.0) * 50 + 80).round)
    else
      set(:cutoff, 0)
    end
  when 90
  when 91
  else
  end
end

define :set_opts do |type, opts|
  if get[type] && get[type] > 0
    opts[type] = get[type]
  end
end

DKEYS = [SQUARE, X, CIRCLE,
TRIANGLE, L1,R1,
L1_PRESS,
R1_PRESS]

live_loop :midi_note do
  note, velocity = on_midi('/midi/mio2_din_1/0/1/note_on')
  if velocity > 0
    amp = ((velocity / 127.0) * 2 + 0.2).round(1)
    if get[:drum_keys]
      play_sample DKEYS[note % DKEYS.length], true
    elsif get[:hold_note]
      play_synth note, false, note: note, amp: amp
    else
      opts = {note: note, amp: amp}
      [:attack, :sustain, :delay, :release, :cutoff].each do |type|
        set_opts(type, opts)
      end
      puts [get[:syn], opts].join(' - ')
      synth(get[:syn], opts)
    end
  else
    mute_synth note
    mute_synth DKEYS[note % DKEYS.length]
  end
end

# live loops
live_loop :button_press do
  v = on_osc('/osc/b/*')
  key = get_event('/osc/b/*').path
  if v == 1
    button_down key
  else
    button_up key
  end
end


live_loop :do_step do
  step = step_time
  set(step_id(step), nil)
  if (get[step_id(step)])
    duration, values, type = get[step_id(step)]
    if duration
      puts step
      puts values
      puts duration
      case type
      when :synth
        synth get[:syn], values.to_hash, sustain: duration
      when :sample
        sample values
      end
    end
  end
  sleep get[:resolution]
end
