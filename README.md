# Build for Kong Customized Plugin: Telstra Prior Request
Written by Dr. Raymond Zheng in November 2018

## Functionality:
When this plugin is enabled to a server, and when a API call to this service is made, this plugin will first make another independent call, grab the response, and update some request information of the call to the service.

## Use Case:
Taking notification for example, when end users call the notification platform to send an short message, this plugin will call the token server first, grab the returned asscess token from response and insert into the headers of the call to the notification. 

## Installation:
-  luarock install .

## Uninstallation:
-  Remove all configuration of this plugin in Admin Dashboard
-  Remove this plugin from 'custom_plugins' in Kong configration file
-  Remove packages of this plugin
-  Restart Kong daemon

## Attenttion:
-  Compare the PRIORITY number with other plugins carefully, which determine the order of plugin running
-  Not obeying the order in installation will cause the failure of Kong start
-  Not obeying the order in uninstallation will fail Kong
-  User input error precaution has not been developed yes in Lua code.
