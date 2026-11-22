-- Live aircraft markers from the standard DCS Export API.
-- No process-memory access. Missing export permission fails closed.
if F4RwrLinkBridgeLoaded then return end
F4RwrLinkBridgeLoaded=true
local okActivity,isActive=pcall(dofile,lfs.writedir()..'Scripts/F4RwrLink/FoxBridgeActivity.lua')
if not okActivity or type(isActive)~='function' then isActive=function() return false end end
local wasActive=false
local output,last,sequence=nil,-1,0
local worldLast,cachedTracks,cachedOwnAllowed,cachedObjectsAllowed=-1,{},nil,nil
local diagSeen,diagSamples,diagCount={},{},0
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<1e12 end
local function vector(v) return type(v)=='table' and finite(v.x) and finite(v.y) and finite(v.z) end
local function vec(v) return string.format('{"x":%.6f,"y":%.6f,"z":%.6f}',v.x,v.y,v.z) end
local function call(name,...)
    if type(_G[name])~='function' then return nil end
    local ok,value=pcall(_G[name],...);if ok then return value end
end
local allowed,coalition,diagnoseWorldObjects
local function publishExportMissiles(own,units)
    local state,items='BLOCKED',{}
    if allowed('LoIsOwnshipExportAllowed') and allowed('LoIsObjectExportAllowed') and type(own)=='table' and vector(own.Position) then
        local ballistic=call('LoGetWorldObjects','ballistic')
        state=(type(units)=='table' or type(ballistic)=='table') and 'LIVE' or 'UNAVAILABLE'
        local seen={}
        for _,list in ipairs({type(units)=='table' and units or {},type(ballistic)=='table' and ballistic or {}}) do
            for id,o in pairs(list) do
                if type(o)=='table' and type(o.Type)=='table' and not seen[tostring(id)] and #items<64 then
                    local t=o.Type
                    -- DCS wsTypes: weapon=4, missile=4; do not relabel bombs/shells as missiles.
                    if tonumber(t.level1 or t[1])==4 and tonumber(t.level2 or t[2])==4 and vector(o.Position) then
                        seen[tostring(id)]=true
                        local side,mySide=coalition(o),coalition(own)
                        local identity=side and mySide and (side==mySide and 'FRIENDLY' or 'HOSTILE') or 'UNKNOWN'
                        local name=''
                        if type(LoGetNameByType)=='function' then
                            local ok,n=pcall(LoGetNameByType,t.level1 or t[1],t.level2 or t[2],t.level3 or t[3],t.level4 or t[4])
                            if ok and type(n)=='string' then name=n end
                        end
                        local safeId=tostring(id):gsub('[^%w_%-]',''):sub(1,48)
                        name=name:gsub('[^%w _%-%.]',''):sub(1,96)
                        items[#items+1]='{"id":"'..safeId..'","identity":"'..identity..'","type":"'..name..'","age_s":0,"p":'..vec(o.Position)..'}'
                    end
                end
            end
        end
    end
    local ownPosition=type(own)=='table' and own.Position
    local ownJSON=allowed('LoIsOwnshipExportAllowed') and vector(ownPosition) and vec(ownPosition) or 'null'
    output:write('F4EXPORT_MISSILES_V1|{"state":"'..state..'","sequence":'..sequence..',"sample_time":'..tostring(last)..',"ownship":'..ownJSON..',"missiles":['..table.concat(items,',')..']}\n')
end
allowed=function(name) return call(name)==true end
coalition=function(o)
    if type(o)~='table' then return nil end
    local id=tonumber(o.CoalitionID)
    if id==1 or id==2 then return id end
    return nil
end
-- Independent native receiver stream: never infer radar activity from world positions.
local function quoted(value)
    return '"'..tostring(value or ''):gsub('[%z\1-\31\\"]',' '):sub(1,96)..'"'
end
diagnoseWorldObjects=function(objects,source)
    if type(objects)~='table' or diagCount>=256 then return end
    local firstSeen=0
    for _,_ in pairs(diagSeen) do firstSeen=firstSeen+1 end
    for id,o in pairs(objects) do
        if diagCount>=256 then break end
        if type(o)=='table' and type(o.Type)=='table' then
            local key=tostring(id)..':'..source
            local kind=o.Type;local l1=tonumber(kind.level1 or kind[1]);local l2=tonumber(kind.level2 or kind[2])
            local candidate=l1==4 or (l1==1 and l2~=1 and l2~=2)
            local new=not diagSeen[key] and firstSeen<128
            local sample=diagSamples[key] or {count=0,time=-1}
            local trajectory=candidate and sample.count<12 and last-sample.time>=0.5
            if new or trajectory then
                local fields={};local count=0
                for k,v in pairs(kind) do
                    if finite(v) and count<16 then fields[#fields+1]=quoted(k)..':'..tostring(v);count=count+1 end
                end
                local velocity=o.Velocity or o.velocity
                output:write('F4WORLD_DIAG_V1|{"sample_time":'..tostring(last)..',"id":'..quoted(id)..',"list":'..quoted(source)..',"name_raw":'..quoted(o.Name)..',"type_raw":{'..table.concat(fields,',')..'},"coalition":'..quoted(o.CoalitionID or o.Coalition)..',"position":'..(vector(o.Position) and vec(o.Position) or 'null')..',"velocity":'..(vector(velocity) and vec(velocity) or 'null')..',"classification":"unconfirmed","first_seen":'..tostring(new)..'}\n')
                if new then diagSeen[key]=true;firstSeen=firstSeen+1 end
                sample.count=sample.count+1;sample.time=last;diagSamples[key]=sample;diagCount=diagCount+1
            end
        end
    end
end
local function publishNativeRwr()
    local state,contacts='BLOCKED',{}
    if allowed('LoIsOwnshipExportAllowed') and allowed('LoIsSensorExportAllowed') then
        local tws=call('LoGetTWSInfo')
        state='UNAVAILABLE'
        if type(tws)=='table' and type(tws.Emitters)=='table' then
            state='LIVE'
            for _,e in pairs(tws.Emitters) do
                if type(e)=='table' and #contacts<64 then
                    local name=''
                    local t=e.Type
                    if type(t)=='table' and type(LoGetNameByType)=='function' then
                        local ok,n=pcall(LoGetNameByType,t.level1 or t[1],t.level2 or t[2],t.level3 or t[3],t.level4 or t[4])
                        if ok and type(n)=='string' then name=n end
                    end
                    local az=finite(e.Azimuth) and math.abs(e.Azimuth)<=2*math.pi and string.format('%.8f',e.Azimuth) or 'null'
                    contacts[#contacts+1]='{"id":'..quoted(e.ID)..',"type_name":'..quoted(name)..',"azimuth":'..az..',"signal":'..quoted(e.SignalType)..'}'
                end
            end
        end
    end
    output:write('F4NATIVE_RWR_V1|{"state":"'..state..'","contacts":['..table.concat(contacts,',')..']}\n')
end
local function publish()
    if not output then return end
    if not isActive() then wasActive=false;return end
    if not wasActive then worldLast=-1;cachedTracks={};wasActive=true end
    local now=call('LoGetModelTime')
    -- Camera/ownship at up to 60 Hz; world discovery and threats at up to 10 Hz.
    if not finite(now) or (now>=last and now-last<(1/60-0.0001)) then return end
    last=now;sequence=sequence+1
    local ownAllowed=allowed('LoIsOwnshipExportAllowed')
    local objectsAllowed=allowed('LoIsObjectExportAllowed')
    local scan=now<worldLast or worldLast<0 or now-worldLast>=0.0999 or ownAllowed~=cachedOwnAllowed or objectsAllowed~=cachedObjectsAllowed
    local camera,own
    if ownAllowed then camera=call('LoGetCameraPosition');own=call('LoGetSelfData') end
    local cameraJSON='null'
    if type(camera)=='table' and vector(camera.p) and vector(camera.x) and vector(camera.y) and vector(camera.z) then
        local projection=''
        local fov=FoxViewFovSample
        if type(fov)=='table' and finite(fov.degrees) and fov.degrees>1 and fov.degrees<179 and finite(fov.time) and now>=fov.time and now-fov.time<=0.25 then
            projection=string.format(',"projection":{"hfov_deg":%.9f}',fov.degrees)
        end
        cameraJSON='{"p":'..vec(camera.p)..',"forward":'..vec(camera.x)..',"up":'..vec(camera.y)..',"right":'..vec(camera.z)..projection..'}'
    end
    local origin=type(own)=='table' and own.Position
    local ownJSON=vector(origin) and vec(origin) or 'null'
    local function flightNumber(name)
        local n=ownAllowed and call(name) or nil
        return finite(n) and string.format('%.6f',n) or 'null'
    end
    local accel=ownAllowed and call('LoGetAccelerationUnits') or nil
    local gy=type(accel)=='table' and accel.y
    local flightJSON='{"ias":'..flightNumber('LoGetIndicatedAirSpeed')..',"altitude":'..flightNumber('LoGetAltitudeAboveSeaLevel')..',"agl":'..flightNumber('LoGetAltitudeAboveGroundLevel')..',"aoa":'..flightNumber('LoGetAngleOfAttack')..',"mach":'..flightNumber('LoGetMachNumber')..',"g":'..(finite(gy) and string.format('%.6f',gy) or 'null')..'}'
    local ownHeading=type(own)=='table' and own.Heading
    local headingJSON=finite(ownHeading) and string.format('%.8f',ownHeading) or 'null'
    if sequence==1 then
        output:write('F4DIAG|own_permission_function='..type(LoIsOwnshipExportAllowed)..'|object_permission_function='..type(LoIsObjectExportAllowed)..'|own_allowed='..tostring(ownAllowed)..'|objects_allowed='..tostring(objectsAllowed)..'|camera_type='..type(camera)..'|own_type='..type(own)..'|camera_valid='..tostring(cameraJSON~='null')..'|coalition='..tostring(type(own)=='table' and own.Coalition)..'|coalition_id='..tostring(type(own)=='table' and own.CoalitionID)..'\n')
        output:flush()
    end
    if sequence==1 then
        local sensorAllowed=allowed('LoIsSensorExportAllowed')
        local tws=sensorAllowed and call('LoGetTWSInfo') or nil
        local cameraKeys={}
        if type(camera)=='table' then for k in pairs(camera) do cameraKeys[#cameraKeys+1]=tostring(k) end end
        output:write('F4DIAG_CAPS|sensor_allowed='..tostring(sensorAllowed)..'|tws_type='..type(tws)..'|camera_keys='..table.concat(cameraKeys,',')..'\n')
        if type(tws)=='table' then
            local e=tws.Emitters
            output:write('F4DIAG_TWS|emitters_type='..type(e)..'|count='..tostring(type(e)=='table' and #e or -1)..'\n')
        end
        output:flush()
    end
    local tracks=cachedTracks
    local ownID=ownAllowed and call('LoGetPlayerPlaneId') or nil
    local myCoalition=coalition(own)
    local objects
    if scan then
    tracks={}
    publishNativeRwr()
    if ownAllowed and objectsAllowed and vector(origin) then
        objects=call('LoGetWorldObjects')
        if type(objects)=='table' then
            if sequence==1 then
                local counts={}
                for _,v in pairs(objects) do
                    if type(v)=='table' and type(v.Type)=='table' then
                        local key=tostring(v.Type.level1 or v.Type[1])..':'..tostring(v.Type.level2 or v.Type[2])
                        counts[key]=(counts[key] or 0)+1
                    end
                end
                local fields={};for key,count in pairs(counts) do fields[#fields+1]=key..'='..count end
                output:write('F4DIAG_OBJECT_TYPES|'..table.concat(fields,',')..'\n');output:flush()
            end
            if not myCoalition and ownID then myCoalition=coalition(objects[ownID] or objects[tostring(ownID)]) end
            local candidates={}
            for id,o in pairs(objects) do
                if type(o)=='table' and tostring(id)~=tostring(ownID) then
                    local kind=o.Type
                    local isAir=type(kind)=='table' and tonumber(kind.level1 or kind[1])==1 and
                        (tonumber(kind.level2 or kind[2])==1 or tonumber(kind.level2 or kind[2])==2)
                    local other=coalition(o)
                    local p=o.Position
                    if isAir and other and myCoalition and vector(p) then
                        local dx,dy,dz=p.x-origin.x,p.y-origin.y,p.z-origin.z
                        local distance=dx*dx+dy*dy+dz*dz
                        if distance>1 then candidates[#candidates+1]={id=id,p=p,side=other,distance=distance,model=o.Name} end
                    end
                end
            end
            table.sort(candidates,function(a,b)return a.distance<b.distance end)
            for i=1,math.min(#candidates,32) do
                local c=candidates[i]
                local id=tostring(c.id):gsub('[^%w_%-]',''):sub(1,24)
                local identity=c.side==myCoalition and 'FRIENDLY' or 'HOSTILE'
                tracks[#tracks+1]='{"id":"'..id..'","identity":"'..identity..'","aircraft_type":'..quoted(c.model)..',"source":"world_export","age_s":0,"p":'..vec(c.p)..'}'
            end
        end
    end
    publishExportMissiles(own,objects)
    worldLast=now;cachedTracks=tracks;cachedOwnAllowed=ownAllowed;cachedObjectsAllowed=objectsAllowed
    end
    -- Preserve the actual observation age while reusing the last world snapshot.
    local state=not ownAllowed and 'OWN_EXPORT_BLOCKED' or (not objectsAllowed and 'OBJECT_EXPORT_BLOCKED' or (#tracks==0 and 'NO_AIRCRAFT' or 'LIVE_POSITIONS'))
    local snapshot='{"sequence":'..sequence..',"state":"'..state..'","camera":'..cameraJSON..',"ownship":'..ownJSON..',"flight":'..flightJSON..',"own_heading":'..headingJSON..',"own_unit_name":'..quoted(ownAllowed and type(own)=='table' and own.UnitName or '')..',"own_unit_id":'..(finite(ownID) and tostring(ownID) or 'null')
    if scan then output:write('F4DL_V1|'..snapshot..',"tracks":['..table.concat(tracks,',')..']}\n') end
    output:write('F4CAM_V1|'..snapshot..'}\n')
    output:flush()
end
local previousStart=LuaExportStart
LuaExportStart=function(...)
    if previousStart then previousStart(...) end
    local root=lfs and lfs.writedir and lfs.writedir()
    if type(root)~='string' or root:lower():find('onedrive',1,true) then return end
    output=io.open(root..'Logs/F4RwrLink.log','w');last=-1;sequence=0
    worldLast=-1;cachedTracks={};cachedOwnAllowed=nil;cachedObjectsAllowed=nil
    wasActive=false
    diagSeen,diagSamples,diagCount={},{},0

end
local previousFrame=LuaExportAfterNextFrame
LuaExportAfterNextFrame=function(...)
    if previousFrame then previousFrame(...) end
    local ok,err=pcall(publish)
    if not ok and output then output:write('F4DIAG_ERROR|'..tostring(err)..'\n');output:flush() end
end
local previousStop=LuaExportStop
LuaExportStop=function(...)
    if output then output:close();output=nil end
    if previousStop then previousStop(...) end
end
