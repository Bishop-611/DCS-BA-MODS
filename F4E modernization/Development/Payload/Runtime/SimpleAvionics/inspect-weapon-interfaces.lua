-- Read-only Lua surface inspection; never invoke discovered functions.
return function()
    local function report(s) log.write('F4_SIMPLE_BRIDGE', log.INFO, s) end
    for _, entry in ipairs({{27,'F4_WEAPONS'},{52,'F4_RADAR'},{201,'SIMPLE_RADAR'}}) do
        local ok, device = pcall(GetDevice, entry[1])
        if not ok or device == nil then
            report(entry[2] .. ' unavailable; object query success=' .. tostring(ok))
        else
            local names, seen = {}, {}
            local function collect(t, prefix)
                if type(t) ~= 'table' then return end
                for key, value in pairs(t) do
                    if type(key) == 'string' and type(value) == 'function' then
                        local name = prefix .. key
                        if not seen[name] and #names < 160 then
                            seen[name] = true
                            names[#names + 1] = name
                        end
                    end
                end
            end
            collect(device, 'object.')
            local meta_ok, meta = pcall(getmetatable, device)
            if meta_ok and type(meta) == 'table' then
                collect(meta, 'meta.')
                collect(rawget(meta, '__index'), 'methods.')
            end
            table.sort(names)
            report(entry[2] .. ' accessible type=' .. type(device) .. ' visible_functions=' .. tostring(#names))
            for _, name in ipairs(names) do report(entry[2] .. ' ' .. name) end
        end
    end
    report('COMPLETE; object/method visibility does not prove target transfer or AIM-7 guidance')
end
