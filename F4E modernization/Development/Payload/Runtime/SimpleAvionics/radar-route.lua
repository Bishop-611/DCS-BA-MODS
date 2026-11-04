-- Stage 6 INPLACE_HOLD5: acquisition held 5 seconds; game entry unchanged.
local radar_profile=dofile([[__F4_RUNTIME__/radar-profile.lua]])
perfomance=radar_profile.performance -- DCS API intentionally spells this without the second 'r'.
dofile([[__F4_RUNTIME__/radar-contacts.lua]])
local update_bscope = dofile([[__F4_RUNTIME__/display-data.lua]])
local receive_update = update
local receive_init = post_initialize
local tick, selected, pressed, released = 0, nil, false, false
local dev = GetSelf()
local command_count = 0
local native_off_attempts = 0
dev:listen_command(509)
dev:listen_command(510)
local mode = get_param_handle('RADAR_MODE')
local range = get_param_handle('RADAR_STT_RANGE')
local azimuth = get_param_handle('RADAR_STT_AZIMUTH')
local elevation = get_param_handle('RADAR_STT_ELEVATION')
local friendly = get_param_handle('RADAR_STT_FRIENDLY')
local iff = get_param_handle('IFF_INTERROGATOR_STATUS')
local tdc_az = get_param_handle('RADAR_TDC_AZIMUTH')
local tdc_range = get_param_handle('RADAR_TDC_RANGE')
local tdc_size = get_param_handle('RADAR_TDC_RANGE_CARRET_SIZE')
local contacts = {}
for i = 1, 128 do
    local prefix = string.format('RADAR_CONTACT_%02d_', i)
    contacts[i] = {
        range=get_param_handle(prefix .. 'RANGE'),
        age=get_param_handle(prefix .. 'TIME'),
        az=get_param_handle(prefix .. 'AZIMUTH')
    }
end
local function report(s) log.write('F4_SIMPLE_IFF', log.INFO, s) end
function SetCommand(command, value)
    if command == 509 or command == 510 then
        command_count = command_count + 1
        report('RECEIVED command=' .. tostring(command) .. ' value=' .. tostring(value) ..
            ' mode=' .. tostring(mode:get()) .. '; Lua receipt does not prove native handling')
    end
end
function post_initialize()
    receive_init()
    get_param_handle('SCAN_ZONE_VOLUME_AZIMUTH'):set(radar_profile.performance.scan_volume_azimuth)
    get_param_handle('SCAN_ZONE_VOLUME_ELEVATION'):set(radar_profile.performance.scan_volume_elevation)
    get_param_handle('SCAN_ZONE_ORIGIN_AZIMUTH'):set(0)
    get_param_handle('SCAN_ZONE_ORIGIN_ELEVATION'):set(0)
    get_param_handle('RADAR_PITCH_STABILIZATION'):set(1)
    get_param_handle('RADAR_ROLL_STABILIZATION'):set(1)
    log.write('F4_SIMPLE_PROFILE',log.INFO,radar_profile.name..'; configured 80deg/20deg, beam5deg, speed120deg/s; actual revisit requires measurement')
    report('ARMED AUTO_NATIVE_OFF POSITIVE_NO_CUTOFF BRIDGE_SURFACE35 subscribed 509/510; IFF_ON30 five-second hold; interrogator enabled at 30 seconds; no weapons')
