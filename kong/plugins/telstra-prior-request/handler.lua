-- Written by Dr. Raymond Zheng  in November 2018 
-- for Notification to merge two  API Calls into one

local BasePlugin = require "kong.plugins.base_plugin"
local TestFunction = BasePlugin:extend()
local cjson = require "cjson"


function TestFunction:new()
  TestFunction.super.new(self, "Telstra Prior Request")
end


function TestFunction:access(config)
  TestFunction.super.access(self)

  local function iter(config_array)
    return function(config_array, i)
      i = i + 1
      local current_pair = config_array[i]
      if current_pair == nil then -- n + 1
        return nil
      end
      local current_name, current_value = current_pair:match("^([^:]+):*(.-)$")
      if current_value == "" then
        current_value = nil
      end
      return i, current_name, current_value
    end, config_array, 0
  end

  local function val(value_str, source_json)
    -- replace {{value}} with the value from source_json
    local val_return = value_str
    for item in value_str:gmatch("{{(.-)}}") do
      local key, value = item:match("^([^:]+):*(.-)$")
      if key and value and source_json[key] and source_json[key][value] then
        item=item:gsub('-','%%-')
        val_return = val_return:gsub("{{"..item.."}}",source_json[key][value])
      end
    end
    return val_return
  end
  
  -- Grab headers from request
  local req_json={} err=nil
  req_json.req_headers, err = ngx.req.get_headers()
  if err then
    ngx.log(ngx.ERR, "Req Headers Read ERR: ", err)
  end

  -- Grab body from request if specified in Application/Json
  ngx.req.read_body()
  local req_body = ngx.req.get_body_data()
  if req_json.req_headers['content-type'] and req_json.req_headers['content-type']:lower() == 'application/json' then
    local status, req_body_json = pcall(cjson.decode, req_body)
    if status then
      req_json.req_body = req_body_json
    else
      ngx.log(ngx.ERR, "The user input body:", req_body, " cannot be turned to json!")
      req_json.req_body = {}
    end
  end

  -- Replace header variables
  for name, value in ipairs(config.prereq.headers) do
    if (value:match('{{.*:.*}}')) then
      config.prereq.headers[name] = val(value, req_json)
    end
  end
  
  -- Replace body variables
  if config.prereq.body and config.prereq.body:match('{{.*:.*}}') then
    config.prereq.body = val(config.prereq.body, req_json)
  end

  -- Call Prior Server
  local http = require "resty.http"
  local httpc = http.new()
  local httpc_headers = {}
  for _, name, value in iter(config.prereq.headers) do
    if name then
      httpc_headers[name]=value
    end
  end
  local res, err = httpc:request_uri("https://allinone.non-prod.telstrahealth.com:8443/token", {
    method = config.prereq.http_method or "POST",
    ssl_verify = config.prereq.ssl_verify or false,
    headers = httpc_headers,
    body = config.prereq.body or ""
  })
  if err then
    ngx.log(ngx.ERR, "ERR: ", err, res.body)
  end

  local res_json = {}
  res_json.res_headers = res.headers
  res_json.res_body = cjson.decode(res.body)

  --LOGING
  ngx.log(ngx.ERR, "RESPONCE_BODY: ", res.body)

  for _, name, value in iter(config.request.headers) do
    ngx.req.set_header(name, val(value, res_json))
  end
  if config.request.body then
    ngx.req.set_body_data(config.request.body)
  end
end


TestFunction.PRIORITY = 999
TestFunction.VERSION = "0.1.0"


return TestFunction
