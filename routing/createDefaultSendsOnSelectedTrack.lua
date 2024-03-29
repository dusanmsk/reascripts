-- reascript will create sends from selected track to all tracks which name starts with 'SEND -'

function isRoutedTo(track1, track2)
    local send_count = reaper.GetTrackNumSends(track1, 0)
    for i = 0, send_count - 1 do
      local dest_track = reaper.GetTrackSendInfo_Value(track1, 0, i, "P_DESTTRACK")
      if dest_track == track2 then
        return true
      end
    end
    return false
end


selected_track = reaper.GetSelectedTrack(0, 0)
_, selected_track_name = reaper.GetSetMediaTrackInfo_String(selected_track, "P_NAME", "", false)
if string.match(selected_track_name, "^SEND -") then
  reaper.ShowMessageBox("Error", "Can't create route to from 'SEND -' track to all 'SEND -' tracks", 0) 
  return
end

if selected_track ~= nil then
    track_count = reaper.CountTracks(0)
    for i = 0, track_count - 1 do
        track = reaper.GetTrack(0, i)
        _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if string.match(track_name, "^SEND -") and not isRoutedTo(selected_track, track) then
            sendIdx = reaper.CreateTrackSend(selected_track, track)
            reaper.SetTrackSendInfo_Value(selected_track, 0, sendIdx, "D_VOL", 0)
        end
    end
end

