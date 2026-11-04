local root=[[__F4_RUNTIME__/]]
local Controller=dofile(root..'Controls/manual-controller.lua')
local map=dofile(root..'Controls/input-map.lua')
local force_interlock=dofile(root..'Controls/force-interlock.lua')
local dev=GetSelf()
local time=0
local last_slew,last_cursor_log=-10,-10
local held,forwarded={},{}
local reset_until,start_at,release_at=nil,nil,nil
local mode=get_param_handle('RADAR_MODE')
local tdc_az=get_param_handle('RADAR_TDC_AZIMUTH')
local tdc_range=get_param_handle('RADAR_TDC_RANGE')
local ui_az=get_param_handle('F4_SR_UI_TDC_AZ')
local ui_range=get_param_handle('F4_SR_UI_TDC_RANGE')
local range=get_param_handle('F4_SR_RANGE_MAX_NM')
local acm=get_param_handle('F4_SR_ACM')
local sensors=get_base_data()
local power_switch=.75
local function powered() return power_switch>=.74 end
local function report(s) log.write('F4_SIMPLE_INPUT',log.INFO,s) end
local function radar() return assert(GetDevice(201),'Simple radar unavailable') end
local function aa_context()
    local ok,v=pcall(get_cockpit_draw_argument_value,271)
    if not ok or type(v)~='number' then return false end
    local index=math.floor(v/.1666+.5)
    -- Same A/A and CAGE HUD positions used by the modern-HUD implementation.
    if index~=4 and index~=2 then return false end
    -- A/G/TV uses HUD index 3; a screen-selector value alone must not disable A/A inputs.
    return true
end
local function airborne()
    local ok,n,l,r=pcall(function()
        return sensors.getWOW_NoseLandingGear(),sensors.getWOW_LeftMainLandingGear(),sensors.getWOW_RightMainLandingGear()
    end)
    return ok and type(n)=='number' and type(l)=='number' and type(r)=='number' and n<.5 and l<.5 and r<.5
end
local routes={}
for _,entry in ipairs(map) do
    routes[entry.routed]=entry
    if entry.axis_routed then routes[entry.axis_routed]=entry end
end
for command in pairs(routes) do dev:listen_command(command) end
local function forward(command,value)
    local entry=routes[command]
    if entry then dispatch_action(entry.device,entry.command,value) end
end
local contacts={}
for i=1,128 do
    local prefix=string.format('RADAR_CONTACT_%02d_',i)
    contacts[i]={range=get_param_handle(prefix..'RANGE'),az=get_param_handle(prefix..'AZIMUTH'),age=get_param_handle(prefix..'TIME'),
        elevation=get_param_handle(prefix..'ELEVATION')}
