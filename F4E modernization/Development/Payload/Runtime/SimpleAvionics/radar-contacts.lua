-- Stage 3: observe default radar returns before tuning its performance.
-- Contact names verified against Nero.ger's original Basic Radar example thread.
local dev = GetSelf()
local ticks = 0
local contacts = {}
local fields = {'RANGE','TIME','AZIMUTH','ELEVATION','FRIENDLY','RCS','NCTR'}
for i = 1, 128 do
    contacts[i] = {}
    for _, field in ipairs(fields) do
        contacts[i][field] = get_param_handle(string.format('RADAR_CONTACT_%02d_', i) .. field)
    end
end
local mode = get_param_handle('RADAR_MODE')
local stt_range = get_param_handle('RADAR_STT_RANGE')
make_default_activity(0.1)
need_to_be_closed = false
local function report(s)
    log.write('F4_SIMPLE_CONTACTS', log.INFO, s)
end
function post_initialize()
    report('POST_INITIALIZE; default-performance receive test; no lock commands')
    local ok, err = pcall(function() dev:set_power(true) end)
    report('set_power call=' .. tostring(ok) .. ' ' .. tostring(err))
end
function update()
    ticks = ticks + 1
    -- Bounded logging: every five simulated seconds for the first three minutes.
    if ticks % 50 ~= 0 or ticks > 1800 then return end
    local count, fresh, shown = 0, 0, 0
    for i = 1, 128 do
        local c = contacts[i]
        local range, age = c.RANGE:get(), c.TIME:get()
        if type(range) == 'number' and range > 0 then
            count = count + 1
            if type(age) == 'number' and age >= 0 and age <= 5 then fresh = fresh + 1 end
            if shown < 6 then
                shown = shown + 1
                local values = {'slot=' .. tostring(i)}
                for _, field in ipairs(fields) do
                    values[#values + 1] = field .. '=' .. tostring(c[field]:get())
                end
                report(table.concat(values, ' '))
            end
        end
    end
    report('SNAPSHOT ticks=' .. tostring(ticks) .. ' mode=' .. tostring(mode:get()) ..
        ' nonzero_slots=' .. tostring(count) .. ' age_le5_slots=' .. tostring(fresh) ..
        ' STT_RANGE=' .. tostring(stt_range:get()) .. '; returns are not unique aircraft')
end
