# Build for Kong Customized Plugin: Telstra Prior Request
Written by Dr. Raymond Zheng in November 2018

## Functionality:
When this plugin is enabled to a server, and when a API call to this service is made, this plugin will first make another independent call, grab the response, and update some request information of the call to the service.

## Use Case:
Taking notification for example, when end users call the notification platform to send an short message, this plugin will call the token server first, grab the returned asscess token from response and insert into the headers of the call to the notification. 

## Pre-requisites:
- [Lua](https://www.lua.org/) >= 5.1
- [LuaRocks](https://luarocks.org/) >=2.4.3
- [Kong](https://konghq.com/) >= 0.33
- [OpenResty](https://openresty.org/) >= 1.13.6.2
- [Nginx](https://nginx.org/) >= 1.13.11

## Installation:
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

## Attenttion:
-  Compare the PRIORITY number with other plugins carefully, which determine the order of plugin running
-  Not obeying the order in installation will cause the failure of Kong start
-  Not obeying the order in uninstallation will fail Kong
-  User input error precaution has not been developed yes in Lua code.
