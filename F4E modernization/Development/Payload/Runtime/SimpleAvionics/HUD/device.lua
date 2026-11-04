local ccip=dofile('__F4_RUNTIME__/HUD/CCIP/device.lua')
local update_uncage=dofile('__F4_RUNTIME__/HUD/heat-auto-uncage.lua')
local alignment=dofile('__F4_RUNTIME__/HUD/alignment.lua')
local update_dlz=dofile('__F4_RUNTIME__/HUD/dlz-device.lua')
local update_gun=dofile('__F4_RUNTIME__/HUD/gun-device.lua')
local weaponMath=dofile('__F4_RUNTIME__/HUD/weapon_math.lua')
local mathlib=dofile('__F4_RUNTIME__/HUD/flight_math.lua')
local data=get_base_data()
local handles={}
local lastDiagnostic=nil
local lastHeatStatus,lastHeatLog,lastLOSLog=nil,-5,-5
local elapsed,lastPosition,lastFpmLog=0,nil,-5
local previousAttitude=nil
local funnelCounts={L=0,R=0}
local function vector(name)
    local ok,x,y,z=pcall(function() return data[name](data) end)
    if type(x)=='table' then local v=x;x,y,z=v.x or v[1],v.y or v[2],v.z or v[3] end
    if ok and mathlib.finite(x) and mathlib.finite(y) and mathlib.finite(z) then return x,y,z end
end
local function diagnostic(message)
    if message==lastDiagnostic then return end
    lastDiagnostic=message
    if type(log)=='table' and type(log.write)=='function' then pcall(log.write,'F4MH',log.INFO or 3,message)
    elseif type(print)=='function' then pcall(print,'F4MH '..message) end
end
local lastValues={}
local function set(name,value)
    if lastValues[name]==value then return end
    lastValues[name]=value
    if not handles[name] then handles[name]=get_param_handle('F4MH_'..name) end
    handles[name]:set(value)
end
local function read(name)
    local ok,v=pcall(function() return data[name](data) end)
    if ok and mathlib.finite(v) then return v end
