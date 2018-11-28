# Build for Kong Customized Plugin: Telstra Prior Request
Written by Dr. Xiaoming (Raymond) Zheng in November 2018

## Functionality:
This plugin can make an additional prior API call(named middle-call) when the configured service (named service-call) is called.
The middle-call can accepts variables from both headers and body of service-call.
The service-call can accepts variables from both headers and body of the reponse of middle-call.

## Use Case:
Taking Telstra notification API for example, when an end user/agent calls the notification platform to send out a short message, this plugin will call the token server first, grab the returned asscess token from response and insert into the headers of the call to the notification. 

## Pre-requisites:
- [Lua](https://www.lua.org/) >= 5.1
- [LuaRocks](https://luarocks.org/) >=2.4.3
- [Kong](https://konghq.com/) >= 0.33
- [OpenResty](https://openresty.org/) >= 1.13.6.2
- [Nginx](https://nginx.org/) >= 1.13.11

## Installation:
- Download the package file kong-plugin-telstra-prior-request-0.1.0-0.all.rock
-  ```luarock install kong-plugin-telstra-prior-request-0.1.0-0.all.rock```
-  Change 'custom_plugins' in Kong configration file
-  Restart Kong daemon
-  Log into Kong Admin Dashboard and click 'New Plugin' under plade 'Plugins'
-  Find the plugin, fill the parameters and finish the configuration.
-  The plugin is ready to act.

## Uninstallation:
-  Remove all configuration of this plugin in Admin Dashboard
-  Remove this plugin from 'custom_plugins' in Kong configration file
-  ```luarocks remove kong-plugin-telstra-prior-request```
-  Restart Kong daemon

## Variable Format:
When configuring this plugin in Kong Admin Dashboard, variables from 4 sources( both headers and body of request of service-call and response of middle-call: req_headers, req_body, res_headers and res_body) can be used. 
However the rules below apply:
- Variables must follow the format '{{KEY:VALUE}}'(quotation marks here and below are not included).
- The available 'KEY' are 'req_body', 'res_body', 'req_headers', and 'req_headers'.
- 'VALUE' is case-insensitive when 'KEY' is 'req_headers' or 'res_headers' following HTTP standards.
- 'VALUE' is case-sensitive when 'KEY' is 'req_body' or 'res_body'.
- 'req_body' is only available when 'content-type:application/json' is in 'req_headers'.
- 'req_body' and 'res_body' must be json-formatted string and only one level variables can be used.
- 'res_body' and 'res_headers' are only available for service-call.

## Attenttion:
-  Compare the PRIORITY number with other plugins carefully, which determine the order of plugin running
-  Not obeying the order in installation will cause the failure of Kong start
-  Not obeying the order in uninstallation will fail Kong
-  User input error precaution has not been developed yes in Lua code.
