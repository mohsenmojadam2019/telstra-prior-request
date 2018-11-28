local find = string.find
-- entries must have colons to set the key and value apart
local function check_for_value(value)
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

return {
  fields = {
    prereq = {
      type = "table",
      schema = {
        fields = {
          url = {type = "string", required = true, default  = "https://allinone.non-prod.telstrahealth.com:8443/token"},
          http_method = {type = "string", default = "POST"},
          body = {type = "string", default = "client_id=FQXrZSMiD4alV7clZfCKmSyG0QlHVpr8&grant_type=client_credentials&scope=NOTIFICATION-MGMT&client_secret=2K6HYyi70BjUEyTY"},
          headers = {type = "array", default = "Content-Type:application/x-www-form-urlencoded", func = check_for_value},
          ssl_verify = {type = "boolean", default = false}
        }
      }
    },
    request = {
      type = "table",
      schema = {
        fields = {
          body = {type = "string"},
          headers = {type = "array", default = "Authorization:Bearer {{res_body:access_token}},Content-Type:application/json", func = check_for_value}
        }
      }
    }
  }
}
