-- Same native ccRadar subset entry used by the project's modern HUD.
-- Keep native compositor, geometry and TV indicators; do not replace the failed final bake pass.
dofile(LockOn_Options.script_path..'Scripts/DSCG/indicator/init.lua')
local page=[[__F4_RUNTIME__/Controls/display-cockpit-page.lua]]
page_subsets[OFF]=page
page_subsets[RADAR]=page
log.write('F4_SIMPLE_DISPLAY',log.INFO,'COCKPIT_DSCG_SUBSETS installed; native physical screen visibility requires verification')
