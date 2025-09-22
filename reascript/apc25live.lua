-- @description Simple APC Key25 pad matrix controller
-- @version 1.0
-- @author Tvoje Meno
-- @changelog
--   + Initial release
-- @about
--   Useful for live performance – pad matrix on APC Key25 is used as recarm/mute controller for tracks in REAPER.
--
--   ## How to use
--   Name your tracks as `Whatever [X]` where **X** is the CC number of each pad
--   (use MIDI monitor to see CC numbers or the example project bundled with this script).
--   Pressing any pad will arm/unarm/mute/unmute the corresponding track.

function dbg(arg)
  local time = os.date("%Y-%m-%d %H:%M:%S")
  --reaper.ShowConsoleMsg("[" .. time .. "] dbg: " .. arg .. "\n")
end

-- when turning off instrument, also mute the track
local DO_MUTE = true

local target_name = "APC Key 25"

local TRACK_MATRIX_CC_RANGE = {0, 39}

LAST_TOUCHED_MATRIX_PAD = nil


-- find midi input
local num_inputs = reaper.GetNumMIDIInputs()
input_device_index = -1
for i = 0, num_inputs - 1 do
    local retval, name = reaper.GetMIDIInputName(i, "")
    if retval and name == target_name then
        input_device_index = i
        break
    end
end
if input_device_index ~= -1 then
    dbg("Index of input device is: " .. input_device_index, "Result", 0)
else
    dbg("Input device was not found.", "Error", 0)
end

-- find midi outout (for leds)
local num_outputs = reaper.GetNumMIDIOutputs()
output_device_index = -1
for i = 0, num_outputs - 1 do
    local retval, name = reaper.GetMIDIOutputName(i, "")
    if retval and name == target_name then
        output_device_index = i
        break
    end
end
if output_device_index ~= -1 then
    dbg("Index of output device is: " .. output_device_index, "Result", 0)
else
    dbg("Output device was not found.", "Error", 0)
end

function setPadColor(padNo, color)
  -- 0 = off
  -- 1 = green
  -- 2 = green flash
  -- 3 = red
  -- 4 = red flash
  -- 5 = yellow
  -- 6 = yellow flash
  local deviceIndex = 16 + output_device_index
  dbg("Setting pad " .. padNo .. " color to " .. color .. " on device " .. deviceIndex)
  reaper.StuffMIDIMessage(deviceIndex, 0x90, padNo, color)
end

-- search for padno in track name (for example [0] or [33])
function getTrackByPadNo(padNo)
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local retval, name = reaper.GetTrackName(track, "")
    local tracknameSearchString = "%[" .. padNo .. "%]"
    if retval and name:find(tracknameSearchString) then
      return track
    end
  end
  return nil
end  

function flip(value)
  if value == 0 then
    return 1
  else
    return 0
  end
end

-- flip armed and muted state of the track
function triggerMuteArm(track, padNo)
  local armed = reaper.GetMediaTrackInfo_Value(track, "I_RECARM")
  local muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
  local arm = flip(armed)
  local mute = muted
  if(DO_MUTE) then    -- change mute state only if configured to do so
      mute = flip(arm)  -- unmute when armed, mute when disarmed
  end
  reaper.SetMediaTrackInfo_Value(track, "I_RECARM", arm)
  reaper.SetMediaTrackInfo_Value(track, "B_MUTE", mute)
end

function handleInstrumentPress(padNo)
  LAST_TOUCHED_MATRIX_PAD = padNo
  local track = getTrackByPadNo(padNo)
  if not track then
    dbg("Track no " .. padNo .. " was not found.")
    return
  end
  triggerMuteArm(track, padNo)
  initPadLeds()
end

function adjustVolume(howMuch)
    if not LAST_TOUCHED_MATRIX_PAD then
        return
    end
    local track = getTrackByPadNo(LAST_TOUCHED_MATRIX_PAD)
    if track then
        local muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") > 0
        if not muted then
          local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
          dbg("Current volume: " .. volume)
          volume = math.min(volume + howMuch, 1.0)
          reaper.SetMediaTrackInfo_Value(track, "D_VOL", volume)
        end
    end
end

function setVolume(volume)
    if not LAST_TOUCHED_MATRIX_PAD then
        return
    end
    local track = getTrackByPadNo(LAST_TOUCHED_MATRIX_PAD)
    if track then
        local muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") > 0
        if not muted then   -- do not set volume if track is muted
          dbg("Setting volume of track [" .. LAST_TOUCHED_MATRIX_PAD .. "] to " .. volume)
          reaper.SetMediaTrackInfo_Value(track, "D_VOL", volume)
        end
    end
end


function handlePadPress(padNo)
  dbg(padNo ..   " pressed \n")
  if padNo == 64 then -- volume up
    dbg("volume up pressed \n")
    adjustVolume(0.1)
  elseif padNo == 65 then -- volume down
    dbg("volume down pressed \n")
    adjustVolume(-0.1)
  elseif padNo >= TRACK_MATRIX_CC_RANGE[1] and padNo <= TRACK_MATRIX_CC_RANGE[2] then  -- instrument matrix
    handleInstrumentPress(padNo)
  end
  initPadLeds()
end

function processCC(cc, value)
  dbg("CC " .. cc .. " value: " .. value)
  if cc == 48 then -- volume knob
    setVolume(value/127.0)
  end 
end

function initPadLeds()
  for padNo = TRACK_MATRIX_CC_RANGE[1], TRACK_MATRIX_CC_RANGE[2] do
    local track = getTrackByPadNo(padNo)
    if track then
      local armed = reaper.GetMediaTrackInfo_Value(track, "I_RECARM") > 0
      if armed then
        setPadColor(padNo, 1) -- green
      else
        setPadColor(padNo, 0) -- off
      end
    else    -- track not found
      setPadColor(padNo, 0) -- off
    end
  end
end


last_retval = 0     -- debouncing using last retval vrom MIDI_GetRecentInputEvent
function main_loop()
  local retval, msg, ts, devIdx, projPos, projLoopCnt = reaper.MIDI_GetRecentInputEvent(0)
  --dbg("retval: ".. retval .. "\n")
  --dbg("devidx: ".. devIdx.. "\n")
  if (devIdx == input_device_index and retval ~= last_retval) then
    last_retval = retval
    --dbg("devIdx: ".. devIdx .. "\n")
    --dbg("msg: ".. msg .. "\n")
    local status = msg:byte(1)
    local data1 = msg:byte(2)
    local data2 = msg:byte(3)
    local message_type = status & 0xF0
    local channel = (status & 0x0F) + 1
    note = data1       -- pad matrix is numbered from left bottom pad as 0, 7 is right bottom, 39 is right upper
    --dbg(message_type .. " " .. note)
     
    if message_type == 0x90 then  -- Note On
      dbg("on " .. note)
      handlePadPress(note)
    elseif message_type == 0x80  then -- Note Off
      dbg("off")
    elseif message_type == 0xB0 then    -- CC
      processCC(note, data2)
    end
  end      -- if devIdx == input_device_index
  initPadLeds()
  reaper.defer(main_loop)
end

reaper.defer(main_loop)
