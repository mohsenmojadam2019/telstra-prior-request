-- Written by Dr. Xiaoming (Raymond) Zheng  in November 2018 
-- Instert another call a header of the service call
-- Able to use variables from headers and body.

local BasePlugin = require "kong.plugins.base_plugin"
local PriorReqFunction = BasePlugin:extend()


function PriorReqFunction:new()
  PriorReqFunction.super.new(self, "Telstra Prior Request")
end


function PriorReqFunction:access(config)
  PriorReqFunction.super.access(self)

  local cjson = require "cjson"
  local http = require "resty.http"
  local httpc = http.new()
  local httpc_headers = {}
  local res_json = {}
  local req_json = {}

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
    if not source_json then
      return value_str
    end
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
  local req_headers, err = ngx.req.get_headers()
  if err then
    ngx.log(ngx.ERR, "Req Headers Read ERR: ", err)
  else
    req_json.req_headers = req_headers
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

  -- Make a prior call if not calling self
  local req_url = config.prereq.url:match('^https?://([^?&=]+)/?') or ""
  local req_host = req_url:match('[^:?&=/]+') or ""
  local req_path = req_url:match('(/.-)/?$') or "/"
  local ngx_path = ngx.var.uri:match('(/.-)/?$') or "/"
  if req_host:lower() == ngx.var.host:lower() and req_path == ngx_path then
    -- Avoid self-call
    ngx.log(ngx.ERR, "CIRCLE: The prior API calls itself. ", config.prereq.url, " vs ", ngx.var.host, ngx.var.uri)
  else
    -- Call Prior Server
    for _, name, value in iter(config.prereq.headers) do
      if name then
        httpc_headers[name] = value
      end
    end
    local res, err = httpc:request_uri(config.prereq.url, {
      method = config.prereq.http_method or "POST",
      ssl_verify = config.prereq.ssl_verify or false,
      headers = httpc_headers,
      body = config.prereq.body or ""
    })
    if err then
      ngx.log(ngx.ERR, "ERR: ", err, res.body)
    else
      res_json.res_headers = res.headers
      res_json.res_body = cjson.decode(res.body)
    end
  
    --LOGING
    --ngx.log(ngx.ERR, "RESPONCE_BODY: ", res.body)
  end

  for _, name, value in iter(config.request.headers) do
    ngx.req.set_header(name, val(value, res_json))
  end
  if config.request.body then
    ngx.req.set_body_data(config.request.body)
  end
end


PriorReqFunction.PRIORITY = 999
PriorReqFunction.VERSION = "0.1.0"


return PriorReqFunction
