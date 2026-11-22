-- F4 Modern Receiver: add with a Mission Editor DO SCRIPT FILE trigger, offline only.
-- Mission-authorized simulation data. This is not an upgrade to Heatblur's native receiver.
if F4ModernReceiver then return end
F4ModernReceiver = { missiles = {}, sequence = 0, nextScan = 0, emitters = {}, dropped = 0 }
local R = F4ModernReceiver
local NM = 1852
local cfg = { radarRange = 250*NM, missileRange = 60*NM, aircraftRange = 20*NM, limit = 64 }
local database = {
    RPC_5N62V = { symbol = '5', name = 'SA-5 SQUARE PAIR', range = 400000 },
    RLS_19J6 = { symbol = 'TS', name = 'TIN SHIELD SEARCH', range = 150000 },
}
local function call(object, method, ...)
    if not object then return nil end
    local args = {...}
    local ok, a, b = pcall(function() return object[method](object, unpack(args)) end)
    if ok then return a, b end
end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<1e12 end
local function vector(p) return type(p)=='table' and finite(p.x) and finite(p.y) and finite(p.z) end
local function distance(a,b)
    local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
    return math.sqrt(x*x+y*y+z*z)
end
local function quote(s)
    return '"'..tostring(s or ''):gsub('[%z\1-\31\\"]', function(c)
        if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' else return ' ' end
    end)..'"'
end
local function vec(p) return string.format('{"x":%.3f,"y":%.3f,"z":%.3f}',p.x,p.y,p.z) end
local function player()
    local selected,count=nil,0
    for _,side in ipairs({coalition.side.BLUE,coalition.side.RED,coalition.side.NEUTRAL}) do
        for _,u in ipairs(coalition.getPlayers(side) or {}) do
            if call(u,'isExist') and call(u,'getPlayerName') then selected=u;count=count+1 end
        end
    end
    if count==1 then return selected end
end
local function same(a,b)
    return a and b and call(a,'getID') ~= nil and call(a,'getID') == call(b,'getID')
end
local function visible(a,b)
    if not land or type(land.isVisible)~='function' then return false end
    local ok,result=pcall(land.isVisible,{x=a.x,y=a.y+3,z=a.z},{x=b.x,y=b.y+2,z=b.z})
    return ok and result==true
end
local function groupName(u)
    return call(call(u,'getGroup'),'getName')
end
local function scan(own,origin)
    local list={}
    for _,side in ipairs({coalition.side.BLUE,coalition.side.RED,coalition.side.NEUTRAL}) do
        if side~=call(own,'getCoalition') then
            for _,category in ipairs({Group.Category.AIRPLANE,Group.Category.HELICOPTER,Group.Category.GROUND,Group.Category.SHIP}) do
                for _,g in ipairs(coalition.getGroups(side,category) or {}) do
                    for _,u in ipairs(call(g,'getUnits') or {}) do
                        if call(u,'isExist') then
                            local active,target=call(u,'getRadar')
                            local p=call(u,'getPoint')
                            if active==true and vector(p) then
                                local typeName=call(u,'getTypeName') or ''
                                local entry=database[typeName]
                                local range=entry and entry.range or cfg.radarRange
                                local d=distance(p,origin)
                                if d<=range and visible(origin,p) then
                                    list[#list+1]={id=tostring(call(u,'getID')),p=p,distance=d,
                                        symbol=entry and entry.symbol or 'U',
                                        type=typeName,name=entry and entry.name or typeName,
                                        mode=same(target,own) and 'TRACK' or 'EMITTER',
                                        group=groupName(u)}
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(list,function(a,b)
        if a.mode~=b.mode then return a.mode=='TRACK' end
        return a.distance<b.distance
    end)
    R.emitters=list
end
function R:onEvent(event)
    if event.id~=world.event.S_EVENT_SHOT or not event.weapon then return end
    local desc=call(event.weapon,'getDesc')
    if type(desc)~='table' or desc.category~=Weapon.Category.MISSILE then return end
    local key=tostring(call(event.weapon,'getID') or event.weapon)
    local count=0;for _ in pairs(self.missiles) do count=count+1 end
    if count>=1024 then self.dropped=self.dropped+1;return end
    self.missiles[key]={object=event.weapon,launcher=event.initiator,
        group=groupName(event.initiator),born=event.time or timer.getTime(),guidance=desc.guidance,
        type=call(event.weapon,'getTypeName') or 'MISSILE'}
end
local function frame(now)
    local own=player()
    local origin=call(own,'getPoint')
    if not own or not vector(origin) then return '{"state":"NO_PLAYER","emitters":[],"missiles":[]}' end
    if now>=R.nextScan then scan(own,origin);R.nextScan=now+1 end
    local missiles,launchGroups={},{}
    for key,m in pairs(R.missiles) do
        if not call(m.object,'isExist') or now-m.born>1800 then R.missiles[key]=nil
        else
            local p=call(m.object,'getPoint')
            local inbound=same(call(m.object,'getTarget'),own)
            local radarGuided=m.guidance==Weapon.GuidanceType.RADAR_ACTIVE or m.guidance==Weapon.GuidanceType.RADAR_SEMI_ACTIVE
            if inbound and radarGuided and m.group then launchGroups[m.group]=true end
            if vector(p) and distance(origin,p)<=cfg.missileRange then
                local launcherSide=call(m.launcher,'getCoalition')
                local identity=launcherSide and (launcherSide==call(own,'getCoalition') and 'FRIENDLY' or 'HOSTILE') or 'UNKNOWN'
                missiles[#missiles+1]={id=key,p=p,distance=distance(origin,p),inbound=inbound,own_launch=same(m.launcher,own),identity=identity,type=m.type}
            end
        end
    end
    table.sort(missiles,function(a,b)
        if a.inbound~=b.inbound then return a.inbound end
        return a.distance<b.distance
    end)
    local es,ms={},{}
    for i=1,math.min(#R.emitters,cfg.limit) do
        local e=R.emitters[i]
        local mode=launchGroups[e.group] and 'LAUNCH' or e.mode
        es[#es+1]='{"id":'..quote(e.id)..',"p":'..vec(e.p)..',"symbol":'..quote(e.symbol)..',"type":'..quote(e.type)..',"name":'..quote(e.name)..',"mode":'..quote(mode)..'}'
    end
    for i=1,math.min(#missiles,cfg.limit) do
        local m=missiles[i]
        ms[#ms+1]='{"id":'..quote(m.id)..',"p":'..vec(m.p)..',"identity":'..quote(m.identity)..',"inbound":'..tostring(m.inbound)..',"own_launch":'..tostring(m.own_launch)..',"type":'..quote(m.type)..'}'
    end
    local pose=call(own,'getPosition')
    local heading=type(pose)=='table' and vector(pose.x) and math.atan2(pose.x.z,pose.x.x) or nil
    return '{"state":"SIM_RECEIVER","sequence":'..(R.sequence+1)..',"sample_time":'..now..',"ownship":'..vec(origin)..',"own_heading":'..(heading and string.format('%.8f',heading) or 'null')..',"emitters":['..table.concat(es,',')..'],"missiles":['..table.concat(ms,',')..'],"dropped":'..R.dropped..'}'
end
local function tick(_,now)
    local ok,data=pcall(frame,now)
    if ok then
        R.sequence=R.sequence+1
        env.info('F4MODERN_V1|'..data)
    else env.info('F4MODERN_ERROR|'..tostring(data)) end
    return now+(1/30)
end
world.addEventHandler(R)
timer.scheduleFunction(tick,{},timer.getTime()+1)
env.info('F4MODERN_READY|offline mission companion; active radars + post-load missile events')
