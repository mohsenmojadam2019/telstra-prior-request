-- Updated on 28May2019 by Dr. Xiaoming Zheng (Raymond)

local find = string.find
local url = require "socket.url"

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

local function check_url(value)
  if not value then
    return true
  end
  local url_parse, err = url.parse(value)
  if err then
    return false, "URL input error: "..err
  end
  if not url_parse.scheme then
    return false, "URL input error: no scheme!"
  end
  if not url_parse.host then
    return false, "URL input error: no host!"
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
local typedefs = require "kong.db.schema.typedefs"
return {
  name = "telstra-prior-request",
  fields = {
    { run_on = typedefs.run_on_first },
    { config = {
      type = "record",
      fields = {
        { upstream_path_append = {type = "string", custom_validator = check_path},},
        { debug = {type = "boolean", default = false},},
        { prereq = {
          type = "record",
          fields = {
            { url = {type = "string", custom_validator = check_url},},
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
