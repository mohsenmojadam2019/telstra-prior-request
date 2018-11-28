package = "telstra-prior-request"
version = "1.0-1"
local pluginName = package:match("^kong%-plugin%-(.+)$") --telstra-prior-request
supported_platforms = {"linux"}
source = {
  url = "https://github.com/siaomingjeng/ozfriend.git"  -- TBC
}
description = {
  summary = "An example for the LuaRocks tutorial.",
  detailed = [[
    This is an example for the LuaRocks tutorial.
    Here we would put a detailed, typically
    paragraph-long description.
  ]],
  homepage = "http://...", -- We don't have one yet
  license = "MIT/X11" 
}
dependencies = {
  "lua >= 5.1, < 5.4"
}
build = {
  type = "builtin",
   modules = {
    ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
    ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
  }
}