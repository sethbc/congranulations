-- congranulations
-- granular synthesis for norns
-- E1: select voice  E2: position  E3: grain size
-- K2: play/pause  K3: randomize

engine.name = 'Congranulations'

local g = include("lib/congranulations_engine")

local NVOICES = g.get_nvoices()

-- state
local selected_voice = 1
local playing = {}
local phase_polls = {}
local level_polls = {}
local voice_phase = {}
local voice_level = {}

local redraw_metro

function init()
  for i = 1, NVOICES do
    playing[i] = true
    voice_phase[i] = 0
    voice_level[i] = 0
  end

  init_params()
  g.init_defaults()
  init_polls()

  redraw_metro = metro.init()
  redraw_metro.time = 1 / 15
  redraw_metro.event = function()
    redraw()
  end
  redraw_metro:start()
end

-- params --

local function make_voice_params(v)
  local prefix = "voice_" .. v .. "_"

  params:add_file(prefix .. "sample", "voice " .. v .. " sample")
  params:set_action(prefix .. "sample", function(path)
    if path ~= "" and path ~= "-" and path ~= "none" then
      g.load_sample(v, path)
    end
  end)

  params:add_control(prefix .. "position", "voice " .. v .. " position",
    controlspec.new(0, 1, "lin", 0, 0, ""))
  params:set_action(prefix .. "position", function(val)
    g.set_position(v, val)
  end)

  params:add_control(prefix .. "size", "voice " .. v .. " size",
    controlspec.new(0.01, 0.5, "exp", 0, 0.1, "s"))
  params:set_action(prefix .. "size", function(val)
    g.set_size(v, val)
  end)

  params:add_control(prefix .. "density", "voice " .. v .. " density",
    controlspec.new(0.5, 100, "exp", 0, 10, "hz"))
  params:set_action(prefix .. "density", function(val)
    g.set_density(v, val)
  end)

  params:add_control(prefix .. "speed", "voice " .. v .. " speed",
    controlspec.new(-4, 4, "lin", 0, 1, ""))
  params:set_action(prefix .. "speed", function(val)
    g.set_speed(v, val)
  end)

  params:add_control(prefix .. "spray", "voice " .. v .. " spray",
    controlspec.new(0, 0.5, "lin", 0, 0.01, ""))
  params:set_action(prefix .. "spray", function(val)
    g.set_spray(v, val)
  end)

  params:add_control(prefix .. "volume", "voice " .. v .. " volume",
    controlspec.new(0, 1, "lin", 0, 0.5, ""))
  params:set_action(prefix .. "volume", function(val)
    g.set_volume(v, val)
  end)

  params:add_control(prefix .. "send", "voice " .. v .. " reverb send",
    controlspec.new(0, 1, "lin", 0, 0, ""))
  params:set_action(prefix .. "send", function(val)
    g.set_send(v, val)
  end)
end

function init_params()
  params:add_separator("congranulations")

  for v = 1, NVOICES do
    params:add_group("voice " .. v, 8)
    make_voice_params(v)
  end

  params:add_group("effects", 3)

  params:add_control("reverb_mix", "reverb mix",
    controlspec.new(0, 1, "lin", 0, 0.5, ""))
  params:set_action("reverb_mix", function(val)
    g.set_reverb(val)
  end)

  params:add_control("reverb_room", "reverb room",
    controlspec.new(0, 1, "lin", 0, 0.7, ""))
  params:set_action("reverb_room", function(val)
    g.set_room(val)
  end)

  params:add_control("reverb_damp", "reverb damp",
    controlspec.new(0, 1, "lin", 0, 0.5, ""))
  params:set_action("reverb_damp", function(val)
    g.set_damp(val)
  end)

  params:bang()
end

-- polls --

