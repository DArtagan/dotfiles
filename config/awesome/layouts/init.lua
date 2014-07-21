
--[[
                                                   
     Layouts, widgets and utilities for Awesome WM 
                                                   
     Licensed under GNU General Public License v2  
      * (c) 2013, Luke Bonham                      
                                                   
--]]
local wrequire     = require("lain.helpers").wrequire
local setmetatable = setmetatable

local layout       = { _NAME = "layouts" }

return setmetatable(layout, { __index = wrequire })
