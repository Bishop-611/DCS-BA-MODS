-- Current original input definition: switch_2('Interlock Position', {'Out','In'}).
-- Original WEAPONS device 27, command 3032: OUT=0, IN=1; argument 348.
local first=true
return function(reason)
    local read_ok,value=pcall(get_cockpit_draw_argument_value,348)
    if first or reason=='BLOCKED_INPUT' or (read_ok and type(value)=='number' and value>.01) then
        local ok,err=pcall(function() GetDevice(27):performClickableAction(3032,0,false) end)
        log.write('F4_SIMPLE_INTERLOCK',log.INFO,'FORCE_OUT reason='..tostring(reason)..' before='..
            (read_ok and tostring(value) or 'UNAVAILABLE')..' command_ok='..tostring(ok)..' '..tostring(err))
        first=false
    end
end