function init_polls()
  for i = 1, NVOICES do
    phase_polls[i] = poll.set("phase_" .. i)
    phase_polls[i].callback = function(val)
      voice_phase[i] = val
    end
    phase_polls[i]:start()

    level_polls[i] = poll.set("level_" .. i)
    level_polls[i].callback = function(val)
      voice_level[i] = val
    end
    level_polls[i]:start()
  end
end

-- controls --

function enc(n, d)
  if n == 1 then
    selected_voice = util.clamp(selected_voice + (d > 0 and 1 or -1), 1, NVOICES)
  elseif n == 2 then
    local prefix = "voice_" .. selected_voice .. "_"
    params:delta(prefix .. "position", d)
  elseif n == 3 then
    local prefix = "voice_" .. selected_voice .. "_"
    params:delta(prefix .. "size", d)
  end
end

function key(n, z)
  if z ~= 1 then return end

  if n == 2 then
    playing[selected_voice] = not playing[selected_voice]
    g.set_gate(selected_voice, playing[selected_voice] and 1 or 0)
  elseif n == 3 then
    randomize_voice(selected_voice)
  end
end

function randomize_voice(v)
  local prefix = "voice_" .. v .. "_"
  params:set(prefix .. "position", math.random())
  params:set(prefix .. "size", 0.01 + math.random() * 0.49)
  params:set(prefix .. "density", 0.5 + math.random() * 99.5)
  params:set(prefix .. "speed", -4 + math.random() * 8)
  params:set(prefix .. "spray", math.random() * 0.5)
end

-- display --

function redraw()
  screen.clear()
  screen.aa(1)

  -- header
  screen.level(15)
  screen.move(0, 7)
  screen.text("congranulations")

  -- voice indicators
  for i = 1, NVOICES do
    local x = 90 + (i - 1) * 10
    screen.level(i == selected_voice and 15 or 3)
    screen.move(x, 7)
    screen.text(i)
    if not playing[i] then
      screen.level(1)
      screen.move(x, 9)
      screen.line(x + 5, 9)
      screen.stroke()
    end
  end

  -- waveform / position display per voice
  local lane_h = 10
  local lane_y = 14
  for i = 1, NVOICES do
    local y = lane_y + (i - 1) * (lane_h + 2)
    local is_sel = i == selected_voice

    -- lane background
    screen.level(is_sel and 2 or 1)
    screen.rect(0, y, 128, lane_h)
    screen.fill()

    -- level meter (background bar)
    local lvl = voice_level[i] or 0
    if lvl > 0 and playing[i] then
      screen.level(is_sel and 4 or 2)
      screen.rect(0, y, math.floor(128 * math.min(lvl * 3, 1)), lane_h)
      screen.fill()
    end

    -- position indicator
    local px = math.floor(voice_phase[i] * 126) + 1
    screen.level(is_sel and 15 or 7)
    screen.move(px, y)
    screen.line(px, y + lane_h)
    screen.stroke()

    -- voice label
    screen.level(is_sel and 15 or 5)
    screen.move(2, y + 7)
    screen.text(i)

    -- playing state
    if not playing[i] then
      screen.level(is_sel and 8 or 3)
      screen.move(8, y + 7)
      screen.text("||")
    end
  end

  -- param display at bottom
  local v = selected_voice
  local prefix = "voice_" .. v .. "_"
  screen.level(10)
  screen.move(0, 62)
  local pos_val = string.format("%.2f", params:get(prefix .. "position"))
  local size_val = string.format("%.2f", params:get(prefix .. "size"))
  local dens_val = string.format("%.1f", params:get(prefix .. "density"))
  screen.text("p:" .. pos_val .. " s:" .. size_val .. " d:" .. dens_val)

  screen.update()
end

-- cleanup --

function cleanup()
  if redraw_metro then
    redraw_metro:stop()
  end
  for i = 1, NVOICES do
    if phase_polls[i] then phase_polls[i]:stop() end
    if level_polls[i] then level_polls[i]:stop() end
  end
end
