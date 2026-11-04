local dev = GetSelf()
local ticks = 0
make_default_activity(0.1)
need_to_be_closed = false
local function report(s)
    log.write('F4_SIMPLE_RADAR', log.INFO, s)
end
function post_initialize()
    report('POST_INITIALIZE; construction/update gate only')
    local ok, err = pcall(function() dev:set_power(true) end)
    report('set_power call=' .. tostring(ok) .. ' ' .. tostring(err))
end
function update()
    ticks = ticks + 1
    if ticks == 50 or ticks == 200 then
        report('UPDATE ticks=' .. tostring(ticks))
        for _, name in ipairs({'RADAR_MODE', 'RADAR_POWER', 'IFF_INTERROGATOR_STATUS'}) do
            local ok, value = pcall(function() return get_param_handle(name):get() end)
            report(name .. '=' .. tostring(value) .. ' read=' .. tostring(ok) .. '; zero may be uninitialized')
        end
    end
end