end
make_default_activity(1/100)
need_to_be_closed=false
local hud_device=GetSelf()
for command=3900,3913 do hud_device:listen_command(command) end
function SetCommand(command,value) ccip.command(command,value) end
function post_initialize() set('VALID',0);set('FPM_VALID',0);diagnostic('HUD DEVICE INITIALIZED') end
function update()
    elapsed=elapsed+0.01
    local trimOK,trimY=true,-30 -- shared optical offset; no extra ladder offset
    trimY=trimOK and mathlib.finite(trimY) and trimY or 0
    set('VALID',0);set('FPM_VALID',0)
    local pitch,bank,heading=read('getPitch'),read('getRoll'),read('getHeading')
    local ias,alt=read('getIndicatedAirSpeed'),read('getBarometricAltitude')
    local agl=read('getRadarAltitude')
    -- Sensor values are metres. Exactly 500 ft and invalid AGL use MSL/barometric altitude.
    local useRadar=agl and agl>=0 and agl<152.4
    local displayedAlt=useRadar and agl or alt
    set('ATT_VALID',pitch and bank and 1 or 0)
    set('IAS_VALID',ias and 1 or 0);set('ALT_VALID',displayedAlt and 1 or 0);set('HDG_VALID',heading and 1 or 0)
    set('ALT_RADAR',useRadar and 1 or 0)
    local modeOK,mode=pcall(function() return get_cockpit_draw_argument_value(271) end)
    local index=modeOK and mathlib.finite(mode) and math.floor(mode/0.1666+0.5) or -1
    set('HUD_ON',index>=1 and index<=6 and 1 or 0) -- stock mode selector: OFF=0
    local intensityOK,intensity=pcall(get_cockpit_draw_argument_value,1201)
    set('BRIGHTNESS',intensityOK and mathlib.finite(intensity) and math.max(0,math.min(1,intensity)) or 1)
    for i=1,6 do set('MODE_'..i,index==i and 1 or 0) end
    diagnostic(string.format('HUD INPUTS pitch=%s bank=%s heading=%s ias=%s altitude=%s mode=%s',tostring(pitch~=nil),tostring(bank~=nil),tostring(heading~=nil),tostring(ias~=nil),tostring(alt~=nil),tostring(index)))
    local function shared(n)
        local ok,v=pcall(function() return get_param_handle('F4MC_'..n):get() end)
        if ok and mathlib.finite(v) then return v end
    end
    local linked=shared('LINK')==1
    local aa=index==4 or index==2
    local tracked=get_param_handle('RADAR_MODE'):get()==3 and get_param_handle('RADAR_STT_RANGE'):get()>0
    local gunLightOK,gunLight=pcall(get_cockpit_draw_argument_value,274)
    local gunSelected=(linked and shared('WEAPON_5209')==1) or (gunLightOK and mathlib.finite(gunLight) and gunLight>.05)
    local heatOK,heatLight=pcall(get_cockpit_draw_argument_value,280) -- Heads_Up_Heat_Light, local draw_args.lua
    local heatSelected=(linked and shared('WEAPON_5208')==1) or (heatOK and mathlib.finite(heatLight) and heatLight>.05)
    set('IR_CUE',aa and heatSelected and not gunSelected and 1 or 0)
    update_uncage(false) -- user preference: original ARR remains manual only
    local function draw(n)
        local ok,v=pcall(get_cockpit_draw_argument_value,n);return ok and type(v)=='number' and string.format('%.2f',v) or 'UNAVAILABLE'
    end
    local heatStatus='aa='..tostring(aa)..' heat='..tostring(heatSelected)..' gun='..tostring(gunSelected)..
        ' arm='..draw(247)..' volume='..draw(635)..' heat_lamps='..draw(284)..'/'..draw(285)..'/'..draw(286)..'/'..draw(287)
    if heatStatus~=lastHeatStatus or (heatSelected and elapsed-lastHeatLog>=5) then
        if type(log)=='table' then log.write('F4_HEAT_STATUS',log.INFO,heatStatus) end
        lastHeatStatus=heatStatus;lastHeatLog=elapsed
    end
    set('GUN_LEAD',aa and gunSelected and not tracked and 1 or 0);set('FIXED_REF',aa and gunSelected and 0 or 1)
    local ratePitch,rateYaw=read('getRateOfPitch'),read('getRateOfYaw')
    -- Some full-fidelity sensor tables omit body rates. Derive them from Euler
    -- attitude changes rather than suppressing the whole funnel in that case.
    if pitch and bank and heading and previousAttitude then
        local dp=(pitch-previousAttitude.pitch)/.01
        local dh=((heading-previousAttitude.heading+math.pi)%(2*math.pi)-math.pi)/.01
        if not ratePitch then ratePitch=dp*math.cos(bank)-dh*math.sin(bank)*math.cos(pitch) end
        if not rateYaw then rateYaw=-dp*math.sin(bank)-dh*math.cos(bank)*math.cos(pitch) end
    end
    if pitch and bank and heading then previousAttitude={pitch=pitch,bank=bank,heading=heading} else previousAttitude=nil end
    local spanOK,span=pcall(function() return get_param_handle('F4MH_SPAN'):get() end)
    if not spanOK or not mathlib.finite(span) or span<5 then span=10 end
    set('FUNNEL_SPAN',span)
    local left,right
    if false then left,right=weaponMath.funnel(pitch,bank,ratePitch,rateYaw,span) end
    set('FUNNEL_VALID',left and 1 or 0)
    if left then
        -- Use the same proven mesh/parameter translation path as the FPM.
        -- Dense overlapping stroke samples avoid the unverified native line-point
        -- controller's coordinate/signature behavior entirely.
        for side,points in pairs({L=left,R=right}) do
            local count=0
            for i=1,#points-1 do
                local a,b=points[i],points[i+1]
                local dx,dy=b.x-a.x,b.y-a.y
                local steps=math.min(600,math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy)/.9)))
                for j=0,steps-1 do
                    local t=j/steps;local x,y=a.x+dx*t,a.y+dy*t+trimY
                    if math.abs(x)<=110 and y>=-110 and y<=40 and count<256 then
                        count=count+1;set('FUN_'..side..'X_'..count,x);set('FUN_'..side..'Y_'..count,y);set('FUN_'..side..'SHOW_'..count,1)
                    end
                end
            end
            for i=count+1,funnelCounts[side] do set('FUN_'..side..'SHOW_'..i,0) end
            funnelCounts[side]=count
        end
    end

    local tx,ty,limited,bx,by,box_limited
    if aa and tracked then
        local az=get_param_handle('RADAR_STT_AZIMUTH'):get()
        local el=get_param_handle('RADAR_STT_ELEVATION'):get()
        tx,ty,limited=mathlib.ray(math.cos(el)*math.cos(az),math.sin(el),math.cos(el)*math.sin(az),trimY,true)
        -- STT supplies independent HUD angles; do not reinterpret elevation as spherical latitude.
        bx,by,box_limited=mathlib.hud_angles(az,el,alignment.target_y)
        if elapsed-lastLOSLog>=.25 and type(log)=='table' then
            lastLOSLog=elapsed
            log.write('F4_SIMPLE_HUD_LOS',log.INFO,string.format('t=%.3f az=%.6f el=%.6f pitch=%s bank=%s box=%.3f/%.3f gun=%.3f/%.3f range=%.1f',elapsed,az,el,tostring(pitch),tostring(bank),bx or 0,by or 0,tx or 0,ty or 0,get_param_handle('RADAR_STT_RANGE'):get()))
        end
    end
    set('TD_VALID',tx and 1 or 0);set('TD_LIMIT',limited and 1 or 0)
    local onscreen=bx and not box_limited
    set('BOX_VALID',bx and 1 or 0);set('BOX_LIMIT',box_limited and 1 or 0)
    if bx then set('BOX_X',bx);set('BOX_Y',by) end
    set('TD_ONSCREEN',onscreen and 1 or 0)
    local iff=get_param_handle('RADAR_STT_FRIENDLY'):get()
    local interrogating=get_param_handle('IFF_INTERROGATOR_STATUS'):get()==1
    set('TD_IFF_FRIEND',onscreen and interrogating and iff==1 and 1 or 0)
    set('TD_IFF_FOE',onscreen and interrogating and iff==0 and 1 or 0)
    set('TD_IFF_NONE',onscreen and (not interrogating or (iff~=0 and iff~=1)) and 1 or 0)
    if tx then set('TD_X',tx);set('TD_Y',ty) end
    set('RADAR_INFO',aa and tracked and 1 or 0)
    set('VSI_SHOW',not (aa and tracked) and 1 or 0)
    set('RADAR_RANGE',get_param_handle('RADAR_STT_RANGE'):get()/1852)
    set('RADAR_VC_VALID',aa and tracked and get_param_handle('F4_SR_CLOSURE_VALID'):get() or 0)
    set('RADAR_VC',get_param_handle('F4_SR_CLOSURE_KT'):get())
    set('ACM',aa and get_param_handle('F4_SR_ACM'):get() or 0)
    -- Keep basic attitude until the F-16 gun attitude-awareness replacement is validated.
    set('ATT_VALID',pitch and bank and 1 or 0)
    set('GUN_TRACK',aa and gunSelected and tracked and 1 or 0)
    set('MISSILE_TRACK',aa and not gunSelected and tracked and 1 or 0)
    -- Local F-16 HUD_common/add_PL_line rules; body/world projection supplied here.
    for row=0,34 do
        local deg=row*5-85
        local nearby=pitch and math.abs(deg-math.deg(pitch))<=25
        for side=1,2 do
            local count=deg==0 and 192 or 38
            for j=1,count do
                local tick=j>count-6 and deg~=0
                local along=tick and 0 or (j-1)/(deg==0 and count-1 or count-7)*(deg==0 and 170 or 25)
                local offset=(16+along)*(side==1 and -1 or 1)
                local vertical=deg<0 and along*math.tan(math.rad(deg/2)) or 0
                if tick then vertical=(j-(count-6))/6*4*(deg>0 and -1 or 1) end
                local lx,ly,show
                if nearby then lx,ly,show=mathlib.ladder_stroke(deg,offset,vertical,pitch,bank,trimY) end
                local key='LP_'..row..'_'..side..'_'..j
                local dash=tick or deg>=0 or math.floor(along/4)%2==0
                set(key..'X',lx or 0);set(key..'Y',ly or 0);set(key..'V',show and dash and 1 or 0)
            end
            local label_y=deg<0 and 25*math.tan(math.rad(deg/2)) or 0
            local lx,ly,show
            if nearby then lx,ly,show=mathlib.ladder_stroke(deg,50*(side==1 and -1 or 1),label_y,pitch,bank,trimY) end
            local key='LL_'..row..'_'..side
            set(key..'X',lx or 0);set(key..'Y',ly or 0);set(key..'V',show and deg~=0 and 1 or 0)
        end
    end
    -- DCS base sensor heading is counterclockwise; displayed heading is true, clockwise.
    if heading then heading=(-heading)%(2*math.pi) end
    if ias then set('IAS',ias*1.94384449) end
    if displayedAlt then set('ALT',displayedAlt/0.3048) end
    local alpha=read('getAngleOfAttack')
    set('ALPHA_VALID',alpha and 1 or 0);set('ALPHA',alpha and math.deg(alpha) or 0)
    if pitch and bank then set('PITCH',pitch*1000);set('BANK',bank) end
    for i=0,34 do
        local lx,ly,visible=mathlib.ladder(i*5-85,pitch,bank,trimY)
        set('LADDER_X_'..i,lx);set('LADDER_Y_'..i,ly);set('LADDER_SHOW_'..i,visible and 1 or 0)
    end
    local degrees=heading and math.deg(heading)%360
    if degrees then set('HDG',math.floor(degrees+0.5)%360) end
    for i=0,71 do
        local delta=degrees and (i*5-degrees+180)%360-180 or 180
        set('HMARK_'..i,delta*2.8);set('HSHOW_'..i,math.abs(delta)<=27 and 1 or 0)
        set('HLABEL_'..i,math.abs(delta)<=12 and 1 or 0)
    end
    local mach,g,vvi=read('getMachNumber'),read('getVerticalAcceleration'),read('getVerticalVelocity')
    set('MACH_VALID',mach and 1 or 0);set('MACH',mach or 0)
    set('G_VALID',g and 1 or 0);set('G',g or 0)
    set('VVI_VALID',vvi and 1 or 0);set('VVI',(vvi or 0)*196.8503937)
    local x,y,z=vector('getSelfVelocity')
    local source=x and 'WORLD_VELOCITY' or 'UNAVAILABLE'
    local cx,cy,cz=vector('getSelfCoordinates')
    local timeOK,now=pcall(function() return get_model_time() end)
    if not timeOK or not mathlib.finite(now) then now=elapsed end
    if cx then
        if not x and lastPosition then
            local dt=now-lastPosition.time
            if dt>0 and dt<=0.25 then
                local vx,vy,vz=(cx-lastPosition.x)/dt,(cy-lastPosition.y)/dt,(cz-lastPosition.z)/dt
                local speed=math.sqrt(vx*vx+vy*vy+vz*vz)
                if speed<1500 then x,y,z=vx,vy,vz;source='POSITION_DELTA' end
            end
        end
        lastPosition={x=cx,y=cy,z=cz,time=now}
    else lastPosition=nil end
    local px,py,limited
    if x and pitch and bank and heading then
        px,py,limited=mathlib.project(x,y,z,pitch,bank,heading,trimY)
    end
    if px then
        set('FPM_X',px);set('FPM_Y',py);set('FPM_LIMIT',limited and 1 or 0);set('FPM_VALID',1)
    end
    set('FPM_MISSING',px and 0 or 1)
    local combat={aa=aa,gun=gunSelected,pitch=pitch,bank=bank,heading=heading,altitude=alt,vx=x,vy=y,vz=z,time=now}
    update_dlz(combat);update_gun(combat)
    local tvOK,tv=pcall(get_cockpit_draw_argument_value,2599)
    ccip.update({ag=index==3,time=now,
        x=cx,y=cy,z=cz,pitch=pitch,bank=bank,heading=heading,fpm_x=px,fpm_y=py})
    if elapsed-lastFpmLog>=5 then
        lastFpmLog=elapsed
        if type(log)=='table' and type(log.write)=='function' then
            pcall(log.write,'F4MH',log.INFO or 3,string.format('FPM source=%s coordinates=%s valid=%s x=%s y=%s funnel=%s gun=%s stroke_points=%d/%d',source,tostring(cx~=nil),tostring(px~=nil),tostring(px),tostring(py),tostring(left~=nil),tostring(gunSelected),funnelCounts.L,funnelCounts.R))
        end
    end
    set('VALID',pitch and bank and heading and ias and alt and 1 or 0)
end
