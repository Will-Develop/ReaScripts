--[[
ReaScript name: spk77_Adjust volume envelope point at mouse cursor via mousewheel.lua
Version: 1.2
Author: spk77
About:
  # Adjusts envelope points under mouse cursor via the mousewheel
Changelog:
 * v1.2(27-01-2020)
  + amagalma modifications: added improved support for Tempo envelope, added Trim Volume env support, added support for any other envelope
--]]

-------------------
-- User settings --
-------------------

-- Adjustment behavior
local adj_sel_env = false   -- true:  envelope has to be selected

-- Volume envelope step size
-- (User configurable "dB_steps": see "set_envelope_point" -function)

-- Pan envelope step size
local pan_env_step = 0.01 -- 200 steps (-1 to 1)

-- Width envelope step size
local width_env_step = 0.01 -- 200 steps (-1 to 1)

-- Mute envelope step size
local mute_env_step = 1 -- 2 steps (0 to 1)

-- Step count for all other envelopes
local all_steps = 200

----------------------------------------------------------------------

local dB_step = 0.2

local max = math.max
local abs = math.abs
local exp = math.exp
local log = math.log

local dbg = true

function msg(m)
  if dbg then
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
  end
end

-- Justin's functions ----------------------------------------
function VAL2DB(x)
  if x < 0.0000000298023223876953125 then 
    x = -150
  else
    x = max(-150, log(x)* 8.6858896380650365530225783783321)
  end
  return x
end

function DB2VAL(x)
  return exp(x*0.11512925464970228420089957273422)
end
--------------------------------------------------------------

-- Set new value for an envelope point
function set_envelope_point(env_prop_table, m_wheel_delta)
  local e = env_prop_table
  local env = e.pointer
  if env == nil then
    return
  end
  local min_val = e.min_val
  local max_val = e.max_val

  local br_env = reaper.BR_EnvAlloc(env, true)
  local pos = reaper.BR_PositionAtMouseCursor(false)
  local p_index = reaper.BR_EnvFind(br_env, pos, 10)
  local get_point_ret, position, value, shape, selected, bezier = reaper.BR_EnvGetPoint(br_env, p_index)
  reaper.BR_EnvFree(br_env, false)

  -- Volume envelopes
  if e.name == "Volume" or e.name == "Volume (Pre-FX)" or e.name == "Trim Volume" then
    local dB_val = VAL2DB(abs(value))
   
    -- Change the "dB_step" here
    if     dB_val < -90 then dB_step = 5     -- < -90 dB
    elseif dB_val < -60 then dB_step = 3     -- from -90 to -60 dB
    elseif dB_val < -45 then dB_step = 2     -- from -60 to -45 dB
    elseif dB_val < -30 then dB_step = 1.5   -- from -45 to -30 dB
    elseif dB_val < -18 then dB_step = 1     -- from -30 to -18 dB
    elseif dB_val < 24  then dB_step = 0.2   -- from -18 to 24 dB
    end  
    
    if m_wheel_delta < -1 then 
      dB_step = -dB_step 
    end
     value = DB2VAL(dB_val + dB_step)
  
  -- Pan envelopes
  elseif e.name == "Pan" or e.name == "Pan (Pre-FX)" then
    if m_wheel_delta < -1 then 
      pan_env_step = -pan_env_step
    end
    value = value + pan_env_step

  -- Width envelopes 
  elseif e.name == "Width" or e.name == "Width (Pre-FX)" then
    if m_wheel_delta < -1 then 
      width_env_step = -width_env_step
    end
    value = value + width_env_step
  
  -- Mute envelope
  elseif e.name == "Mute" then
    if m_wheel_delta < -1 then 
      mute_env_step = -mute_env_step
    end
    value = value + mute_env_step
  
  -- Tempo Map envelope
  elseif e.name == "Tempo map" then
    local sign = 1
    if m_wheel_delta < -1 then 
      sign = -1
    end
    if value < 65 then
      value = value + 0.5*sign
    elseif value >= 65 and value < 140 then
      value = value + 1*sign
    else
      value = value + 2*sign
    end
    
  else -- all other envelopes
    local step = (e.max_val - e.min_val)/all_steps
    if m_wheel_delta < -1 then 
     step = -step
   end
   value = value + step
  end
  
  if value < e.min_val then
    value = e.min_val
  end
  
  if value > e.max_val then
    value = e.max_val
  end
  
  if e.is_fader_scaling then
    value = reaper.ScaleToEnvelopeMode(1, value)
  end
  
  reaper.SetEnvelopePoint(env, p_index, nil, value, nil, nil, nil, true)
  reaper.UpdateTimeline()
  reaper.Undo_OnStateChangeEx("Adjust envelope point", 1, -1)
end


-- Returns "envelope properties" table 
function get_env_properties(env)
   envelope = {}
  if env ~= nil then
    local br_env = reaper.BR_EnvAlloc(env, true)
    local active, visible, armed, in_lane, lane_height, default_shape, 
          min_val, max_val, center_val, env_type, is_fader_scaling
          = reaper.BR_EnvGetProperties(br_env, false, false, false, false, 0, 0, 0, 0, 0, 0, false)        
    reaper.BR_EnvFree(br_env, false)
    
    local env_name = ({reaper.GetEnvelopeName(env, "")})[2]
    if env_name == "Volume" or env_name == "Volume (Pre-FX)" then
      max_val = reaper.SNM_GetIntConfigVar("volenvrange", -1)
      if max_val ~= -1 then
        if max_val == 1 then 
          max_val = 1.0
        elseif max_val == 0 then 
          max_val = 2.0
        elseif max_val == 4 then 
          max_val = 4.0
        else 
          max_val = 16.0
        end
      end 
    end
    
    --[[
    if is_fader_scaling then
      max_val    = reaper.ScaleToEnvelopeMode(1, max_val)
      center_val = reaper.ScaleToEnvelopeMode(1, center_val)
      min_val    = reaper.ScaleToEnvelopeMode(1, min_val)
    end
    --]]
    
    -- Store values to "envelope" table
    envelope.pointer = env
    envelope.active = active
    envelope.visible = visible
    envelope.armed = armed
    envelope.in_lane = in_lane
    envelope.lane_height = lane_height
    envelope.default_shape = default_shape
    envelope.min_val = min_val
    envelope.max_val = max_val
    envelope.center_val = center_val
    envelope.is_fader_scaling = is_fader_scaling
    envelope.type = env_type
    envelope.name = env_name
  end
  return envelope
  
end


----------
-- Main --
----------
function main()
  local m_wheel_delta = ({reaper.get_action_context()})[7]
  if m_wheel_delta == -1 then
    return
  end 
  local windowOut, segment, details = reaper.BR_GetMouseCursorContext()
  local env
  if adj_sel_env then
    env = reaper.GetSelectedEnvelope(0)
  else
    env, is_take_env = reaper.BR_GetMouseCursorContext_Envelope()
  end
  if env == nil then -- or is_take_env then
    local track, context = reaper.BR_TrackAtMouseCursor()
    local master = reaper.GetMasterTrack( 0 )
    if context == 2 and track == master then
      env = reaper.GetTrackEnvelopeByName( master, "Tempo map" )
    else
      return
    end
  end
  local env_name = ({reaper.GetEnvelopeName(env, "")})[2]
  env_properties = get_env_properties(env)
  set_envelope_point(env_properties, m_wheel_delta)
end

reaper.defer(main)
