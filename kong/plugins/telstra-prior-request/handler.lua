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
  local url = require "socket.url"
  local data_json = {}

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

  local function val(value_str, source_json, urlencode)
    -- Replace {{value}} with the value from source_json.
    if not source_json or not value_str then
      return value_str
    end
    local val_return = value_str
    for item in value_str:gmatch("{{(.-)}}") do
      local key, value = item:match("^([^:]+):*(.-)$")
      if key and value and source_json[key] and source_json[key][value] then
        item=item:gsub('-','%%-')
        if urlencode then
          local encoded_value, _ = source_json[key][value]:gsub("([^%w%-%.%_%~])", function(c) return string.format("%%%%%02X", string.byte(c)) end)
          val_return = val_return:gsub("{{"..item.."}}", encoded_value)
        else
          val_return = val_return:gsub("{{"..item.."}}", source_json[key][value])
        end
      end
    end
    return val_return
  end
  
  -- Grab Headers from Request
  local req_headers, err = ngx.req.get_headers()
  if err then
    ngx.log(ngx.ERR, "Req Headers Read ERR: ", err)
  else
    data_json.req_headers = req_headers
  end
  -- Grab Query from Rrequest
  local req_query, err = ngx.req.get_uri_args()
  if err then
    ngx.log(ngx.ERR, "Req Query Parameter Read ERR: ", err)
  else
    data_json.req_query = req_query
  end
  -- Grab Json Body from Request if specified in Application/Json
  ngx.req.read_body()
  local req_body = ngx.req.get_body_data()
  if data_json.req_headers['Content-Type'] and data_json.req_headers['Content-Type']:lower() == 'application/json' then
    local status, req_body_json = pcall(cjson.decode, req_body)
    if status then
      data_json.req_body = req_body_json
    else
      ngx.log(ngx.ERR, "The user input request body:", req_body, " cannot be turned to json!")
      data_json.req_body = {}
    end
  end

  -- Make a prior call if not calling itself
  if config.prereq and config.prereq.url then
    local req_url_parse = url.parse(config.prereq.url)
    req_url_parse.port = req_url_parse.port or (req_url_parse.scheme == "http" and "80") or (req_url_parse.scheme == "https" and "443")
    local req_path = req_url_parse.path or "/"
    local ngx_path = ngx.var.uri:match('(/.-)/?$') or "/"
    if req_url_parse.host:lower() == ngx.var.host:lower() and req_path == ngx_path and req_url_parse.port==ngx.var.server_port then
      -- Avoid Self-Call: same host and same path and same port
      ngx.log(ngx.ERR, "CIRCLE: The prior API calls itself. ", config.prereq.url, " vs ", ngx.var.host, ngx.var.uri)
    else
      local httpc_headers = {}
      local httpc_query = {}
      local httpc_body = ""
      -- Set Pre-Request Headers: array to table
      if config.prereq and config.prereq.headers then
        setmetatable(httpc_headers, {__index=function(table, key) if rawget(table, key:lower()) then return table[key:lower()]end end})
        for _, name, value in iter(config.prereq.headers) do
          if name then
            httpc_headers[name] = val(value, data_json)
          end
        end
      end
      -- Set Pre-Request Query
      if config.prereq and config.prereq.query then
        for _, name, value in iter(config.prereq.query) do
          if name then
            httpc_query[name] = val(value, data_json)
          end
        end
      end
      -- Set Pre-Request Body if it is not nil
      if config.prereq and config.prereq.body then
        if httpc_headers["Content-Type"] == "application/x-www-form-urlencoded" then
          httpc_body = val(config.prereq.body, data_json, true)
        else
          httpc_body = val(config.prereq.body, data_json)
        end
      end

      -- Call Prior Server
      local res, err = httpc:request_uri(config.prereq.url, {
        method = config.prereq.http_method or "POST",
        ssl_verify = config.prereq.ssl_verify or false,
        headers = httpc_headers,
        query = httpc_query,
        body = httpc_body
      })
      if err then
        ngx.log(ngx.ERR, "ERR: ", err)
      else
        data_json.res_headers = res.headers
        if data_json.res_headers['Content-Type'] and data_json.res_headers['Content-Type']:lower() == 'application/json' then
          local res_status, res_body_json = pcall(cjson.decode, res.body)
          if res_status then
            data_json.res_body = res_body_json
          else
            data_json.res_body = {}
          end   
        end
      end
      --LOGING
      --ngx.log(ngx.ERR, "RESPONCE_BODY: ", res.body)
    end
  end

  -- Set Request Headers: not touch existing ones
  if config.request and config.request.headers then
    for _, name, value in iter(config.request.headers) do
      ngx.req.set_header(name, val(value, data_json))
    end
  end
  -- Set Request Query: not touch existing ones
  if config.request and config.request.query then
    local new_query = ngx.req.get_uri_args()
    for _, name, value in iter(config.request.query) do
      new_query[name] = val(value, data_json)
    end
    ngx.req.set_uri_args(new_query)
  end
  -- Set Body: completely overwrite existing body
  if config.request and config.request.body then
    if ngx.req.get_headers()["Content-Type"] == "application/x-www-form-urlencoded" then
      ngx.req.set_body_data(val(config.request.body, data_json, true))
    else
      ngx.req.set_body_data(val(config.request.body, data_json))
    end
  end
end


PriorReqFunction.PRIORITY = 999
PriorReqFunction.VERSION = "0.1.0"


return PriorReqFunction
