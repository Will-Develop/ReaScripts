-- @description Save project plugin info to text file
-- @author Edgemeal
-- @version 1.03
-- @changelog Open created text file in OS default application.
-- @link Forum https://forum.cockos.com/showthread.php?t=225219
-- @donation Donate https://www.paypal.me/Edgemeal

function Add_TakeFX(fx_names, name)
  for i = 1, #fx_names do -- do not add duplicates
    if fx_names[i] == name then return end
  end
  fx_names[#fx_names+1] = name
end

function GetLastWord(line)
  local lastpos = (line:reverse()):find(' ')
  return (line:sub(-lastpos+1))
end

local function RemoveFileExt(file)
  local index = (file:reverse()):find("%.")
  if index > 0 then
    return string.sub(file, 1, #file-index)
  else
    return file
  end
end

function Status(fx_name,preset_name, enabled, offline)
  if preset_name ~= "" then  -- add track fx name and preset name
    t[#t+1] = (enabled and "" or "* ") .. (offline and "# " or "") .. fx_name .. " <> Preset: " .. preset_name
  else
    t[#t+1] = (enabled and "" or "* ") .. (offline and "# " or "") .. fx_name
  end
end

function AddFX(track,fx_count)
  for fx = 0, fx_count-1 do
    local _, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
    local _, preset_name = reaper.TrackFX_GetPreset(track, fx, "")
    local enabled = reaper.TrackFX_GetEnabled(track, fx) -- bypass
    local offline = reaper.TrackFX_GetOffline(track, fx) -- offline
    Status(fx_name,preset_name,enabled,offline) -- add fx info
  end
end

function AddItemFX(track,track_name)
  local itemcount = reaper.CountTrackMediaItems(track)
  if itemcount > 0 then
    local fx_used = {}
    for j = 0, itemcount-1 do
      local item = reaper.GetTrackMediaItem(track, j)
      local take = reaper.GetActiveTake(item)
      local fx_count = reaper.TakeFX_GetCount(take)
      for fx = 0, fx_count-1 do
        local _, fx_name = reaper.TakeFX_GetFXName(take, fx, "")
        Add_TakeFX(fx_used,fx_name)
      end
    end
    if #fx_used > 0 then
      local tn = track_name .. ' - Media Items FX\n'
      t[#t+1]=tn..string.rep('-', #tn-1)
      t[#t+1]= table.concat(fx_used, "\n")
      t[#t+1]= "" -- empty line
    end
  end
end

function AddFxMonitor()
  local track = reaper.GetMasterTrack()
  local cnt = reaper.TrackFX_GetRecCount(track) -- get fx count in 'fx monitoring' chain.
  if cnt > 0 then
    local tn ="FX Monitoring\n"
    t[#t+1]=tn..string.rep('-', #tn-1)
    for i = 0, cnt-1 do
      local fx = (0x1000000 + i) -- convert for fx monitoring
      local retval, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
      local _, preset_name = reaper.TrackFX_GetPreset(track, fx, "")
      local enabled = reaper.TrackFX_GetEnabled(track, fx) -- bypass
      local offline = reaper.TrackFX_GetOffline(track, fx) -- offline
      Status(fx_name,preset_name,enabled,offline) -- add fx info
    end
    t[#t+1]= "" -- add empty line
  end
end

function get_line(filename, line_number)
  local i = 0
  for line in io.lines(filename) do
    i = i + 1
    if i == line_number then
      return line
    end
  end
  return nil -- line not found
end

function Main()
  local proj, projfn = reaper.EnumProjects(-1, "")
  if projfn ~= "" then
    t[#t+1]="Project: "..reaper.GetProjectName(proj, "")
    t[#t+1]="Path: "..reaper.GetProjectPath("")
    local line = get_line(projfn, 1)-- project time stamp, Unix format, last word in 1st line of project file.
    local unixTS = (GetLastWord(line))
    t[#t+1]='Date: ' ..(os.date("%B %d, %Y  %X", tonumber(unixTS))) -- convert to "month day, year  time"
    t[#t+1]='Length: ' .. reaper.format_timestr(reaper.GetProjectLength(proj), "")
  else
    t[#t+1]="Unknown project (not saved)"
  end
  t[#t+1]= '* = Plugin disabled, # = Plugin Offline'
  t[#t+1]= ""  -- empty line

  -- FX Monitor
  AddFxMonitor()

  -- Master Track
  local track = reaper.GetMasterTrack(0)
  local fx_count = reaper.TrackFX_GetCount(track)
  if fx_count > 0 then
    local tn ="Master Track\n"  -- add track name
    t[#t+1]=tn..string.rep('-', #tn-1)
    AddFX(track,fx_count)
    t[#t+1]= ""  -- empty line
  end

  -- Regular Tracks
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count-1  do
    local track = reaper.GetTrack(0, i)
    local _, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME' , '', false)
    local tn ='Track '..tostring(i+1)..': '..track_name..'\n'  -- add track name
    t[#t+1]=tn..string.rep('-', #tn-1)
    AddFX(track,reaper.TrackFX_GetCount(track))
    t[#t+1]= ""  -- empty line
    AddItemFX(track, string.sub(tn,1,#tn-1)) -- show fx names used in items on this track.
  end

  -- save project info to text file in project folder
  if projfn ~= "" then
    local fn = RemoveFileExt(projfn).." - Project Plugins.txt"
    local file = io.open(fn, "w")
    file:write(table.concat(t,"\n"))
    file:close()

    -- Close instances with exact same title open via Windows notepad.
    local os = reaper.GetOS()-- get OS
    if (os == 'Win32') or (os == 'Win64') then
      if reaper.APIExists('JS_Window_FindTop') then -- check if JS_API extension is installed
        local np_title = RemoveFileExt(reaper.GetProjectName(proj, ""))..' - Project Plugins.txt - Notepad'
        local hwnd = reaper.JS_Window_FindTop(np_title, true)
        while hwnd do
          reaper.JS_WindowMessage_Send(hwnd, "WM_CLOSE", 0,0,0,0)
          hwnd = reaper.JS_Window_FindTop(np_title, true)
        end
      end
    end
    -- open text file in OS default application
    reaper.CF_ShellExecute(fn)
  else
    reaper.ClearConsole()
    reaper.ShowConsoleMsg(table.concat(t,"\n"))
  end
end

t = {} -- store proj info
Main()
