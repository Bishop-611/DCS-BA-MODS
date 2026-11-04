-- Automatic ARR hold, NOT radar slaving or proof of IR acquisition.
-- Local F-4 command_defs.lua: WEAPONS_ARR=3020; WEAPONS device=27.
local previous,owned=false,false
return function(wanted)
    wanted=not not wanted
    if wanted==previous then return end
    previous=wanted
    local command
    if wanted then
        local ok,held=pcall(get_cockpit_draw_argument_value,2780)
        if not(ok and type(held)=='number' and held>.5) then command=1 end
    elseif owned then command=0 end
    if command~=nil then
        local ok,err=pcall(function() GetDevice(27):performClickableAction(3020,command,false) end)
        owned=command==1 and ok
        if type(log)=='table' then log.write('F4_HEAT_UNCAGE',log.INFO,'ARR='..command..' call_ok='..tostring(ok)..' '..tostring(err)..'; IR lock not inferred') end
    end
end
