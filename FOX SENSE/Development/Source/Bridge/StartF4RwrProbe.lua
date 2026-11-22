local Probe = require 'F4RwrProbe'
mod_init[#mod_init + 1] = function(jester)
    jester.behaviors[Probe] = Probe:new()
end
