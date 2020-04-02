# pimatic-meross
Pimatic plugin for support of Meross devices

This plugin lets you control and get status info from a Meross devices. The plugin supports the SmartPlug (mss210) and the Garagedoor Opener (msg100).

After downloading the Meross app, you can register in the app with your email and password.
After registration you can add your meross device(s) in the app, configure the wifi and other settings.

When these steps are done you can configure the pimatic-meross plugin.

## Config of the plugin
```
{
  username: "The username of your Meross account"
  password: "The password of your Meross account"
  debug:    "Debug mode. Writes debug messages to the Pimatic log, if set to true."
}
```

## Config of a Meross device

Meross devices are added via the discovery function.
The automatic generated information must not change. Its the unique reference to your meross device. You can change the Pimatic device name after you have saved the device. This is the only device variable you may change!
The following data is automatically generated on device discovery and should not be changed!

```
{
  region: "The region"
  devIconId: "The device icon"
  fmwareVersion: "The firmware version number"
  hdwareVersion: "The hardware version number"
}
```

## Garagedoor Opener (msg100)
The following variables (attributes) are available in the gui / pimatic.

```
<deviceId>.deviceStatus:      "If the device is online or offline"
<deviceID>.garagedoorStatus:  "Actual status of the garagedoor (open or closed)"
```
The garagedoor is opened and closed via buttons. These buttons ca be controlled via the gui, rules or the api.

## Smartplug (mss210)
The following variables (attributes) are available in the gui / pimatic.

```
<deviceId>.deviceStatus:   	"If the device is online or offline"
<deviceId>.state:  			"Actual stateof the Smartplug switch (on or off)"
```
The smartplug is switched on or off via the gui, rules or the api. If the button on the smartplug is toggled (swithed on or off) the switch in pimatic will also toggle.


---

You could backup Pimatic before you are using this plugin!

__The minimum requirement for this plugin is node v8!__
