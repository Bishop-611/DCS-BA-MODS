local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e12 end
local function vector(v) return type(v)=='table' and finite(v.x) and finite(v.y) and finite(v.z) end
local function weapon_type(station)
    local t=station and station.weapon
    if type(t)~='table' then return nil end
    local out={}
    for i=1,4 do out[i]=t['level'..i] or t[i];if not finite(out[i]) then return nil end end
    return out
end
local function excluded(name)
    local n=type(name)=='string' and name:upper():gsub('[^%w]','') or ''
    return n:find('AGM45',1,true) or n:find('AGM88',1,true) or n:find('AGM122',1,true)
        or n:find('AGM65',1,true) or n:find('AGM62',1,true) or n:find('WALLEYE',1,true) or n:find('GBU15',1,true)
end
function M.capture(api)
    local function call(n,...) if type(api[n])~='function' then return nil end;local ok,v=pcall(api[n],...);if ok then return v end end
    if call('LoIsOwnshipExportAllowed')~=true then return nil,'EXPORT_BLOCKED' end
    local own,velocity,wind,payload=call('LoGetSelfData'),call('LoGetVectorVelocity'),call('LoGetVectorWindVelocity'),call('LoGetPayloadInfo')
    local panel=call('GetDevice',0)
    local function draw(n)
        if not panel then return nil end
        local ok,v=pcall(function() return panel:get_argument_value(n) end)
        return ok and finite(v) and v or nil
    end
    local knob=draw(273)
    -- F-4 ARM and TV selector positions: both animation and input-normalized ranges.
    if type(own)~='table' or own.Name~='F-4E-45MC' then return nil,'OTHER_AIRCRAFT' end
    if not vector(own.Position) or not vector(velocity) or not vector(wind) then return nil,'NO_FLIGHT_DATA' end
    if type(payload)~='table' or type(payload.Stations)~='table' then return nil,'NO_PAYLOAD' end
    local remaining=0
    for _,station in pairs(payload.Stations) do
        if type(station)=='table' and finite(station.count) and station.count>0 then
            local t=weapon_type(station)
            if not t then return nil,'BAD_PAYLOAD' end
            -- Count all actual ordnance, including A/A missiles. Fuel tanks are not ordnance.
            if t[1]==4 and (t[2]==4 or t[2]==5 or t[2]==6 or t[2]==7) then remaining=remaining+station.count end
        end
    end
    local function result(name,station,code,selection)
        local arming=draw(1221)
        local tailArmed=arming and (math.floor(arming*4+.5)==2 or math.floor(arming*4+.5)==3) or false
        return {origin=own.Position,velocity=velocity,wind=wind,pitch=own.Pitch,bank=own.Bank,heading=own.Heading,
            name=name,aircraft=own.Name,station=station,code=code,remaining=remaining,selection=selection,tailArmed=tailArmed,arming=arming},'OK'
    end
    local function gun(reason)
        local shells=type(payload.Cannon)=='table' and payload.Cannon.shells
        if not finite(shells) or shells<=0 then return nil,'EMPTY' end
        return result('M61A1',0,2,reason)
    end
    local name,station,code,selection
    if remaining==0 then
        return gun('GUN_ONLY')
    else
        if knob and ((knob>=.10 and knob<=.17) or (knob>=.24 and knob<=.30)) then return nil,'EXCLUDED_WEAPON' end
        station=payload.CurrentStation
        if not finite(station) or station<=0 or station~=math.floor(station) then
            -- Full-fidelity F-4 can export CurrentStation=0 while its native panel has armed stores.
            -- Pylon 1/3/7/11/13 mapping verified in CoreMods F-4E Entry/F-4E.lua.
            local bombs=knob and knob>=.87
            local rockets=knob and (knob<=.03 or (knob>=.60 and knob<=.73))
            local bullpup=knob and knob>=.74 and knob<.87
            if not knob then return nil,'SELECTION_UNAVAILABLE' end
            if not(bombs or rockets or bullpup) then return gun('GUN_NO_SELECTION') end
            station=nil
            local chosen_type,mixed=nil,false
            local details={}
            -- Upper green Button_Lit means selected; lower amber Arm_Lit means ready.
            for _,entry in ipairs({{1,256},{2,257},{3,257},{4,257},{7,258},{10,259},{11,259},{12,259},{13,260}}) do
                local light=draw(entry[2]);local candidate=payload.Stations[entry[1]]
                local wt=weapon_type(candidate)
                local candidate_name=wt and call('LoGetNameByType',unpack(wt))
                local normalized=type(candidate_name)=='string' and candidate_name:upper():gsub('[^%w]','') or ''
                local compatible=wt and ((bombs and wt[2]==5) or (rockets and (wt[2]==7 or (wt[2]==5 and normalized:find('CBU',1,true))))
                    or (bullpup and wt[2]==4 and normalized:find('AGM12',1,true)))
                if light and light>.05 and wt and wt[1]==4 and compatible and not excluded(candidate_name) and finite(candidate.count) and candidate.count>0 then
                    local key=table.concat(wt,':')
                    details[#details+1]='pylon='..entry[1]..',name='..tostring(call('LoGetNameByType',unpack(wt)))..',type='..key
                    if chosen_type and chosen_type~=key then mixed=true end
                    chosen_type=key;station=station and station>0 and station or entry[1]
                end
            end
            if mixed then return nil,'AMBIGUOUS_SELECTION',table.concat(details,';') end
            if not chosen_type then return gun('GUN_NO_SELECTION') end
            selection=bombs and 'F4_SELECTED_BOMB_STATIONS' or (rockets and 'F4_SELECTED_ROCKET_STATIONS' or 'F4_SELECTED_AG_STATIONS')
        else selection='CURRENT_STATION' end
        local selected=payload.Stations[station];local wt=weapon_type(selected)
        if not wt or not finite(selected.count) or selected.count<=0 then return gun('GUN_EMPTY_SELECTION') end
        name=call('LoGetNameByType',unpack(wt))
        if type(name)~='string' or name=='' then return nil,'UNKNOWN_WEAPON' end
        if excluded(name) then return nil,'EXCLUDED_WEAPON' end
        code=1
    end
    return result(name,station,code,selection)
end
return M
