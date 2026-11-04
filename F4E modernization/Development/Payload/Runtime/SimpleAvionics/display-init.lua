dofile(LockOn_Options.common_script_path..'devices_defs.lua')
indicator_type=indicator_types.COMMON
purposes={render_purpose.SCREENSPACE_INSIDE_COCKPIT,render_purpose.HUD_ONLY_VIEW}
page_subsets={[1]=[[__F4_RUNTIME__/display-page.lua]]}
pages={[1]={1}}
init_pageID=1
-- Screen-space elements use the main screen coordinates, not dedicated_viewport.
-- The page explicitly scales geometry, text and controller translations together.
screenspace_scale=1
log.write('F4_SIMPLE_DISPLAY',log.INFO,'B_SCOPE_SCREENSPACE_V3; explicitly bounded lower-left panel, 40NM / +/-60 degrees')