end
function update()
    receive_update()
    update_bscope()
    tick = tick + 1
    -- Current F-4 command_defs.lua resolves RADAR_Power_Knob_RIO to 3004.
    if tick % 10 == 0 and native_off_attempts < 10 then
        local knob_ok, knob = pcall(function() return get_cockpit_draw_argument_value(336) end)
        if knob_ok and type(knob) == 'number' and math.abs(knob) > 0.01 then
            native_off_attempts = native_off_attempts + 1
            local ok, err = pcall(function()
                local native = assert(GetDevice(52), 'Original radar device unavailable')
                native:performClickableAction(3004, 0, false)
            end)
            log.write('F4_SIMPLE_CONTROL', log.INFO, 'AUTO_NATIVE_OFF attempt=' .. tostring(native_off_attempts) ..
                ' before=' .. tostring(knob) .. ' call=' .. tostring(ok) .. ' ' .. tostring(err))
            if native_off_attempts == 10 then
                log.write('F4_SIMPLE_CONTROL', log.INFO, 'AUTO_NATIVE_OFF retry limit reached; verify knob telemetry')
            end
        end
    end
    if tick == 400 then
        local ok, err = pcall(function() dev:set_power(true) end)
        log.write('F4_SIMPLE_CONTROL', log.INFO, 'POSITIVE_NO_CUTOFF power_on_call=' .. tostring(ok) .. ' ' .. tostring(err))
    end
    if tick % 10 == 0 and tick <= 1800 then
        local knob_ok, knob = pcall(function() return get_cockpit_draw_argument_value(336) end)
        local power_ok, power = pcall(function() return dev:get_power() end)
        log.write('F4_SIMPLE_CONTROL', log.INFO, 'STATE ticks=' .. tostring(tick) ..
            ' original_knob_arg336=' .. (knob_ok and tostring(knob) or 'UNAVAILABLE') ..
            ' simple_power=' .. (power_ok and tostring(power) or 'UNAVAILABLE') ..
            ' mode=' .. tostring(mode:get()) .. ' range=' .. tostring(range:get()))
    end
    if tick == 350 then
        local ok, err = pcall(function()
            local inspect = dofile([[__F4_RUNTIME__/inspect-weapon-interfaces.lua]])
            inspect()
        end)
        log.write('F4_SIMPLE_BRIDGE', log.INFO, 'BRIDGE_SURFACE35 success=' .. tostring(ok) .. (ok and '' or (' error=' .. tostring(err))))
    end
    if tick == 300 then
        report('IFF_ENABLE before=' .. tostring(iff:get()) .. ' friendly=' .. tostring(friendly:get()))
        iff:set(1)
        report('IFF_ENABLE readback=' .. tostring(iff:get()) .. '; readback alone does not prove identification')
    end
    if not selected and tick >= 200 and tick <= 1200 and tick % 10 == 0 and mode:get() == 1 then
        local best, score = nil, math.huge
        for i, c in ipairs(contacts) do
            local r, age, az = c.range:get(), c.age:get(), c.az:get()
            if r > 1000 and r < 50000 and age >= 0 and age <= 2 and math.abs(az) < math.rad(30) then
                if math.abs(az) < score then best, score = i, math.abs(az) end
            end
        end
        if best then
            local c = contacts[best]
            tdc_az:set(c.az:get())
            tdc_range:set(c.range:get())
            tdc_size:set(3000)
            selected = tick
            report('TDC placed slot=' .. tostring(best) .. ' range=' .. tostring(c.range:get()) .. ' az=' .. tostring(c.az:get()))
        end
    end
    if selected and not pressed and tick >= selected + 2 then
        pressed = true
        local ok, err = pcall(function() dispatch_action(nil, 509) end)
        report('LOCK_START call=' .. tostring(ok) .. ' ' .. tostring(err) .. '; not lock confirmation')
    end
    if selected and pressed and not released and tick >= selected + 52 then
        released = true
        local ok, err = pcall(function() dispatch_action(nil, 510) end)
        report('LOCK_FINISH call=' .. tostring(ok) .. ' ' .. tostring(err))
    end
    if tick <= 1800 and (tick % 10 == 0 or (selected and tick <= selected + 65)) then
        report('STATE ticks=' .. tostring(tick) .. ' mode=' .. tostring(mode:get()) ..
            ' range=' .. tostring(range:get()) .. ' az=' .. tostring(azimuth:get()) ..
            ' el=' .. tostring(elevation:get()) .. ' friendly=' .. tostring(friendly:get()) ..
            ' TDC_AZ=' .. tostring(tdc_az:get()) .. ' TDC_RANGE=' .. tostring(tdc_range:get()) ..
            ' IFF_STATUS=' .. tostring(iff:get()) .. ' TDC_SIZE=' .. tostring(tdc_size:get()) .. ' received=' .. tostring(command_count))
    end
end
