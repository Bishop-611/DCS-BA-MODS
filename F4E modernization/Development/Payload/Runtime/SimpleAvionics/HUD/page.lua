local elementParameters,elementControllers,groupElements={},{},{}
local function createGroup()
    local e=CreateElement 'ceSimple';groupElements[e]=true;return e
end
-- Original F-4 glass mask and collimator are retained by init.lua.
dofile(LockOn_Options.script_path..'Scripts/HeadUpDisplay/Indicator/definitions.lua')
dofile(LockOn_Options.script_path..'Scripts/Common/levels.lua')
local material=MakeMaterial(nil,{20,255,60,255})
-- Same DX font source used by the stock F-4 ControlsIndicator; avoid the tiny DSCG bitmap.
local font=MakeFont({used_DXUnicodeFontData='font_cockpit_rus_2'},{20,255,60,255})
local serial=0
local function add(e,parent,is_text)
    serial=serial+1;e.name='F4MH_'..serial
    e.collimated=true;e.level=HUD_DEFAULT_LEVEL;e.h_clip_relation=h_clip_relations.COMPARE
    e.isvisible=true
    -- Opaque green strokes: repeated mesh faces must not accumulate into white.
    e.additive_alpha=false;e.use_mipfilter=false
    if parent then
        if type(parent)=='table' and parent.fpm_transform==true then
            e.parent_element=parent.parent_element
            elementParameters[e]=parent.params or {'F4MH_FPM_VALID','F4MH_FPM_X','F4MH_FPM_Y','F4MH_FPM_LIMIT'}
            local controllers={{'parameter_in_range',0,0.5,1.5},{'move_left_right_using_parameter',1,0.001},{'move_up_down_using_parameter',2,0.001}}
            if parent.limited then controllers[#controllers+1]={'parameter_in_range',3,0.5,1.5} end
            elementControllers[e]=controllers
        else e.parent_element=parent.name end
    end
    local parameters,controllers={},{}
    for i,v in ipairs(elementParameters[e] or {}) do parameters[i]=v end
    for i,v in ipairs(elementControllers[e] or {}) do controllers[i]=v end
    if not groupElements[e] then
        local brightnessIndex=#parameters;parameters[#parameters+1]='F4MH_BRIGHTNESS'
        controllers[#controllers+1]={'opacity_using_parameter',brightnessIndex}
    end
    e.element_params=parameters;e.controllers=controllers;e.change_opacity=true
    Add(e);elementParameters[e]=nil;elementControllers[e]=nil;groupElements[e]=nil;return e
end
local root=createGroup()
root.init_pos={0,0,0}
elementParameters[root]={'F4MH_HUD_ON'}
elementControllers[root]={{'parameter_in_range',0,.5,1.5}}
-- Static page geometry must not disappear when one sensor is unavailable.
add(root)
local flightRoot=createGroup();flightRoot.init_pos={0,0,0}
-- Calibration is applied to angular coordinates before edge limiting in device.lua.
add(flightRoot,root)
local function gate(parameter,parent)
    local e=createGroup();e.init_pos={0,0,0};elementParameters[e]={parameter};elementControllers[e]={{'parameter_in_range',0,0.5,1.5}}
    return add(e,parent or root)
end
local function line(points,parent,strokeWidth,options)
    -- Explicit triangles in milliradians: the previous 0.0014-wide lines were subpixel.
    local e=CreateElement 'ceMeshPoly';e.material=material;e.init_pos={0,0,0}
    -- DCS element properties copy tables. Build locally, assign each complete array once.
    local vertices,indices={},{}
    for i=1,#points-1 do
        local a,b=points[i],points[i+1]
        local dx,dy=b[1]-a[1],b[2]-a[2];local length=math.sqrt(dx*dx+dy*dy)
        if length>0 then
            local half=(strokeWidth or 1.5)*.5
            local nx,ny=-dy/length*half,dx/length*half;local n=#vertices
            for _,v in ipairs({{a[1]+nx,a[2]+ny},{b[1]+nx,b[2]+ny},{b[1]-nx,b[2]-ny},{a[1]-nx,a[2]-ny}}) do vertices[#vertices+1]=v end
            -- Both windings avoid dependence on mesh face-culling conventions.
            for _,v in ipairs({n,n+1,n+2,n,n+2,n+3,n+2,n+1,n,n+3,n+2,n}) do indices[#indices+1]=v end
        end
    end
    e.vertices=vertices;e.indices=indices
    if options then elementParameters[e]=options.params;elementControllers[e]=options.controllers end
    return add(e,parent or root)
end
local function text(value,x,y,param,format,parent,large)
    local e=CreateElement 'ceStringPoly';e.material=font;e.init_pos={x,y,0}
    -- Same height; slightly wider glyphs provide more horizontal pixels per stroke.
    e.alignment='CenterCenter';e.stringdefs=large and {0.0095,0.0062,0,0} or {0.0085,0.0056,0,0}
    if param then elementParameters[e]={param};e.formats={format or '%.0f'};elementControllers[e]={{'text_using_parameter',0,0}}
    else e.value=value end
    return add(e,parent or root,true)
end
-- Fixed F-16-style gun cross / aircraft reference.
local fixedRef=gate('F4MH_FIXED_REF',flightRoot)
line({{-6,0},{6,0}},fixedRef);line({{0,-6},{0,6}},fixedRef)
-- Independent mesh FPM; no native HUD controller or texture dependency.
-- Apply translation to drawable leaves rather than inheriting it through ceSimple.
local fpm={fpm_transform=true,parent_element=flightRoot.name}
local circle={};for i=0,32 do circle[#circle+1]={4*math.cos(i*2*math.pi/32),4*math.sin(i*2*math.pi/32)} end
line(circle,fpm);line({{-11,0},{-4,0}},fpm);line({{4,0},{11,0}},fpm);line({{0,4},{0,9}},fpm)
local fpm_limit={fpm_transform=true,parent_element=flightRoot.name,limited=true}
line({{-3,-3},{3,3}},fpm_limit);line({{-3,3},{3,-3}},fpm_limit)
text('FPM DATA',0,-100,nil,nil,gate('F4MH_FPM_MISSING'))
-- Projected world-referenced ladder; negative rungs dashed, zero horizon solid.
local attitude=gate('F4MH_ATT_VALID',flightRoot)
local function point(key,parent)
    local moving={fpm_transform=true,parent_element=parent.name,
        params={'F4MH_'..key..'V','F4MH_'..key..'X','F4MH_'..key..'Y'}}
    line({{-.55,0},{.55,0}},moving,1.15)
end
for row=0,34 do
    for side=1,2 do
        for j=1,(row==17 and 192 or 38) do point('LP_'..row..'_'..side..'_'..j,attitude) end
        local key='LL_'..row..'_'..side
        local moving={fpm_transform=true,parent_element=attitude.name,
            params={'F4MH_'..key..'V','F4MH_'..key..'X','F4MH_'..key..'Y'}}
        text(tostring(math.abs(row*5-85)),0,0,nil,nil,moving)
    end
end
-- Compact numeric windows fit the F-4's smaller combiner.
text(nil,-100,-5,'F4MH_IAS','%03.0f',gate('F4MH_IAS_VALID'),true)
text(nil,100,-5,'F4MH_ALT','%.0f',gate('F4MH_ALT_VALID'),true)
text('R',132,-5,nil,nil,gate('F4MH_ALT_RADAR'))
text('KTS',-100,13);text('FT',100,13)
local heading=gate('F4MH_HDG_VALID')
text(nil,0,35,'F4MH_HDG','%03.0f',heading);text('T',24,35)
-- Heading scale: fixed five-degree marks scroll with actual heading, wrap at north.
for i=0,71 do
    local anchor=createGroup();elementParameters[anchor]={'F4MH_HDG'}
    -- Separate wrapping handled by the updater parameters below.
    elementParameters[anchor]={'F4MH_HMARK_'..i,'F4MH_HSHOW_'..i}
    elementControllers[anchor]={{'move_left_right_using_parameter',0,0.001},{'parameter_in_range',1,0.5,1.5}}
    anchor.init_pos={0,15,0};add(anchor,heading)
    line({{0,0},{0,i%2==0 and -5 or -3}},anchor)
    if i%2==0 then text(string.format('%02d',i/2),0,-11,nil,nil,gate('F4MH_HLABEL_'..i,anchor)) end
end
line({{-3,23},{0,19},{3,23}})
local function optional(param,valid,x,y,fmt)
    local gate=createGroup();elementParameters[gate]={valid};elementControllers[gate]={{'parameter_in_range',0,0.5,1.5}};add(gate,root)
    text(nil,x,y,param,fmt,gate)
end
optional('F4MH_MACH','F4MH_MACH_VALID',-90,-81,'M %.2f')
optional('F4MH_ALPHA','F4MH_ALPHA_VALID',-90,-62,'AOA %.1f')
optional('F4MH_G','F4MH_G_VALID',-90,-100,'%.1f G')
local vsi=gate('F4MH_VSI_SHOW')
text('V/S',90,-62,nil,nil,vsi)
text(nil,90,-81,'F4MH_VVI','%.0f',gate('F4MH_VVI_VALID',vsi))
-- Real F-4 knob mode at the requested upper-right position, not a fabricated NAV label.
for index,label in ipairs({'STBY','CAGE','A/G','A/A','BIT 1','BIT 2'}) do
    text(label,96,35,nil,nil,gate('F4MH_MODE_'..index))
end
-- Small static registration mark for the first in-game visibility verification.
-- No development registration label in the operational HUD.

-- F-16 stroke primitives in one fixed HUD coordinate frame; no translated marks.
local dlzRoot=createGroup();dlzRoot.init_pos={0,0,0}
elementParameters[dlzRoot]={'F4MH_DLZ_VALID'};elementControllers[dlzRoot]={{'parameter_in_range',0,.5,1.5}}
add(dlzRoot,root)
local function dlzStroke(points,params,controllers)
 local e=CreateElement 'ceSMultiLine';e.material=material;e.init_pos={0,0,0}
 e.thickness=1.6;e.fuzziness=.6;e.draw_as_wire=false;e.z_enabled=false
 local vertices,indices={},{}
 for i,p in ipairs(points) do
  vertices[#vertices+1]={p[1],p[2]}
  if i<#points then indices[#indices+1]=i-1;indices[#indices+1]=i end
 end
 e.vertices=vertices;e.indices=indices
 if params then elementParameters[e]=params;elementControllers[e]=controllers end
 return add(e,dlzRoot)
end
for slot=0,63 do
 local y=-92+slot
 dlzStroke({{100,y},{100,y+1}}, {'F4MH_DLZ_MIN_SLOT','F4MH_DLZ_MAX_SLOT'},
  {{'parameter_in_range',0,-1,slot+.1},{'parameter_in_range',1,slot+.9,65}})
end
local function mark(parameter,points,extra)
 for slot=0,64 do
  local vertices={};for _,p in ipairs(points) do vertices[#vertices+1]={100+p[1],-92+slot+p[2]} end
  local params,controllers={parameter},{{'parameter_in_range',0,slot-.1,slot+.1}}
  if extra then params[2]=extra;controllers[2]={'parameter_in_range',1,.5,1.5} end
  dlzStroke(vertices,params,controllers)
 end
end
mark('F4MH_DLZ_MIN_SLOT',{{0,0},{6,0}})
mark('F4MH_DLZ_MAX_SLOT',{{0,0},{6,0}})
mark('F4MH_DLZ_R2_SLOT',{{0,0},{4,0}},'F4MH_DLZ_R2_VALID')
mark('F4MH_DLZ_TARGET_SLOT',{{-10,-3},{-4,0},{-10,3}})
text(nil,104,-16,'F4MH_DLZ_SCALE','%.0f',dlzRoot)
text('7M',104,-108,nil,nil,dlzRoot)
text(nil,70,-96,'F4MH_DLZ_TOF','T %.0f',gate('F4MH_DLZ_TOF_VALID',dlzRoot))
-- Target designation box follows native antenna line of sight, not an SA track.
-- Actual STT target box, independent of the accepted gun cue.
local td={fpm_transform=true,parent_element=flightRoot.name,
    params={'F4MH_TD_ONSCREEN','F4MH_BOX_X','F4MH_BOX_Y'}}
line({{-18,-18},{18,-18},{18,18},{-18,18},{-18,-18}},td,1.2)
-- Keep text's own value controller; apply the target translation on its parent.
local rangeAnchor=createGroup();rangeAnchor.init_pos={0,0,0}
elementParameters[rangeAnchor]={'F4MH_TD_ONSCREEN','F4MH_BOX_X','F4MH_BOX_Y'}
elementControllers[rangeAnchor]={{'parameter_in_range',0,.5,1.5},{'move_left_right_using_parameter',1,.001},{'move_up_down_using_parameter',2,.001}}
add(rangeAnchor,flightRoot)
text(nil,0,-27,'F4MH_RADAR_RANGE','%.1f NM',rangeAnchor)
for _,item in ipairs({{'FRIEND','F4MH_TD_IFF_FRIEND'},{'FOE','F4MH_TD_IFF_FOE'},{'UKN','F4MH_TD_IFF_NONE'}}) do
    local label={fpm_transform=true,parent_element=flightRoot.name,
        params={item[2],'F4MH_BOX_X','F4MH_BOX_Y'}}
    text(item[1],0,26,nil,nil,label)
end
local tdLimit={fpm_transform=true,parent_element=flightRoot.name,limited=true,
    params={'F4MH_BOX_VALID','F4MH_BOX_X','F4MH_BOX_Y','F4MH_BOX_LIMIT'}}
line({{-3,-3},{3,3}},tdLimit);line({{-3,3},{3,-3}},tdLimit)
-- Reuse native LCOSS positioning; never invent an AIM-9 seeker tracking angle.
INDICATOR_LEVEL=HUD_DEFAULT_LEVEL
dofile(LockOn_Options.script_path..'Scripts/Common/common_defs.lua')
local function ccipCenter(parent)
 local dot=CreateElement 'ceMeshPoly';dot.material=material;dot.init_pos={0,0,0}
 local vertices,indices={{0,0}},{}
 for i=0,15 do local a=i*math.pi/8;vertices[#vertices+1]={1.8*math.cos(a),1.8*math.sin(a)} end
 for i=1,16 do local nextIndex=i%16+1;for _,v in ipairs({0,i,nextIndex,nextIndex,i,0}) do indices[#indices+1]=v end end
 dot.vertices=vertices;dot.indices=indices;return add(dot,parent)
end
-- One shared gun symbol for acquisition and tracking: 12.5 mil radius + solid center.
local function gunCue(parent)
 local ring={};for i=0,64 do local a=i*math.pi/32;ring[#ring+1]={12.5*math.cos(a),12.5*math.sin(a)} end
 line(ring,parent,1.5)
 local dot=CreateElement 'ceMeshPoly';dot.material=material;dot.init_pos={0,0,0}
 local vertices,indices={{0,0}},{}
 for i=0,15 do local a=i*math.pi/8;vertices[#vertices+1]={1.6*math.cos(a),1.6*math.sin(a)} end
 for i=1,16 do local nextIndex=i%16+1;for _,v in ipairs({0,i,nextIndex,nextIndex,i,0}) do indices[#indices+1]=v end end
 dot.vertices=vertices;dot.indices=indices;add(dot,parent)
end
local function nativeCue(parameter,isGun)
 local parent=gate(parameter)
 local anchor=my_create_textured_box_2k(0,0,2048,2048,1024,1024,37)
 anchor.material=MakeMaterial(nil,{0,0,0,0});anchor.init_pos={0,0,0}
 elementControllers[anchor]={{'hud_aircraft_reticle'}};anchor.change_opacity=false
 add(anchor,parent)
 if isGun then gunCue(anchor);return end
 local points={};local radius=35 -- user-requested 2x HEAT reference circle
 for i=0,64 do local a=i*2*math.pi/64;points[#points+1]={radius*math.cos(a),radius*math.sin(a)} end
 line(points,anchor)
 if isGun then line({{-4,0},{4,0}},anchor,.85);line({{0,-4},{0,4}},anchor,.85)
 end
end
nativeCue('F4MH_IR_CUE',false)
nativeCue('F4MH_GUN_LEAD',true)

local impact={fpm_transform=true,parent_element=flightRoot.name,params={'F4MH_CCIP_VALID','F4MH_CCIP_X','F4MH_CCIP_Y','F4MH_CCIP_LIMIT'}}
local impactCircle={};for i=0,64 do local a=i*2*math.pi/64;impactCircle[#impactCircle+1]={16*math.cos(a),16*math.sin(a)} end
line(impactCircle,impact);ccipCenter(impact)
line({{0,16},{0,25}},impact)
local impactLimit={fpm_transform=true,parent_element=flightRoot.name,limited=true,params=impact.params}
line({{-3,-3},{3,3}},impactLimit);line({{-3,3},{3,-3}},impactLimit)
text('CCIP DATA',0,-104,nil,nil,gate('F4MH_CCIP_MISSING'))
text('CCIP N/A',0,-104,nil,nil,gate('F4MH_CCIP_UNSUPPORTED'))
text('NO SOLN',0,-104,nil,nil,gate('F4MH_CCIP_NO_SOLUTION'))

text(nil,46,-112,'F4MH_RADAR_VC','VC %.0f',gate('F4MH_RADAR_VC_VALID'))
text('ACM',0,-112,nil,nil,gate('F4MH_ACM'),true)

-- Same symbol and stroke as the untracked native-position gun cue.
local gunTarget={fpm_transform=true,parent_element=flightRoot.name,
    params={'F4MH_GUN_SIGHT_VALID','F4MH_GUN_SIGHT_X','F4MH_GUN_SIGHT_Y'}}
gunCue(gunTarget)
local gunLimit={fpm_transform=true,parent_element=flightRoot.name,limited=true,
    params={'F4MH_GUN_SIGHT_VALID','F4MH_GUN_SIGHT_X','F4MH_GUN_SIGHT_Y','F4MH_GUN_SIGHT_LIMIT'}}
line({{-4,-4},{4,4}},gunLimit);line({{-4,4},{4,-4}},gunLimit)
text('GUN RNG',0,-94,nil,nil,gate('F4MH_GUN_RANGE'))
text('GUN NO SOL',0,-94,nil,nil,gate('F4MH_GUN_NO_SOLUTION'))
-- Bomb fall line, updated in angular HUD coordinates by the CCIP receiver.
for i=1,128 do
 local moving={fpm_transform=true,parent_element=flightRoot.name,
    params={'F4MH_CCIP_LINE_SHOW_'..i,'F4MH_CCIP_LINE_X_'..i,'F4MH_CCIP_LINE_Y_'..i}}
 line({{-.4,0},{.4,0}},moving,1.0)
end
text('SELECT WPN',0,-104,nil,nil,gate('F4MH_CCIP_NO_SELECTION'))
text('MIXED WPN',0,-104,nil,nil,gate('F4MH_CCIP_MIXED'))
for _,item in ipairs({{1,'LGB BAL'},{2,'GUN'},{3,'CCIP'},{4,'RKT'},{5,'MCLOS REF'}}) do
 text(item[2],0,-94,nil,nil,gate('F4MH_CCIP_WEAPON_'..item[1]))
end
