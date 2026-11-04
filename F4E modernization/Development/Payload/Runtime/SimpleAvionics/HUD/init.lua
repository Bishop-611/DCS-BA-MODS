-- Preserve native combiner mask, collimation, power and brightness page selection.
dofile(LockOn_Options.script_path..'Scripts/HeadUpDisplay/Indicator/init.lua')
page_subsets[20]=[[__F4_RUNTIME__/HUD/page.lua]]
pages[2]={BASE,20}
