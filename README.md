# Build for Kong Customized Plugin: Telstra Prior Request
Written by Dr. Xiaoming (Raymond) Zheng in November 2018

## Functionality:
This plugin can make an additional prior API call(named prior-call) when the configured service (named service-call) is called.
The prior-call can accepts variables from both headers and body of service-call.
The service-call can accepts variables from both headers and body of the reponse of prior-call.
The tested running time is around 0.24 milliseconds, while one notify API call takes 1123.4 milliseconds.

## Use Case:
Taking Telstra notification API for example, when an end user/agent calls the notification platform to send out a short message, this plugin will call the token server first, grab the returned asscess token from response and insert into the headers of the call to the notification. 

## Pre-requisites:
- [unzip](https://linuxhint.com/centos_unzip/) >= 6.00
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

## Parameter Explanation:
- config.debug: Debug model. Write all information into proxy_error.log as notices.
- config.prereq.body: set the body for prior-call. (String)
- config.prereq.headers: set the headers for prior-call. (Array of strings separated by ```,```)
- config.prereq.http_method: HTTP methods, default to ```POST```. (String)
- config.prereq.ssl_verify: whether to check ssl. (Boolean)
- config.prereq.url: the url of prior-call. (String, unencoded url)
- config.prereq.show_response: prior-call response as final response when in error
- config.request.body: overwrite the body of service-call. (String)
- config.request.headers: add headers to service-call. (Array of strings separated by ```,```)
- config.upstream_path_append: append path to upstream uri. Varaibles are compatible in the appended path.
- api_id, service_id, route_id and consumer_id are heritated from standard Kong plugin. Please refer to Kong Doc.


## Variable Format:
When configuring this plugin in Kong Admin Dashboard, variables from 4 sources( both headers and body of request of service-call and response of prior-call: req_headers, req_body, res_headers and res_body) can be used. 
However the rules below apply:
- Variables must follow the format '{{KEY:VALUE}}'(quotation marks here and below are not included).
- The available 'KEY' are 'res_headers', 'res_body', 'req_headers', 'req_query'  and 'req_body'.
- 'VALUE' is case-insensitive when 'KEY' is 'req_headers' or 'res_headers' following HTTP standards.
- 'VALUE' is case-sensitive when 'KEY' is 'req_body' or 'req_query' or 'res_body'.
- 'req_body' is only available when 'content-type:application/json' is in 'req_headers'.
- 'req_body' and 'res_body' must be json-formatted string and only one level variables can be used.
- 'res_body' and 'res_headers' are only available for service-call.

## Attenttion:
-  Compare the PRIORITY number with other plugins carefully, which determine the order of plugin running
-  Not obeying the order in installation will cause the failure of Kong start
-  Not obeying the order in uninstallation will fail Kong
-  User input error precaution has not been developed yes in Lua code.

## Versions:
- 1.0.1: Add debug info into syslog
- 1.0.0: Add debug mode and prior-call response as the first version used in production.
- 0.3.0: Add parameter 'config.upstream_path_append'; Allow 'req_body', 'req_query' and 'req_headers' in request.
- 0.2.1: Add query related parameters.
- 0.1.1: Achieve middle call.

## Developement
- ```luarock make <kong-plugin-telstra-prior-request-1.0.1-0.rockspec>``` will install from source using spec in the folder.
- ```luarocks pack kong-plugin-telstra-prior-request 1.0.1-0``` pack installed plugin

## Syslog Check:
- journalctl -u kongd <--no-pager>