local dev = GetSelf()
local ticks = 0
make_default_activity(0.1)
need_to_be_closed = false
local function report(s)
    log.write('F4_SIMPLE_ELECTRIC', log.INFO, s)
end
local function call(name, ...)
    local args = {...}
    local ok, value = pcall(function() return dev[name](dev, unpack(args)) end)
    report(name .. ': ' .. tostring(ok) .. ' ' .. tostring(value))
end
function post_initialize()
    report('POST_INITIALIZE; isolated experimental supply')
    call('AC_Generator_1_on', true)
    call('AC_Generator_2_on', true)
    call('DC_Battery_on', true)
end
function update()
    ticks = ticks + 1
    if ticks == 50 or ticks == 200 then
        report('UPDATE ticks=' .. tostring(ticks))
        call('get_AC_Bus_1_voltage')
        call('get_DC_Bus_1_voltage')
    end
end
