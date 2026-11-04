if F4SimpleCCIPLoaded then return end
F4SimpleCCIPLoaded=true
local root=[[__F4_RUNTIME__/HUD/CCIP/]]
local Inputs,Profiles,Solver=dofile(root..'inputs.lua'),dofile(root..'profiles.lua'),dofile(root..'solver.lua')
local seq,next_compute,job,job_input,job_time=0,-1,nil,nil,nil
local output,last_log,last_state=nil,-10,nil
local TerrainOK,Terrain=pcall(require,'terrain')
local cpu_clock=type(os)=='table' and type(os.clock)=='function' and os.clock or nil
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e12 end
local function call(n,...) if type(_G[n])=='function' then local ok,v=pcall(_G[n],...);if ok then return v end end end
local function report(state,input,bridge,now)
    local text='state='..state..' weapon='..tostring(input and input.name)..' station='..tostring(input and input.station)..' selection='..tostring(input and input.selection)..' bridge='..tostring(bridge)
    if text~=last_state or now-last_log>=5 then
        if not output and lfs and io then output=io.open(lfs.writedir()..'Logs/F4CCIP.log','a') end
        if output then output:write(string.format('t=%.3f %s\n',now,text));output:flush() end
        last_state=text;last_log=now
    end
end
local function publish(valid,time,impact,input,status,now,label)
    seq=seq+1
    local p=impact or {x=0,y=0,z=0,time=0}
    local v=input and input.velocity or {x=0,y=0,z=0}
    local values={valid,time,p.x,p.y,p.z,p.time,status,input and input.code or 0,input and input.station or 0,v.x,v.y,v.z}
    local ok,err=pcall(function()
        local dev=assert(GetDevice(205),'HUD device unavailable')
        dev:performClickableAction(3900,seq,false)
        for i,value in ipairs(values) do dev:performClickableAction(3900+i,value,false) end
        dev:performClickableAction(3913,seq,false)
    end)
    report(label or status,input,ok and 'OK' or tostring(err),now)
end
local function tick()
    local now=call('LoGetModelTime');if not finite(now) then return end
    if now<next_compute-2 then next_compute=-1;job=nil end
    local own=call('LoGetSelfData')
    if type(own)~='table' or own.Name~='F-4E-45MC' then job=nil;return end
    local panel=call('GetDevice',0)
    local ok,mode,tv=pcall(function() return panel:get_argument_value(271),panel:get_argument_value(2599) end)
    local ag=ok and finite(mode) and math.floor(mode/.1666+.5)==3
    if not ag then
        job=nil
        if now>=next_compute then next_compute=now+.2;publish(0,now,nil,nil,0,now) end
        return
    end
    if not job and now>=next_compute then
        next_compute=now+.05
        local input,reason,detail=Inputs.capture(_G)
        if not input then publish(0,now,nil,nil,reason=='EXCLUDED_WEAPON' and 8 or (reason=='AMBIGUOUS_SELECTION' and 7 or (reason=='NO_SELECTION' and 2 or 6)),now,reason..(detail and ' '..detail or ''));return end
        local profile=Profiles.select(input.name,input)
        if not profile then publish(0,now,nil,input,3,now,'UNSUPPORTED');return end
        input.code=profile.code
        if not(finite(input.pitch) and finite(input.bank) and finite(input.heading)) then publish(0,now,nil,input,6,now);return end
        local agl=call('LoGetAltitudeAboveGroundLevel')
        if not finite(agl) or agl<=0 then publish(0,now,nil,input,4,now);return end
        local ground=input.origin.y-agl
        local terrain
        for _,candidate in ipairs({TerrainOK and type(Terrain)=='table' and Terrain.GetHeight or false,type(LoGetAltitude)=='function' and LoGetAltitude or false}) do
            if type(candidate)=='function' then
                local good,height=pcall(candidate,input.origin.x,input.origin.z)
                if good and finite(height) and math.abs(height-ground)<15 then terrain=function(x,z)
                    local valid,h=pcall(candidate,x,z);return valid and finite(h) and h or nil
                end;break end
            end
        end
        if not terrain then publish(0,now,nil,input,4,now,'NO_VERIFIED_TERRAIN');return end
        local cp,sp,ch,sh,cb,sb=math.cos(input.pitch),math.sin(input.pitch),math.cos(input.heading),math.sin(input.heading),math.cos(input.bank),math.sin(input.bank)
        local bore=profile.bore or 0
        local dx=cp*ch*math.cos(bore)+(-sp*ch*cb-sh*sb)*math.sin(bore)
        local dy=sp*math.cos(bore)+cp*cb*math.sin(bore)
        local dz=cp*sh*math.cos(bore)+(-sp*sh*cb+ch*sb)*math.sin(bore)
        profile.direction={x=dx,y=dy,z=dz}
        local velocity={x=input.velocity.x+dx*(profile.muzzle or 0),y=input.velocity.y+dy*(profile.muzzle or 0),z=input.velocity.z+dz*(profile.muzzle or 0)}
        job_input,job_time=input,now;profile.yield_step=coroutine.yield
        job=coroutine.create(function() return Solver.solve(input.origin,velocity,profile,terrain,input.wind) end)
    end
    if job then
        -- Several short integration slices per frame; never run an entire long trajectory in one callback.
        local ok,result,reason
        local deadline=cpu_clock and cpu_clock()+.002 or nil
        for _=1,12 do
            ok,result,reason=coroutine.resume(job)
            if not ok or coroutine.status(job)=='dead' then break end
            if deadline and cpu_clock()>=deadline then break end
        end
        if not ok then publish(0,now,nil,job_input,6,now,'SOLVER_ERROR '..tostring(result));job=nil
        elseif coroutine.status(job)=='dead' then
            if result and now-job_time<=1 then publish(1,job_time,result,job_input,1,now)
            else publish(0,now,nil,job_input,4,now,reason or 'SOLVER_STALE') end
            job=nil
        end
    end
end
local previous_frame=LuaExportAfterNextFrame
LuaExportAfterNextFrame=function(...)
    if previous_frame then previous_frame(...) end
    local ok,err=pcall(tick)
    if not ok then report('ERROR '..tostring(err),nil,false,call('LoGetModelTime') or 0) end
end
local previous_stop=LuaExportStop
LuaExportStop=function(...)
    if output then output:close();output=nil end
    job=nil;next_compute=-1;last_log=-10;last_state=nil
    if previous_stop then previous_stop(...) end
end
