local root=[[__F4_RUNTIME__/HUD/]]
local model,profile,mathlib,display=dofile(root..'dlz-model.lua'),dofile(root..'aim7-profile.lua'),dofile(root..'flight_math.lua'),dofile(root..'weapon_math.lua')
local params={}
local function get(n) return get_param_handle(n):get() end
local function set(n,v)
    if not params[n] then params[n]=get_param_handle('F4MH_'..n) end
    params[n]:set(v)
end
local previous,relative_velocity,samples,last_solution,last_compute=nil,nil,0,nil,-10
local job=nil
local function reset()
    previous=nil;relative_velocity=nil;samples=0;last_solution=nil;last_compute=-10;job=nil
end
return function(s)
    local ok,lamp=pcall(get_cockpit_draw_argument_value,279)
    local active=s.aa and not s.gun and ok and type(lamp)=='number' and lamp>.05
        and get('RADAR_MODE')==3 and get('RADAR_STT_RANGE')>0
    if not active or not(s.pitch and s.bank and s.heading and s.altitude and s.vx and s.vy and s.vz) then
        reset();set('DLZ_VALID',0);set('DLZ_INACTIVE',1);set('DLZ_TOF_VALID',0);return
    end
    local range,az,el=get('RADAR_STT_RANGE'),get('RADAR_STT_AZIMUTH'),get('RADAR_STT_ELEVATION')
    local u,r=math.tan(el),math.tan(az)
    local norm=math.sqrt(1+u*u+r*r)
    local x,y,z=mathlib.world(range/norm,range*u/norm,range*r/norm,s.pitch,s.bank,s.heading)
    local dt=previous and s.time-previous.time or nil
    if dt and (dt<=0 or dt>.5) then reset();dt=nil end
    if not dt or dt>=.195 then
        if dt then
            local v={x=(x-previous.x)/dt,y=(y-previous.y)/dt,z=(z-previous.z)/dt}
            if v.x*v.x+v.y*v.y+v.z*v.z>1500^2 then reset()
            else
                if relative_velocity then local k=dt/(.4+dt);for key,value in pairs(v) do relative_velocity[key]=relative_velocity[key]+k*(value-relative_velocity[key]) end
                else relative_velocity=v end
                samples=samples+1
            end
        end
        previous={time=s.time,x=x,y=y,z=z}
    end
    if relative_velocity and samples>=3 and not job and s.time-last_compute>=1 then
        last_compute=s.time
        local ux,uy,uz=x/range,y/range,z/range
        local tvx,tvy,tvz=relative_velocity.x+s.vx,relative_velocity.y+s.vy,relative_velocity.z+s.vz
        local radial=tvx*ux+tvy*uy+tvz*uz
        local target_speed2=tvx*tvx+tvy*tvy+tvz*tvz
        local lateral=math.sqrt(math.max(0,target_speed2-radial*radial))
        local own_speed=math.sqrt(s.vx*s.vx+s.vy*s.vy+s.vz*s.vz)
        local own_radial=s.vx*ux+s.vy*uy+s.vz*uz
        local launch_angle
        if lateral>1 then
            local own_lateral=(s.vx*(tvx-radial*ux)+s.vy*(tvy-radial*uy)+s.vz*(tvz-radial*uz))/lateral
            launch_angle=math.atan2(own_lateral,own_radial)
        else launch_angle=math.acos(math.max(-1,math.min(1,own_radial/math.max(own_speed,1)))) end
        local input={speed=own_speed,altitude=s.altitude,target_altitude=s.altitude+y,
            target_radial=radial,target_lateral=lateral,range=range,launch_angle=launch_angle,climb_sine=uy}
        job=coroutine.create(function() return model.solve(input,profile,coroutine.yield) end)
    end
    if job then
        -- One trajectory per HUD update; do not block a frame on the full envelope search.
        local ok,result=coroutine.resume(job)
        if not ok then job=nil;last_solution=nil
        elseif coroutine.status(job)=='dead' then
            last_solution=result;job=nil
            if type(log)=='table' then log.write('F4_DLZ_MODEL',log.INFO,'profile='..profile.name..' Rmin='..tostring(result and result.rmin)..' Rpi='..tostring(result and result.rpi)..' Rtr='..tostring(result and result.rtr)) end
        end
    end
    local solution=last_solution
    local dlz=solution and display.dlz(solution.rmin/1852,solution.rpi/1852,solution.rtr and solution.rtr/1852 or nil,range/1852)
    set('DLZ_VALID',dlz and 1 or 0);set('DLZ_INACTIVE',dlz and 0 or 1)
    set('DLZ_TOF_VALID',solution and solution.tof and 1 or 0);set('DLZ_TOF',solution and solution.tof or 0)
    if dlz then
        local function slot(v) return math.floor(v+92+.5) end
        set('DLZ_MIN_SLOT',slot(dlz.minimum));set('DLZ_MAX_SLOT',slot(dlz.maximum))
        set('DLZ_MIN_OFFSET',dlz.minimum+92);set('DLZ_MAX_OFFSET',dlz.maximum+92)
        set('DLZ_R2_OFFSET',dlz.secondary and dlz.secondary+92 or 0);set('DLZ_TARGET_OFFSET',dlz.target+92)
        set('DLZ_R2_SLOT',dlz.secondary and slot(dlz.secondary) or -1);set('DLZ_R2_VALID',dlz.secondary and 1 or 0)
        set('DLZ_TARGET_SLOT',slot(dlz.target));set('DLZ_SCALE',dlz.scale);set('DLZ_RANGE',dlz.range)
    end
end
