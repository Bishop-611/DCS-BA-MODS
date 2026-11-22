-- Independent extension using Heatblur's public Jester API; no world queries.
local Class = require 'base.Class'
local Behavior = require 'base.Behavior'
local Urge = require 'base.Urge'
local StressReaction = require 'base.StressReaction'
local Probe = Class(Behavior)
local function writeLine(line)
    if type(io) ~= 'table' or type(io.open) ~= 'function' then return end
    local ok, f = pcall(io.open, [[__FOX_PROBE_LOG__]], 'a')
    if ok and f then pcall(function() f:write(line .. '\n'); f:close() end) end
end

local function field(v)
    return tostring(v or ''):gsub('[^%w _%-%.]', ''):sub(1,48)
end
local Labels = require 'base.Labels'
local Utilities = require 'base.Utilities'
local function numeric(value, unit)
    if type(value)=='number' then
        if value==value and math.abs(value)<1e12 then return value end
        return nil
    end
    local ok,result=pcall(function() return value:ConvertTo(unit).value end)
    if ok and type(result)=='number' and result==result and math.abs(result)<1e12 then return result end
end
local function has(contact,label)
    local ok,result=pcall(function() return contact:Is(label) end)
    return ok and result==true
end
local function publishMissiles(sequence)
    local state,items,total,stale,bad='UNAVAILABLE',{},0,0,0
    local ok,contacts=pcall(function() return GetJester().awareness:GetContacts() end)
    if ok and type(contacts)=='table' then
        state='AWARENESS'
        local now=numeric(Utilities.GetTime().mission_time,s)
        for _,contact in pairs(contacts) do
            if has(contact,Labels.missile) and not has(contact,Labels.dead) then
                total=total+1
                local stamp=numeric(contact.last_seen_time_stamp,s)
                local age=now and stamp and now-stamp
                if not age or age<0 or age>1.5 then stale=stale+1
                else
                    local vector=contact.position_ned
                    local x=vector and numeric(vector.x,m)
                    local y=vector and numeric(vector.y,m)
                    local z=vector and numeric(vector.z,m)
                    if not x or not y or not z then bad=bad+1
                    elseif #items<64 then
                        local identity=has(contact,Labels.friendly) and 'FRIENDLY' or (has(contact,Labels.hostile) and 'HOSTILE' or 'UNKNOWN')
                        local id=field(contact.true_id)
                        -- NED is relative to ownship: north/east/down, not a world position.
                        items[#items+1]=string.format('{"id":"%s","identity":"%s","age_s":%.3f,"ned":{"x":%.3f,"y":%.3f,"z":%.3f}}',id,identity,age,x,y,z)
                    end
                end
            end
        end
    end
    writeLine('F4JESTER_MISSILES_V1|{"state":"'..state..'","sequence":'..sequence..',"total":'..total..',"stale":'..stale..',"invalid":'..bad..',"missiles":['..table.concat(items,',')..']}')
end
local function publishRwrContacts(sequence)
    local items={}
    local state=rwr_bit_test and 'TEST' or (type(rwr_contacts)=='table' and 'LIVE' or 'UNAVAILABLE')
    if state=='LIVE' then
        for key,c in pairs(rwr_contacts) do
            if type(c)=='table' and #items<64 then
                if sequence%10==1 and #items<4 then
                    local fields={}
                    for k,v in pairs(c) do
                        if type(v)=='number' or type(v)=='string' or type(v)=='boolean' then
                            fields[#fields+1]=field(k)..'='..field(v)
                        elseif type(v)=='table' then
                            for sub,n in pairs(v) do
                                if type(n)=='number' or type(n)=='string' then fields[#fields+1]=field(k)..'.'..field(sub)..'='..field(n) end
                                if #fields>=40 then break end
                            end
                        end
                        if #fields>=40 then break end
                    end
                    table.sort(fields)
                    writeLine('F4RWR_RAW|'..field(c.id or key)..'|'..table.concat(fields,'|'):sub(1,2048))
                end
                local hour=tonumber(c.hour) or 0
                if hour<1 or hour>12 then hour=0 end
                items[#items+1]=string.format('{"id":"%s","hour":%d,"activity":"%s","category":"%s","type1":"%s","type2":"%s","symbol1":"%s","symbol2":"%s"}',field(c.id or key),math.floor(hour),field(c.activity),field(c.category_1),field(c.type_1),field(c.type_2),field(c.symbol_1 or c.symbol1),field(c.symbol_2 or c.symbol2))
            end
        end
    end
    writeLine('F4RWR_CONTACTS_V1|{"state":"'..state..'","contacts":['..table.concat(items,',')..']}')
end
function Probe:Constructor()
    Behavior.Constructor(self)
    self.sequence = 0
    local publish = function()
        self.sequence = self.sequence + 1
        pcall(publishRwrContacts,self.sequence)
        local ok,err=pcall(publishMissiles,self.sequence)
        if not ok then writeLine('F4JESTER_MISSILES_ERROR|'..field(err)) end
        local mode, chosen = 'UNAVAILABLE', nil
        if rwr_bit_test then mode = 'TEST'
        elseif type(rwr_contacts) == 'table' then
            mode = 'CLEAR'
            for _, c in pairs(rwr_contacts) do
                if type(c) == 'table' and not c.known_friendly then
                    local friendly = false
                    for _, symbol in ipairs(rwr_symbols_friendly_only or {}) do
                        if symbol == c.symbol_1 or symbol == c.symbol_2 or
                            symbol == c.symbol1 or symbol == c.symbol2 then friendly = true end
                    end
                    if not friendly and (not chosen or
                        (c.activity == 'launch' and chosen.activity ~= 'launch')) then chosen = c end
                end
            end
            if chosen then mode = chosen.activity == 'launch' and 'LAUNCH' or 'CONTACT' end
        end
        local hour = chosen and tonumber(chosen.hour) or 0
        if not hour or hour < 1 or hour > 12 then hour = 0 end
        writeLine('F4RWR_V1|' .. self.sequence .. '|' .. mode .. '|' .. math.floor(hour)
            .. '|' .. field(chosen and chosen.activity) .. '|' .. field(chosen and chosen.category_1))
    end
    self.alert_timer = Urge:new({time_to_release=s(0.5),
        stress_reaction=StressReaction.ignorance, on_release_function=publish})
    self.alert_timer:Restart()
end
function Probe:Tick() self.alert_timer:Tick() end
Probe:Seal()
return Probe
