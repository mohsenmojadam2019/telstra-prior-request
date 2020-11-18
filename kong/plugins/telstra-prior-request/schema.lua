-- Updated on 18Nov2020 by Dr. Xiaoming Zheng (Raymond)
local typedefs = require "kong.db.schema.typedefs"

local function check_method(value)
  if not value then
    return true
  end
  local method = value:upper()
  local ngx_method = ngx["HTTP_" .. method]
  if not ngx_method then
    return false, method .. " is not supported"
  end
  return true
end

local function check_path(value)
  if not value then
    return true
  end
  if value:sub(1,1) == "/" then
    return false, "Cannot start with /"
  end
  return true
end

local colon_strings_array = {
  type = "array",
  default = {},
  elements = { type = "string", match = "^[^:]+:.*$"},
}
return {
  name = "telstra-prior-request",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
      type = "record",
      fields = {
        { upstream_path_append = {type = "string", custom_validator = check_path},},
        { debug = {type = "boolean", default = false},},
        { prereq = {
          type = "record",
          fields = {
            { url = typedefs.url },
            { http_method = {type = "string", default = "POST", custom_validator = check_method},},
            { body = {type = "string"},},
            { query = colon_strings_array,},
            { headers = colon_strings_array,},
            { ssl_verify = {type = "boolean", default = false},},
            { show_reponse = {type = "boolean", default = false},},
            },
        },},
        {request = {
          type = "record",
          fields = {
            {body = {type = "string"},},
            {query = colon_strings_array,},
            {headers = colon_strings_array,},
            },
        },}
      },
    },},
  },
}
