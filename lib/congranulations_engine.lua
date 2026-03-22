-- congranulations_engine.lua
-- Lua wrapper for the Congranulations SuperCollider engine
-- Provides a clean API over engine.* commands

local Engine = {}

local NVOICES = 4

-- default parameter values
local defaults = {
  pos = 0,
  speed = 1,
  size = 0.1,
  density = 10,
  spray = 0.01,
  amp = 0.5,
  send = 0,
  reverb = 0.5,
  room = 0.7,
  damp = 0.5,
}

-- parameter ranges for clamping
local ranges = {
  pos = { 0, 1 },
  speed = { -4, 4 },
  size = { 0.01, 0.5 },
  density = { 0.5, 100 },
  spray = { 0, 0.5 },
  amp = { 0, 1 },
  send = { 0, 1 },
  reverb = { 0, 1 },
  room = { 0, 1 },
  damp = { 0, 1 },
}

local function clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

local function clamp_param(name, val)
  local r = ranges[name]
  if r then
    return clamp(val, r[1], r[2])
  end
  return val
end

--- Map a linear 0..1 input to an exponential curve.
-- Useful for density where perceptual scaling is logarithmic.
-- @param val number 0..1
-- @param min number output minimum
-- @param max number output maximum
-- @return number exponentially scaled value
function Engine.exp_scale(val, min, max)
  val = clamp(val, 0, 1)
  return min * (max / min) ^ val
end

-----------
-- Voice --
-----------

--- Load a sample file into a voice buffer.
-- @param voice number voice index (1-based)
-- @param path string file path to audio sample
function Engine.load_sample(voice, path)
  engine.read(voice, path)
end

--- Set grain playback position.
-- @param voice number voice index (1-based)
-- @param val number position 0..1
function Engine.set_position(voice, val)
  engine.pos(voice, clamp_param("pos", val))
end

--- Smoothly seek to a new position over time.
-- @param voice number voice index (1-based)
-- @param target number target position 0..1
function Engine.seek(voice, target)
  engine.seek(voice, clamp_param("pos", target))
end

--- Set playback speed/pitch.
-- @param voice number voice index (1-based)
-- @param val number speed multiplier (negative = reverse)
function Engine.set_speed(voice, val)
  engine.speed(voice, clamp_param("speed", val))
end

--- Set grain size in seconds.
-- @param voice number voice index (1-based)
-- @param val number grain duration in seconds
function Engine.set_size(voice, val)
  engine.size(voice, clamp_param("size", val))
end

--- Set grain trigger density (grains per second).
-- @param voice number voice index (1-based)
-- @param val number density in Hz
function Engine.set_density(voice, val)
  engine.density(voice, clamp_param("density", val))
end

--- Set grain trigger density from a linear 0..1 input with exponential scaling.
-- @param voice number voice index (1-based)
-- @param val number linear input 0..1
function Engine.set_density_exp(voice, val)
  local scaled = Engine.exp_scale(val, ranges.density[1], ranges.density[2])
  engine.density(voice, scaled)
end

--- Set position spray/jitter amount.
-- @param voice number voice index (1-based)
-- @param val number spray amount 0..0.5
function Engine.set_spray(voice, val)
  engine.spray(voice, clamp_param("spray", val))
end

--- Set voice amplitude.
-- @param voice number voice index (1-based)
-- @param val number amplitude 0..1
function Engine.set_volume(voice, val)
  engine.amp(voice, clamp_param("amp", val))
end

--- Set reverb send level for a voice.
-- @param voice number voice index (1-based)
-- @param val number send level 0..1
function Engine.set_send(voice, val)
  engine.send(voice, clamp_param("send", val))
end

--- Open or close a voice gate.
-- @param voice number voice index (1-based)
-- @param state number 1 = open, 0 = closed
function Engine.set_gate(voice, state)
  engine.gate(voice, state == 1 and 1 or 0)
end

--- Set a named parameter on a voice.
-- Convenience function for dynamic parameter setting.
-- @param voice number voice index (1-based)
-- @param param string parameter name (pos, speed, size, density, spray, amp, send)
-- @param val number parameter value
function Engine.set_voice_param(voice, param, val)
  local fn = {
    pos = Engine.set_position,
    speed = Engine.set_speed,
    size = Engine.set_size,
    density = Engine.set_density,
    spray = Engine.set_spray,
    amp = Engine.set_volume,
    send = Engine.set_send,
  }
  if fn[param] then
    fn[param](voice, val)
  end
end

------------
-- Effect --
------------

--- Set reverb wet/dry mix.
-- @param val number reverb mix 0..1
function Engine.set_reverb(val)
  engine.reverb(clamp_param("reverb", val))
end

--- Set reverb room size.
-- @param val number room size 0..1
function Engine.set_room(val)
  engine.room(clamp_param("room", val))
end

--- Set reverb damping.
-- @param val number damping 0..1
function Engine.set_damp(val)
  engine.damp(clamp_param("damp", val))
end

-----------
-- Utils --
-----------

--- Get the number of voices.
-- @return number
function Engine.get_nvoices()
  return NVOICES
end

--- Get default value for a parameter.
-- @param name string parameter name
-- @return number or nil
function Engine.get_default(name)
  return defaults[name]
end

--- Get range for a parameter.
-- @param name string parameter name
-- @return table {min, max} or nil
function Engine.get_range(name)
  return ranges[name]
end

--- Initialize all voices to default parameter values.
function Engine.init_defaults()
  for v = 1, NVOICES do
    Engine.set_position(v, defaults.pos)
    Engine.set_speed(v, defaults.speed)
    Engine.set_size(v, defaults.size)
    Engine.set_density(v, defaults.density)
    Engine.set_spray(v, defaults.spray)
    Engine.set_volume(v, defaults.amp)
    Engine.set_send(v, defaults.send)
    Engine.set_gate(v, 1)
  end
  Engine.set_reverb(defaults.reverb)
  Engine.set_room(defaults.room)
  Engine.set_damp(defaults.damp)
end

return Engine
