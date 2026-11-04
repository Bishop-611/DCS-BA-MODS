-- Independent B-scope projection; never write native radar input parameters here.
local function handle(name) return get_param_handle(name) end
local profile=dofile([[__F4_RUNTIME__/radar-profile.lua]])
local output = {}
local function set(name, value)
    if not output[name] then output[name] = handle('F4_SR_' .. name) end
    output[name]:set(value)
end
local mode = handle('RADAR_MODE')
local stt = {range=handle('RADAR_STT_RANGE'), az=handle('RADAR_STT_AZIMUTH'), friendly=handle('RADAR_STT_FRIENDLY')}
local cursor = {range=handle('RADAR_TDC_RANGE'), az=handle('RADAR_TDC_AZIMUTH')}
local ui_cursor={valid=handle('F4_SR_UI_TDC_VALID'),range=handle('F4_SR_UI_TDC_RANGE'),az=handle('F4_SR_UI_TDC_AZ')}
local previous_sample,closure=nil,nil
local select_return=dofile([[__F4_RUNTIME__/Controls/select-return.lua]])
local hover_sample,hover_velocity=nil,nil
local fallback_time=0
local contacts = {}
for i=1,128 do
    local prefix=string.format('RADAR_CONTACT_%02d_',i)
    contacts[i]={range=handle(prefix..'RANGE'),az=handle(prefix..'AZIMUTH'),age=handle(prefix..'TIME'),kind=handle(prefix..'NCTR')}
end
local display_range=handle('F4_SR_RANGE_MAX_NM')
local function position(az, range)
    local selected=display_range:get()
    local max_range=(selected>0 and selected or profile.range_nm)*1852
    local x=az/math.rad(60)*0.72
    local y=-0.82+range/max_range*1.40
    return x,y,math.abs(x)<=0.72 and y>=-0.82 and y<=0.58
end
return function()
    local selected=display_range:get()
    set('RANGE_MAX_NM',selected>0 and selected or profile.range_nm)
    for i=1,4 do set('SCALE_'..i,(selected>0 and selected or profile.range_nm)*i/4) end
    local current=mode:get()
    set('MODE',current)
    local source=ui_cursor.valid:get()==1 and ui_cursor or cursor
    local x,y,inside=position(source.az:get(),source.range:get())
    set('TDC_X',x);set('TDC_Y',y);set('TDC_SHOW',inside and (current==1 or current==2) and 1 or 0)
    local locked=current==3 and stt.range:get()>0
    x,y,inside=position(stt.az:get(),stt.range:get())
    set('STT_X',x);set('STT_Y',y);set('STT_SHOW',locked and inside and 1 or 0)
    set('STT_VALID',locked and 1 or 0)
    set('RANGE_NM',locked and stt.range:get()/1852 or 0)
    set('INFO_VALID',locked and 1 or 0)
    set('FRIENDLY',locked and stt.friendly:get() or -1)
    fallback_time=fallback_time+.1
    local time=fallback_time
    if type(get_model_time)=='function' then local ok,t=pcall(get_model_time);if ok and type(t)=='number' then time=t end end
    local valid=false
    if locked then
        local r=stt.range:get()
        if previous_sample then
            local dt=time-previous_sample.time
            if dt>0 and dt<=1 then
                local velocity=(previous_sample.range-r)/dt
                if math.abs(velocity)<2000 then
                    closure=closure and closure+(velocity-closure)*dt/(.4+dt) or velocity
                    valid=true
                else closure=nil end
            end
        end
        previous_sample={time=time,range=r}
    else previous_sample=nil;closure=nil end
    set('CLOSURE_VALID',valid and 1 or 0)
    set('CLOSURE_KT',valid and closure*1.943844492 or 0)
    local slot=0
    local batch={}
    if current==1 or current==2 then
        local candidates={}
        for _,contact in ipairs(contacts) do
            local range,age=contact.range:get(),contact.age:get()
            if range>0 and age>=0 and age<=profile.display_history_seconds then
                candidates[#candidates+1]={range=range,age=age,az=contact.az:get(),kind=contact.kind:get()}
            end
        end
        table.sort(candidates,function(a,b) return a.age<b.age end)
        local newest_age=candidates[1] and candidates[1].age or 0
        for _,candidate in ipairs(candidates) do
            -- One recent temporal batch, regardless of distance. No synthetic target IDs.
            if candidate.age-newest_age<=profile.display_batch_window_seconds then
                batch[#batch+1]=candidate
                x,y,inside=position(candidate.az,candidate.range)
                if inside and slot<32 then
                    slot=slot+1
                    set('C'..slot..'_X',x);set('C'..slot..'_Y',y);set('C'..slot..'_SHOW',1)
                end
            end
        end
    end
    local hovered=(current==1 or current==2) and select_return(batch,source.az:get(),source.range:get(),
        (selected>0 and selected or profile.range_nm)*1852) or nil
    if hovered then
        set('INFO_VALID',1);set('RANGE_NM',hovered.range/1852)
        local sample_time=time-hovered.age
        local matches=0
        for _,candidate in ipairs(batch) do
            if candidate.age<=2 and candidate.kind==hovered.kind and math.abs(candidate.az-hovered.az)<math.rad(1)
                and math.abs(candidate.range-hovered.range)<2500 then matches=matches+1 end
        end
        if matches>1 then hover_sample=nil;hover_velocity=nil end
        if hover_sample then
            local dt=sample_time-hover_sample.time
            local same=hovered.kind==hover_sample.kind and math.abs(hovered.az-hover_sample.az)<math.rad(1)
                and math.abs(hovered.range-hover_sample.range)<2500
            if not same or dt<-.05 or dt>10 then hover_sample=nil;hover_velocity=nil
            elseif dt>=.25 then
                local v=(hover_sample.range-hovered.range)/dt
                hover_velocity=math.abs(v)<2000 and v or nil
                hover_sample=nil
            end
        end
        if not hover_sample and matches==1 then hover_sample={time=sample_time,range=hovered.range,az=hovered.az,kind=hovered.kind} end
        set('CLOSURE_VALID',hover_velocity and 1 or 0)
        set('CLOSURE_KT',hover_velocity and hover_velocity*1.943844492 or 0)
    elseif current~=1 and current~=2 then hover_sample=nil;hover_velocity=nil
    elseif hover_sample then
        -- Retain history over a scan gap only while the cursor remains on that return.
        if time-hover_sample.time>10 or not select_return({hover_sample},source.az:get(),source.range:get(),
            (selected>0 and selected or profile.range_nm)*1852) then hover_sample=nil;hover_velocity=nil end
    end
    for i=slot+1,32 do set('C'..i..'_SHOW',0) end
end