end
local controller=Controller.new({
    mode=function() return mode:get() end,
    busy=function() return reset_until~=nil or start_at~=nil or release_at~=nil end,
    state=function(active,maxrange) acm:set(active and 1 or 0);range:set(maxrange);report('ACM='..tostring(active)..' RANGE_NM='..tostring(maxrange)) end,
    cursor=function(az,r) tdc_az:set(az);tdc_range:set(r);ui_az:set(az);ui_range:set(r) end,
    unlock=function()
        start_at=nil
        if release_at then dispatch_action(nil,510);release_at=nil end
        radar():set_power(false);reset_until=time+.2
        get_param_handle('IFF_INTERROGATOR_STATUS'):set(0)
        get_param_handle('SCAN_ZONE_ORIGIN_ELEVATION'):set(0)
        report('UNLOCK requested; brief native radar power reset')
    end,
    lock_at=function(az,r,elevation)
        if reset_until then return end
        tdc_az:set(az);tdc_range:set(r);get_param_handle('RADAR_TDC_RANGE_CARRET_SIZE'):set(3000)
        ui_az:set(az);ui_range:set(r)
        if type(elevation)=='number' then get_param_handle('SCAN_ZONE_ORIGIN_ELEVATION'):set(elevation) end
        start_at=time+.2
        report('LOCK selected fresh return range='..tostring(r)..' az='..tostring(az)..' elevation='..tostring(elevation))
    end,
    no_target=function(az,r) report('NO_FRESH_RETURN near cursor az='..tostring(az)..' range='..tostring(r)) end,
    iff=function() get_param_handle('IFF_INTERROGATOR_STATUS'):set(1) end,
    contacts=function()
        local result,minage={},math.huge
        for _,target in ipairs(contacts) do
            local age=target.age:get()
            if age>=0 and age<=2 and target.range:get()>0 then
                minage=math.min(minage,age)
                result[#result+1]={range=target.range:get(),az=target.az:get(),age=age,elevation=target.elevation:get()}
            end
        end
        local batch={}
        for _,target in ipairs(result) do if target.age-minage<=.25 then batch[#batch+1]=target end end
        return batch
    end
})
make_default_activity(.02)
need_to_be_closed=false
function post_initialize()
    get_param_handle('F4_SR_POWER_SWITCH'):set(power_switch)
    report('MANUAL_ROUTER initialized; existing Cage/NWS/FHC options only; A/G passthrough')
end
function SetCommand(command,value)
    local entry=routes[command]
    if not entry or type(value)~='number' then return end
    report('RAW_INPUT command='..tostring(command)..' value='..tostring(value))
    if entry.kind=='interlock' then force_interlock('BLOCKED_INPUT');return end
    if entry.kind:sub(1,5)=='power' then
        if entry.kind=='power' then power_switch=value
        elseif entry.kind=='power_axis' then power_switch=(value+1)/2
        elseif entry.kind=='power_step' and value~=0 then power_switch=power_switch+(value>0 and .25 or -.25)
        elseif entry.kind=='power_next' and value>0 then power_switch=(power_switch+.25)%1.25 end
        power_switch=math.max(0,math.min(1,math.floor(power_switch*4+.5)/4))
        get_param_handle('F4_SR_POWER_SWITCH'):set(power_switch)
        if not powered() then
            controller.cage_press=nil;controller.acm=false;controller.pending=false
            start_at=nil;reset_until=nil
            if release_at then dispatch_action(nil,510);release_at=nil end
        end
        radar():set_power(powered())
        report('NEW_RADAR_POWER knob='..tostring(power_switch)..' on='..tostring(powered()))
        return
    end
    local aa=aa_context()
    local consume=aa and (entry.kind~='nws' or airborne())
    if not consume then
        forward(command,value);forwarded[command]=math.abs(value)>.01
        return
    end
    if not powered() then return end
    if forwarded[command] then forward(command,0);forwarded[command]=false end
    if entry.kind=='cage' then controller:cage(value>.5,time)
    elseif entry.kind=='nws' then controller:nws(value>.5)
    else
        local axis=command==entry.axis_routed
        controller:slew((axis and 'axis_' or 'key_')..entry.kind,value*(entry.scale or 1))
        last_slew=time
    end
    report('INPUT command='..tostring(command)..' value='..tostring(value)..' AA consumed')
end
function update()
    time=time+.02
    if reset_until and time>=reset_until then radar():set_power(powered());reset_until=nil end
    if start_at and time>=start_at then dispatch_action(nil,509);start_at=nil;release_at=time+5 end
    if release_at and time>=release_at then dispatch_action(nil,510);release_at=nil end
    local aa=aa_context()
    get_param_handle('F4_SR_AA_ACTIVE'):set(aa and 1 or 0)
    controller:tick(time,.02,aa and powered())
    get_param_handle('F4_SR_UI_TDC_VALID'):set(aa and powered() and 1 or 0)
    if time-last_slew<1 and time-last_cursor_log>=.25 then
        last_cursor_log=time
        report('CURSOR commanded_az='..tostring(ui_az:get())..' commanded_range='..tostring(ui_range:get())..
            ' readback_az='..tostring(tdc_az:get())..' readback_range='..tostring(tdc_range:get())..' acm='..tostring(controller.acm))
    end
    -- The reused model knob visualizes the new radar, not the original transmitter state.
    pcall(function() set_cockpit_draw_argument_value(336,power_switch) end)
end
