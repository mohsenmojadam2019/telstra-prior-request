-- Written by Dr. Xiaoming Zheng (Raymond) in February 2019.
-- Updated by Dr. Xiaoming Zheng (Raymond) in May 2021.
-- Instert another call ahead of the service call
-- and grab information from response to insert into current call.
-- Able to use variables from headers and body and query.

local BasePlugin = require "kong.plugins.base_plugin"
local lsyslog = require "lsyslog"
local response = kong.response
local PriorReqFunction = BasePlugin:extend()
local ngx = ngx

-- log into syslog: serverity=notice/err
local log_level = "NOTICE"
local function send_to_syslog(severity, message)
  local function syslog(premature, sev, msg)
    if premature then
      return
    end
    lsyslog.open("KONGP", lsyslog.FACILITY_USER)
    lsyslog.log(lsyslog["LOG_"..string.upper(sev)], msg)
  end
  local ok, err = ngx.timer.at(0, syslog, severity, message)
  if not ok then
    ngx.log(ngx.ERR, "LOG_ERROR: failed to create timer: ", err)
  end
end


local function table_to_string(tbl)
  if type(tbl) == "table" then
    local result = ""
    for k, v in pairs(tbl) do
      result = result..k..": "..table_to_string(v)..", "
    end
    if result ~= "" then
      result = result:sub(1, result:len()-2)
    end
    return "{"..result.."}"
  elseif type(tbl) == "boolean" or type(tbl) == "number" or type(tbl) == "nil" or type(tbl) == "string" then
    return tostring(tbl)
  else
    return "<"..type(tbl)..">"
  end
end

function PriorReqFunction:new()
  PriorReqFunction.super.new(self, "Telstra Prior Request")
end

