local find = string.find
local url = require "socket.url"
-- entries must have colons to set the key and value apart
local function check_for_value(value)
  if not value then
    return true
  end
  for i, entry in ipairs(value) do
    local ok = find(entry, ":")
    if not ok then
      return false, "key '" .. entry .. "' has no value"
    end
  end
  return true
end

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

return {
  fields = {
    prereq = {
      type = "table",
      schema = {
        fields = {
          url = {type = "string", func = check_url},
          http_method = {type = "string", default = "POST", func = check_method},
          body = {type = "string"},
          query = {type = "array", func = check_for_value},
          headers = {type = "array", func = check_for_value},
          ssl_verify = {type = "boolean", default = false}
        }
      }
    },
    request = {
      type = "table",
      schema = {
        fields = {
          body = {type = "string"},
          query = {type = "array", func = check_for_value},
          headers = {type = "array", func = check_for_value}
        }
      }
    }
  }
}
