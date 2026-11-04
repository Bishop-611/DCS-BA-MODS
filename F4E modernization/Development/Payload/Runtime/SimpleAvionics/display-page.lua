dofile(LockOn_Options.common_script_path..'elements_defs.lua')
SetCustomScale(1.0)
local panel_scale=.32
local aspect=LockOn_Options.screen.aspect or (LockOn_Options.screen.width/LockOn_Options.screen.height)
local window=CreateElement 'ceSimple'
window.name='F4_SR_WINDOW_ROOT'
window.init_pos={-aspect+panel_scale+.04,-1+panel_scale+.04,0}
window.screenspace=ScreenType.SCREENSPACE_TRUE
Add(window)
local green=MakeMaterial(nil,{50,255,90,255})
local dim=MakeMaterial(nil,{25,145,55,255})
local black=MakeMaterial(nil,{0,8,3,240})
local font=MakeFont({used_DXUnicodeFontData='font_cockpit_rus_2'},{50,255,90,255})
local serial=0
local function add(e,parent)
    serial=serial+1;e.name='F4_SR_ELEMENT_'..serial
    e.isdraw=true;e.isvisible=true;e.additive_alpha=false;e.use_mipfilter=false
    e.screenspace=ScreenType.SCREENSPACE_TRUE
    e.parent_element=(parent or window).name
    Add(e);return e
end
local function mesh(vertices,indices,material)
    local e=CreateElement 'ceMeshPoly'
    local scaled={}
    for _,v in ipairs(vertices) do scaled[#scaled+1]={v[1]*panel_scale,v[2]*panel_scale} end
    e.primitivetype='triangles';e.vertices=scaled;e.indices=indices;e.material=material
    e.init_pos={0,0,0};return e
end
local function line(points,material,width,parent)
    local verts,indices={},{}
    for i=1,#points-1 do
        local a,b=points[i],points[i+1]
        local dx,dy=b[1]-a[1],b[2]-a[2]
        local length=math.sqrt(dx*dx+dy*dy)
        local nx,ny=-dy/length*(width or .003),dx/length*(width or .003)
        local n=#verts
        for _,v in ipairs({{a[1]+nx,a[2]+ny},{b[1]+nx,b[2]+ny},{b[1]-nx,b[2]-ny},{a[1]-nx,a[2]-ny}}) do verts[#verts+1]=v end
        for _,v in ipairs({n,n+1,n+2,n,n+2,n+3,n+2,n+1,n,n+3,n+2,n}) do indices[#indices+1]=v end
    end
    local e=mesh(verts,indices,material or green)
    return add(e,parent)
end
local function text(value,x,y,param,format,gate,lower,upper,size)
    local e=CreateElement 'ceStringPoly';e.material=font;e.init_pos={x*panel_scale,y*panel_scale,0}
    local font_scale=size or 1
    e.alignment='CenterCenter';e.stringdefs={.0095*panel_scale*font_scale,.0064*panel_scale*font_scale,0,0}
    local params,controllers={},{}
    if param then params[1]=param;e.formats={format or '%.0f'};controllers[#controllers+1]={'text_using_parameter',0,0}
    else e.value=value end
    if gate then params[#params+1]=gate;controllers[#controllers+1]={'parameter_in_range',#params-1,lower,upper} end
    if #params>0 then e.element_params=params;e.controllers=controllers end
    return add(e)
end
add(mesh({{-1,-1},{1,-1},{1,1},{-1,1}},{0,1,2,0,2,3,2,1,0,3,2,0},black))
line({{-.72,-.82},{.72,-.82},{.72,.58},{-.72,.58},{-.72,-.82}})
for _,x in ipairs({-.36,0,.36}) do line({{x,-.82},{x,.58}},dim,.003) end
for _,y in ipairs({-.47,-.12,.23}) do line({{-.72,y},{.72,y}},dim,.003) end
text('A/A',-.60,.88)
text(nil,.56,.88,'F4_SR_RANGE_MAX_NM','%.0f NM')
for _,item in ipairs({{0,'OFF'},{1,'SRCH'},{2,'ACQ'},{3,'STT'}}) do
    text(item[2],0,.88,nil,nil,'F4_SR_MODE',item[1]-.1,item[1]+.1)
end
for i=1,4 do text(nil,-.89,-.82+i*.35,'F4_SR_SCALE_'..i,'%g',nil,nil,nil,.65) end
for i=-2,2 do text(tostring(i*30),i*.36,.70) end
local function moving(show,x,y)
    local e=CreateElement 'ceSimple';e.init_pos={0,0,0}
    e.element_params={show,x,y}
    e.controllers={{'parameter_in_range',0,.5,1.5},{'move_left_right_using_parameter',1,panel_scale},{'move_up_down_using_parameter',2,panel_scale}}
    return add(e)
end
for i=1,32 do
    local root=moving('F4_SR_C'..i..'_SHOW','F4_SR_C'..i..'_X','F4_SR_C'..i..'_Y')
    line({{-.023,0},{.023,0}},green,.006,root)
end
local tdc=moving('F4_SR_TDC_SHOW','F4_SR_TDC_X','F4_SR_TDC_Y')
line({{-.035,-.027},{-.035,.027}},green,.003,tdc)
line({{.035,-.027},{.035,.027}},green,.003,tdc)
local locked=moving('F4_SR_STT_SHOW','F4_SR_STT_X','F4_SR_STT_Y')
line({{-.045,-.022},{-.045,-.045},{-.022,-.045}},green,.003,locked)
line({{.022,-.045},{.045,-.045},{.045,-.022}},green,.003,locked)
line({{.045,.022},{.045,.045},{.022,.045}},green,.003,locked)
line({{-.022,.045},{-.045,.045},{-.045,.022}},green,.003,locked)
line({{-.012,0},{.012,0}},green,.006,locked)
local range_index=CreateElement 'ceSimple'
range_index.init_pos={0,0,0}
-- The range index translates only vertically, along the right edge.
range_index.element_params={'F4_SR_STT_SHOW','F4_SR_STT_Y'}
range_index.controllers={{'parameter_in_range',0,.5,1.5},{'move_up_down_using_parameter',1,panel_scale}}
add(range_index)
line({{.85,-.022},{.80,0},{.85,.022}},green,.003,range_index)
line({{.85,-.82},{.85,.58}},dim,.002)
text(nil,-.30,-.94,'F4_SR_RANGE_NM','R %.1f','F4_SR_INFO_VALID',.5,1.5,.85)
text(nil,.34,-.94,'F4_SR_CLOSURE_KT','VC %.0f','F4_SR_CLOSURE_VALID',.5,1.5,.85)
-- Compact identification at the margin, never a large banner below the plot.
text('FR',.80,-.91,nil,nil,'F4_SR_FRIENDLY',.9,1.1,.65)
text('UN',.80,-.91,nil,nil,'F4_SR_FRIENDLY',-.1,.1,.65)
text('ACM',0,.35,nil,nil,'F4_SR_ACM',.9,1.1,1.65)
log.write('F4_SIMPLE_DISPLAY',log.INFO,'B_SCOPE_PAGE loaded; actual search returns and STT only')