function PriorReqFunction:access(config)
  PriorReqFunction.super.access(self)

  local cjson = require "cjson.safe"
  local http = require "resty.http"
  local httpc = http.new()
  local url = require "socket.url"
  local data_json = {}

  local function iter(config_array)
    return function(cfg_array, i)
      i = i + 1
      local current_pair = cfg_array[i]
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
        item=item:gsub('-', '%%-')
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

  local function err_exit(err, err_loc, err_code, others, content_type)
    if err then
      err_loc = err_loc or "access"
      err_code = err_code or 400
      ngx.log(ngx.ERR, "ERROR_EXIT, CODE: ", table_to_string(err_code), ", ERR_LOCATION: ", table_to_string(err_loc), ", ERROR: ", table_to_string(err), ". OTHERS, ", table_to_string(others))
      return response.exit(err_code, content_type and err or "{\"msg\": \""..err.."\"}", {["Error_Location"] = err_loc, ["Kong-Plugin"]="telstra-prior-request", ["Content-Type"]=content_type or "application/json"})
    end
  end

  -- Grab Headers from Request
  local req_headers, err_h = ngx.req.get_headers()
  if err_h then
    ngx.log(ngx.ERR, "Req Headers Read ERR: ", err_h)
  else
    data_json.req_headers = req_headers
  end
  -- Grab Query from Rrequest
  local req_query, err_u = ngx.req.get_uri_args()
  if err_u then
    ngx.log(ngx.ERR, "Req Query Parameter Read ERR: ", err_u)
  else
    data_json.req_query = req_query
  end
  -- Grab Json Body from Request if specified in Headers as Application/Json
  ngx.req.read_body()
  local req_body = ngx.req.get_body_data()
  if req_body and data_json.req_headers['Content-Type'] and data_json.req_headers['Content-Type']:lower():match('application/json') then
    local req_body_json, e = cjson.decode(req_body)
    err_exit(e, "req_body_decode_err", 400, " RAW_REQ_BODY: "..table_to_string(req_body))
    data_json.req_body = req_body_json or {}
  end
  -- Debug Mode Part 1: Before Request
  if config.debug then
    log_level = "NOTICE"
    local msg = "PLUGIN_DEBUG_MODE@ORIGIONAL_REQUEST, body: "..tostring(req_body)..", uri: "..tostring(ngx.var.uri)..", headers: "..table_to_string(req_headers)..
      ", query: "..table_to_string(req_query)
    send_to_syslog(log_level, msg)
  end
  -- Check whether it is a self-call circle.
  if config.prereq and config.prereq.url then
    local req_url_parse = url.parse(config.prereq.url)
    req_url_parse.port = req_url_parse.port or (req_url_parse.scheme == "http" and "80") or (req_url_parse.scheme == "https" and "443")
    local req_path = req_url_parse.path or "/"
    local ngx_path = ngx.var.uri:match('(/.-)/?$') or "/"
    -- Avoid Self-Call: same host and same path and same port
    if req_url_parse.host:lower() == ngx.var.host:lower() and req_path == ngx_path and req_url_parse.port==ngx.var.server_port then
      err_exit("the prior API calls itself", "pre_req_url_err", 400, "config_prereq_url: "..config.prereq.url.." ngx.var.host: "..ngx.var.host.." ngx.var.uri: "..ngx.var.uri)
    end
    ---- directly use ngx.shared.DICT for memory caching.
    local db_cache, pre_res_cache, pre_res

    if config.prereq.cache_ttl > 0 then
      db_cache = ngx.shared["kong_db_cache"]
      pre_res_cache = db_cache:get("PRIOR_CACHE") -- flags not care. Return nil if it does not exist or has expired.
    end
    if db_cache and pre_res_cache then
      local pre_res_cache_decoded, decode_err=cjson.decode(pre_res_cache)
      err_exit(decode_err, "pre_res_cache_decode_err", 400, "RAW_RESPONSE: "..table_to_string(pre_res_cache))
      pre_res=pre_res_cache_decoded
    else
      -- Prepare the parameters used for pre-request call.
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
      -- Translate variables in url
      local httpc_url = val(config.prereq.url, data_json, true)
      -- Get other parameters
      local httpc_method = config.prereq.http_method or "POST"
      local httpc_ssl_verify = config.prereq.ssl_verify or false
      -- Debug Mode Part 2: Before Pre-Request
      if config.debug then
        local msg = "PLUGIN_DEBUG_MODE@PRIOR_REQUEST, url: "..httpc_url..", body: "..tostring(httpc_body)..", headers: "..table_to_string(httpc_headers)..
          ", query: "..table_to_string(httpc_query)..", method: "..httpc_method..", ssl_verify: "..tostring(httpc_ssl_verify)
        send_to_syslog(log_level, msg)
      end
      -- Call Prior Server
      local res_p, err_p = httpc:request_uri(httpc_url, {method = httpc_method, ssl_verify = httpc_ssl_verify, headers = httpc_headers, query = httpc_query, body = httpc_body})
      err_exit(err_p, "pre_httpc_err", 400, "PRE_REQ_URL: "..httpc_url..", PRE_REQ_BODY: "..httpc_body..", PRE_REQ_HEADERS: "..table_to_string(httpc_headers)..", PRE_REQ_QUERY: "..table_to_string(httpc_query)..", PRE_REQ_METHOD: "..httpc_method..", PRE_REQ_SSL_VERIFY: "..tostring(httpc_ssl_verify))
      pre_res = res_p

      -- Debug Mode Part 3: After Pre-Request
      if config.debug then
        local msg = "PLUGIN_DEBUG_MODE@PRIOR_RESPONSE"..", response: "..table_to_string(pre_res)
        send_to_syslog(pre_res.status >= 400 and "ERR" or log_level, msg)
      end
      -- LOG and Stop: when reponse status contains error
      if pre_res.status < 200 or pre_res.status > 299 then
        err_exit(pre_res.body or "response Header 'Content-Type' is missing or not 'application/json'", "pre_res_status_err", pre_res.status, "PRE_RES: "..pre_res.status, pre_res.headers['Content-Type'])
      end
      -- LOG and Stop: when response header "Content-Type" is not "application/json".
      if not (pre_res.headers['Content-Type'] and pre_res.headers['Content-Type']:lower():match('application/json')) then
        err_exit(pre_res.body or "response Header 'Content-Type' is missing or not 'application/json'", "pre_res_content_type_err", 400, "PRE_RES_STATUS: "..pre_res.status..", PRE_RES_HEADERS: "..table_to_string(pre_res.res_headers), pre_res.headers['Content-Type'])
      end

      -- Write Cache. "db_cache" will be nil if config.prereq.cache_ttl<=0
      if db_cache then
        local res_to_cache = {headers=pre_res.headers, body=pre_res.body, status=pre_res.status}
        local val_cache, encode_err = cjson.encode(res_to_cache)
        err_exit(encode_err, "pre_res_cache_encode_err", 400, "RES_TO_CACHE: "..table_to_string(res_to_cache))
        if val_cache then
          local succ, set_err, _ = db_cache:set("PRIOR_CACHE", val_cache, config.prereq.cache_ttl)
          err_exit(set_err, "pre_cache_set_err", 400, "VAL_TO_CACHE: "..table_to_string(val_cache))
          err_exit(not succ, "pre_cache_set_res_err", 400, "VAL_TO_CACHE: "..table_to_string(val_cache))
        else
          err_exit("No input value to cache.", "pre_res_cache_encode_output_err", 400, "RES_TO_CACHE: "..table_to_string(res_to_cache))
        end
      end
    end

    -- Load res into data_json.
    data_json.res_headers = pre_res.headers
    data_json.status = pre_res.status or 400
    local res_body_json, e = cjson.decode(pre_res.body)
    err_exit(e, "pre_res_body_decode_err", 400, " RAW_BODY: "..table_to_string(pre_res.body))
    data_json.res_body = res_body_json or {}
  end

  -- Set Request Related Params
  if config.request then
    -- Set Request Headers: not touch existing ones
    if config.request.headers then
      for _, name, value in iter(config.request.headers) do
        ngx.req.set_header(name, val(value, data_json))
      end
    end
    -- Set Request Query: not touch existing ones
    if config.request.query then
      local new_query = ngx.req.get_uri_args()
      for _, name, value in iter(config.request.query) do
        new_query[name] = val(value, data_json)
      end
      ngx.req.set_uri_args(new_query)
    end
    -- Set Body: completely overwrite existing body
    if config.request.body then
      if ngx.req.get_headers()["Content-Type"] == "application/x-www-form-urlencoded" then
        ngx.req.set_body_data(val(config.request.body, data_json, true))
      else
        ngx.req.set_body_data(val(config.request.body, data_json))
      end
    end
  end

  -- Set Appended Upstream URI
  if config.upstream_path_append then
    if ngx.var.upstream_uri:sub(-1) == '/' then
      ngx.var.upstream_uri = ngx.var.upstream_uri..val(config.upstream_path_append, data_json)
    else
      ngx.var.upstream_uri = ngx.var.upstream_uri.."/"..val(config.upstream_path_append, data_json)
    end
  end

  -- Debug Mode Part 4: Final Request
  if config.debug then
    local msg = "PLUGIN_DEBUG_MODE@FINAL_REQUEST, body: "..tostring(ngx.req.get_body_data())..", uri: "..tostring(ngx.var.uri)..", headers: "..table_to_string(ngx.req.get_headers())..
      ", query: "..table_to_string(ngx.req.get_uri_args())
    send_to_syslog(log_level, msg)
  end
end

function PriorReqFunction:body_filter(config)
  PriorReqFunction.super.body_filter(self)
  local chunk, eof = ngx.arg[1], ngx.arg[2]
  -- Debug Mode Part 5: Final Response
  if config.debug then
    local msg = "PLUGIN_DEBUG_MODE@FINAL_RESPONSE@CHUNK"..", body: "..chunk..", headers: "..table_to_string(ngx.resp.get_headers())..
      ", EOF: "..tostring(eof)..", status: "..tostring(ngx.status)
    send_to_syslog(ngx.status >= 400 and "ERR" or log_level, msg)
  end
end

PriorReqFunction.PRIORITY = 666
PriorReqFunction.VERSION = "1.0.1"


return PriorReqFunction
