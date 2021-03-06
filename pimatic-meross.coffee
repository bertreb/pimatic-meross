module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  M = env.matcher
  _ = require('lodash')
  MerossCloud = require 'meross-cloud'

  class MerossPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-meross-config-schema'
      @configProperties = pluginConfigDef.properties

      deviceConfigDef = require("./device-config-schema")

      @merossDevices = {}

      options =
        email: @config.username
        password: @config.password
        logger: console.log

      @connected = false
      @meross = new MerossCloud(options)
      @meross.on 'deviceInitialized', (deviceId, deviceDef, device) =>
        #env.logger.debug  'New deviceDef ' + deviceId + ': ' + JSON.stringify(deviceDef,null,2)
        #env.logger.debug  'New device ' + deviceId + ': ' + JSON.stringify(device,null,2)
        @merossDevices[deviceId] = device
        @connected = true
        env.logger.info "Nr of devices: " + _.size(@merossDevices)
        
        device.on 'connected', () =>
          env.logger.debug 'DEV: ' + deviceId + ' connected'
          @emit 'deviceConnected', device.dev.uuid

        device.on 'close', (error) =>
          #env.logger.debug 'DEV: ' + deviceId + ' closed: ' + error
          @emit 'deviceDisonnected', device.dev.uuid

        device.on 'error', (error) =>
          env.logger.debug 'DEV: ' + deviceId + ' error: ' + error
          @emit 'deviceDisonnected', device.dev.uuid

        device.on 'reconnect', (recon) =>
          env.logger.debug 'DEV: ' + deviceId + ' reconnected: ' + recon
          @emit 'deviceReconnected', device.dev.uuid

        device.on 'rawSendData', (message) =>
          #env.logger.debug "Device Send raw: " + deviceId + ' data: ' + JSON.stringify(message)

      @meross.on 'connected', (deviceId) =>
        #env.logger.debug deviceId + ' connected'

      @meross.on 'close', (deviceId, error) =>
        env.logger.debug deviceId + ' closed: ' + error

      @meross.on 'error', (deviceId, error) =>
        env.logger.debug deviceId + ' error: ' + error

      @meross.on 'reconnect', (deviceId) =>
        #env.logger.debug deviceId + ' reconnected'

      @meross.connect((error) =>
        if error
          env.logger.debug 'connect error: ' + error
          return
        env.logger.debug 'init succesful'
      )

      @framework.deviceManager.registerDeviceClass('MerossGaragedoor', {
        configDef: deviceConfigDef.MerossGaragedoor,
        createCallback: (config, lastState) => new MerossGaragedoor(config, lastState, @framework, @)
      })
      @framework.deviceManager.registerDeviceClass('MerossSmartplug', {
        configDef: deviceConfigDef.MerossSmartplug,
        createCallback: (config, lastState) => new MerossSmartplug(config, lastState, @framework, @)
      })
      @framework.deviceManager.registerDeviceClass('MerossSmartplugEnergy', {
        configDef: deviceConfigDef.MerossSmartplugEnergy,
        createCallback: (config, lastState) => new MerossSmartplugEnergy(config, lastState, @framework, @)
      })

      @framework.ruleManager.addActionProvider(new MerossActionProvider(@framework))

      @framework.on "after init", =>
        # Check if the mobile-frontent was loaded and get a instance
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', "pimatic-meross/app/meross.coffee"
          #mobileFrontend.registerAssetFile 'css', "pimatic-meross/app/css/meross.css"
          mobileFrontend.registerAssetFile 'html', "pimatic-meross/app/meross.jade"
        else
          env.logger.warn "your plugin could not find the mobile-frontend. No gui will be available"

      @supportedTypes = [
        {merossType: 'mss210', pimaticType: 'MerossSmartplug'},
        {merossType: 'mss310', pimaticType: 'MerossSmartplugEnergy'},
        {merossType: 'msg100', pimaticType: 'MerossGaragedoor'}
      ]
      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage 'pimatic-meross', 'Searching for new devices'
        if @connected and @meross?
          for i, device of @merossDevices
            #env.logger.info "Device: " + JSON.stringify(device.dev.uuid,null,2)
            _did = device.dev.uuid
            if _.find(@framework.deviceManager.devicesConfig,(d) => d.id.indexOf(_did)>=0)
              env.logger.info "Device '" + _did + "' already in config"
            else
              _type = _.find(@supportedTypes, (t)=> (t.merossType).indexOf(device.dev.deviceType)>=0)
              if _type?
                config =
                  id: _did
                  name: device.dev.devName
                  class: _type.pimaticType
                  devIconId: device.dev.devIconId
                  region: device.dev.region
                  fmwareVersion: device.dev.fmwareVersion
                  hdwareVersion: device.dev.hdwareVersion
                @framework.deviceManager.discoveredDevice( "Meross", config.name, config)
              else
                env.logger.info "Device type #{device.merossType} not implemented."
        else
          env.logger.info "Meross offline"
      )

  class MerossGaragedoor extends env.devices.Device


    template: "meross-garagedoor"

    actions:
      buttonPressed:
        params:
          buttonId:
            type: "string"
        description: "Press a button"


    constructor: (@config, lastState, @framework, @plugin) ->
      #@config = config
      @id = @config.id
      @name = @config.name

      @deviceId = @config.deviceId

      if @_destroyed then return

      @addAttribute 'deviceStatus',
        description: "Garagedoor status",
        type: "boolean"
        labels: ["online","offline"]
        acronym: "device"

      @addAttribute 'garagedoorStatus',
        description: "Garagedoor status"
        type: "boolean"
        labels: ["open","closed"]
        acronym: "garagedoor"


      @_garagedoorStatus = lastState?.garagedoorStatus?.value or false
      @_deviceStatus = lastState?.deviceStatus?.value or false
      #@deviceConnected = @_deviceStatus

      ###
      @config.buttons=[
        { id : "open" , text : "open" },
        { id : "close" , text : "close" }
      ]
      ###

      @framework.variableManager.waitForInit()
      .then(
        @device = @plugin.meross.getDevice(@id)
        unless @device?
          env.logger.debug "Device '#{@name}' does not exsist"
        else
          @_initDevice()
      )

      #env.logger.info "@_deviceStatus: " + @_deviceStatus
      #@_setDeviceStatus(@_deviceStatus)

      @plugin.on 'deviceReconnected', (uuid) =>
        if uuid is @id and @_deviceStatus is false
          @device = @plugin.meross.getDevice(@id)
          env.logger.debug "DeviceReConnected " + @id
          unless @device?
            env.logger.debug "Device '#{@name}' does not exsist"
            return
          @_initDevice()

      @plugin.on 'deviceConnected', (uuid) =>
        if uuid is @id and @_deviceStatus is false
          @device = @plugin.meross.getDevice(@id)
          env.logger.debug "DeviceConnected " + @id
          unless @device?
            env.logger.debug "Device '#{@name}' does not exsist"
            return
          @_initDevice()

      @plugin.on 'deviceDisonnected', (uuid) =>
        if uuid is @id
          #@deviceConnected = false
          @_setDeviceStatus(false)
          if @device?
            @device.removeListener('data', @handleData)

      super()

    _initDevice: () =>
      @device.on 'data', @handleData
      @device.getSystemAllData((err,allData)=>
        if err
          env.logger.debug "Error getSystemAllData for device '#{@id}' " + err
          return
        env.logger.debug "AllData: " + JSON.stringify(allData,null,2)
        #set initial state
        if Boolean(allData?.all?.digest?.garageDoor[0]?.open)
          newState = true # Boolean(allData.all.digest.garageDoor.open)
        else
          newState = false # contact is closed = garagedoor closed
        @_setGaragedoorStatus(newState)
        .then(()=>
          if allData?.all?.system?.online?.status?
            if Boolean(allData?.all?.system?.online?.status) is true
              newOnlineState = true
            if Boolean(allData?.all?.system?.online?.status) is false
              newOnlineState = false
            #@_deviceStatus = newOnlineState
            @_setDeviceStatus(newOnlineState)
            env.logger.debug 'Online status: ' + newOnlineState
        )
      )


    buttonPressed: (buttonId) =>
      if buttonId is "open"
        @openGaragedoor()
      else if buttonId is "close"
        @closeGaragedoor()
      else
        env.logger.debug "Unknown button #{buttonId} received"


    getTemplateName: -> "meross-garagedoor"

    openGaragedoor: ->
      unless @_deviceStatus and @device?
        env.logger.info "Device '#{@name}' is offline"
        return
      @getGaragedoorStatus()
      .then((garagedoorStatus)=>
        if garagedoorStatus is false # = contact is closed -> door is closed
          @device.controlGarageDoor(1, 1, (err,resp)=>
            if err
              env.logger.debug "Error executing garagedoor open " + err
              return
            env.logger.info "Garagedoor opened"
          )
        else
          env.logger.info "Garagedoor is already open"
      )

    closeGaragedoor: ->
      unless @_deviceStatus and @device?
        env.logger.info "Device '#{@name}' is offline"
        return
      @getGaragedoorStatus()
      .then((garagedoorStatus)=>
        if garagedoorStatus is true # = contact is opened -> door is open
          @device.controlGarageDoor(1, 0, (err,resp)=>
            if err
              env.logger.debug "Error executing garagedoor close " + err
              return
            env.logger.info "Garagedoor closed"
          )
        else
          env.logger.info "Garagedoor is already closed"
      )

    handleData: (namespace, payload) =>
      env.logger.debug "Handledata, device: " + @id + ", namespace: " + namespace + ", Payload: " + JSON.stringify(payload,null,2)
      try
        switch namespace
          when 'Appliance.GarageDoor.State'
            @_setDeviceStatus(true)

            env.logger.debug "Garagedoor State: " + JSON.stringify(payload,null,2)
            if payload.state[0]?.open?
              if payload.state[0]?.open
                newState = Boolean(payload.state[0].open)
              else
                newState = false # contact is closed = garagedoor closed
              @_setGaragedoorStatus(newState)
              .then(()=>
                env.logger.debug "Garagedoor state changed to " + (if newState then "open" else "closed")
              )
          when 'Appliance.System.Online'
            if (Number payload.online.status) == 1 then @_setDeviceStatus(true) else @_setDeviceStatus(false)
      catch err
        env.logger.debug "error handleData handled: " + err


    _setGaragedoorStatus: (value) =>
      return new Promise((resolve,reject)=>
        #if @_garagedoorStatus is value
        #  resolve()
        @_garagedoorStatus = value
        @emit 'garagedoorStatus', @_garagedoorStatus
        resolve()
      )

    _setDeviceStatus: (value) =>
      @_deviceStatus = value
      @emit 'deviceStatus', @_deviceStatus

    getGaragedoorStatus: => Promise.resolve(@_garagedoorStatus)
    getDeviceStatus: => Promise.resolve(@_deviceStatus)

    execute: (device, command, options) =>
      env.logger.debug "Execute command: #{command} with options: #{options}"
      return new Promise((resolve, reject) =>
        unless @_deviceStatus and @device?
          env.logger.info "Device '#{@name}' is offline"
          return reject()
        switch command
          when "open"
            @getGaragedoorStatus()
            .then((garagedoorStatus)=>
              if garagedoorStatus is false # = contact is closed -> door is closed
                @device.controlGarageDoor(1, 1, (err,resp)=>
                  if err
                    env.logger.debug "Error executing garagedoor open " + err
                    reject()
                  env.logger.info "Garagedoor opened"
                  resolve()
                )
              else
                env.logger.info "Garagedoor is already open"
                resolve()
            )
          when "close"
            @getGaragedoorStatus()
            .then((garagedoorStatus)=>
              if garagedoorStatus is true # = contact is opened -> door is open
                @device.controlGarageDoor(1, 0, (err,resp)=>
                  if err
                    env.logger.debug "Error executing garagedoor close " + err
                    reject()
                  env.logger.info "Garagedoor closed"
                  resolve()
                )
              else
                env.logger.info "Garagedoor is already closed"
                resolve()
            )
          else
            env.logger.debug "Unknown command received: " + command
            reject()
      )



    destroy:() =>
      if @device?
        @device.removeListener('data', @handleData)
      #@removeAllListeners()
      super()

  class MerossSmartplug extends env.devices.SwitchActuator

    constructor: (@config, lastState, @framework, @plugin) ->
      #@config = config
      @id = @config.id
      @name = @config.name
      @_state = lastState?.state?.value
      @_deviceStatus = lastState?.deviceStatus?.value or false
      #@deviceConnected = false

      if @_destroyed then return

      @addAttribute 'deviceStatus',
        description: "device",
        type: "boolean"
        labels: ["online","offline"]
        acronym: "Status"

      @_setDeviceStatus(@_deviceStatus)

      @framework.variableManager.waitForInit()
      .then(
        @device = @plugin.meross.getDevice(@id)
        unless @device?
          env.logger.debug "Device '#{@name}' does not exsist"
        else
          @_initDevice()
      )

      @plugin.on 'deviceReconnected', (uuid) =>
        if uuid is @id and @_deviceStatus is false
          @device = @plugin.meross.getDevice(@id)
          env.logger.debug "DeviceReConnected " + @id
          unless @device?
            env.logger.debug "Device '#{@name}' does not exsist"
            return
          @_initDevice()

      @plugin.on 'deviceConnected', (uuid) =>
        if uuid is @id and @_deviceStatus is false
          @device = @plugin.meross.getDevice(@id)
          env.logger.debug "DeviceConnected " + @id
          unless @device?
            env.logger.debug "Device '#{@name}' does not exsist"
            return
          @_initDevice()

      @plugin.on 'deviceDisonnected', (uuid) =>
        if uuid is @id
          #@deviceConnected = false
          @_setDeviceStatus(false)
          if @device?
            @device.removeListener('data', @handleData)


      super()


    _initDevice: () =>
      @device.on 'data', @handleData
      @device.getSystemAllData((err,allData)=>
        if err
          env.logger.debug "Error getSystemAllData for device '#{@id}' " + err
          return
        env.logger.debug "AllData msg210: " + JSON.stringify(allData,null,2)
        #set initial state
        if allData?.all?.system?.online?.status?
          if Boolean(allData?.all?.system?.online?.status) is true
            newOnlineState = true
          if Boolean(allData?.all?.system?.online?.status) is false
            newOnlineState = false
          #@_deviceStatus = newOnlineState
          @_setDeviceStatus(newOnlineState)
          env.logger.debug 'Online status: ' + newOnlineState
      )

    handleData: (namespace, payload) =>
      env.logger.debug "device: " + @id + ", namespace: " + namespace + ", Payload: " + JSON.stringify(payload,null,2)
      switch namespace
        when 'Appliance.Control.ToggleX'
          @_setState(Boolean(payload.togglex[0].onoff))
        when 'Appliance.Control.Toggle'
          @_setState(Boolean(payload.toggle[0].onoff))
        when 'Appliance.System.Online'
          if (Number payload.online.status) == 1
            @_setDeviceStatus(true) 
          else 
            @_setDeviceStatus(false)


    changeStateTo: (state) =>
      if @_deviceStatus and @device?
        if state
          @device.controlToggleX(0,1, (err)=>
            if err?
              env.logger.debug "Handled error controlToggleX on " + err
          )
        else
          @device.controlToggleX(0,0, (err)=>
            if err?
              env.logger.debug "Handled error controlToggleX off " + err
          )


    _setDeviceStatus: (value) =>
      @_deviceStatus = value
      @emit 'deviceStatus', @_deviceStatus

    getDeviceStatus: => Promise.resolve(@_deviceStatus)


    execute: (device, command, options) =>
      env.logger.debug "Execute command: #{command} with options: #{options}"
      return new Promise((resolve, reject) =>
        unless @_deviceStatus and @device?
          env.logger.info "Device '#{@name}' is offline"
          return reject()
        reject("Not implemented")
      )


    destroy:() =>
      if @device?
        @device.removeListener('data', @handleData)
      super()

  class MerossSmartplugEnergy extends env.devices.SwitchActuator

    constructor: (@config, lastState, @framework, @plugin) ->
      #@config = config
      @id = @config.id
      @name = @config.name
      @_state = lastState?.state?.value
      @_deviceStatus = lastState?.deviceStatus?.value or false
      @_voltage = lastState?.voltage?.value or 0
      @_current = lastState?.current?.value or 0
      @_power = lastState?.power?.value or 0
      @_powerConsumption = lastState?.powerConsumption?.value or 0
      #@deviceConnected = false

      @pollElectricityTime = @config.polltimeElectricity ? 30 # seconds
      @pollElectricityTime = 30 if @pollElectricityTime < 30 
      @pollConsumptionTime = @config.polltimeConsumption ? 86400 # 1 day is 86400 seconds

      if @_destroyed then return

      @addAttribute 'deviceStatus',
        description: "Smartplug status",
        type: "boolean"
        labels: ["online","offline"]
        acronym: "device"
      @addAttribute 'current',
        description: "Current",
        type: "number"
        unit: "A",
        acronym: "current"
      @addAttribute 'voltage',
        description: "Voltage",
        type: "number",
        unit: "V",
        acronym: "voltage"
      @addAttribute 'power',
        description: "Power",
        type: "number"
        unit: "W",
        acronym: "power"
      @addAttribute 'powerConsumption',
        description: "Power Consumption",
        type: "number"
        unit: "Wh",
        acronym: "consumption"

      @_setDeviceStatus(@_deviceStatus)

      @framework.variableManager.waitForInit()
      .then(
        @device = @plugin.meross.getDevice(@id)
        unless @device?
          env.logger.debug "Device '#{@name}' does not exsist"
        else
          @_initDevice()
      )

      @plugin.on 'deviceReconnected', (uuid) =>
        if uuid is @id and @_deviceStatus is false
          @device = @plugin.meross.getDevice(@id)
          env.logger.debug "DeviceReConnected " + @id
          unless @device?
            env.logger.debug "Device '#{@name}' does not exsist"
            return
          @_initDevice()

      @plugin.on 'deviceConnected', (uuid) =>
        if uuid is @id and @_deviceStatus is false
          @device = @plugin.meross.getDevice(@id)
          env.logger.debug "DeviceConnected " + @id
          unless @device?
            env.logger.debug "Device '#{@name}' does not exsist"
            return
          @_initDevice()

      @plugin.on 'deviceDisonnected', (uuid) =>
        if uuid is @id
          #@deviceConnected = false
          @_setDeviceStatus(false)
          if @device?
            @device.removeListener('data', @handleData)


      @pollElectricity = () =>
        if @device? and (@_deviceStatus is true)
          @device.getControlElectricity((err,resp)=>
            if err?
              env.logger.debug "Handled error getControlElectricity: " + err
            else
              env.logger.debug 'Electricity values polled' # response: ' + JSON.stringify(resp,null,2)
              @_voltage = resp.electricity.voltage / 10
              @_current = resp.electricity.current / 1000
              @_power = resp.electricity.power / 1000
              @emit 'voltage', @_voltage
              @emit 'current', @_current
              @emit 'power', @_power
          )
        @pollElectricityTimer = setTimeout(@pollElectricity, @pollElectricityTime*1000)
      @pollElectricity()
      
      @pollConsumption = () =>
        if @device? and (@_deviceStatus is true)
          @device.getControlPowerConsumptionX((err,resp)=>
            if err?
              env.logger.debug "Handled error getControlPowerConsumptionX: " + err
            else
              env.logger.debug 'Power Consumption values polled' # response: ' + JSON.stringify(resp,null,2)
              @_powerConsumption = resp.consumptionx[0].value
              @emit 'powerConsumption', @_powerConsumption
          )
        @pollConsumptionTimer = setTimeout(@pollConsumption, @pollConsumptionTime*1000)
      @pollConsumption()

      super()


    _initDevice: () =>
      @device.on 'data', @handleData
      @device.getSystemAllData((err,allData)=>
        if err
          env.logger.debug "Error getSystemAllData for device '#{@id}' " + err
          return
        env.logger.debug "AllData msg310: " + JSON.stringify(allData,null,2)
        #set initial state
        if allData?.all?.system?.online?.status?
          if Boolean(allData?.all?.system?.online?.status) is true
            newOnlineState = true
          if Boolean(allData?.all?.system?.online?.status) is false
            newOnlineState = false
          #@_deviceStatus = newOnlineState
          @_setDeviceStatus(newOnlineState)
          env.logger.debug 'Online status: ' + newOnlineState
      )

    handleData: (namespace, payload) =>
      env.logger.debug "device: " + @id + ", namespace: " + namespace + ", Payload: " + JSON.stringify(payload,null,2)
      switch namespace
        when 'Appliance.Control.ToggleX'
          @_setState(Boolean(payload.togglex[0].onoff))
        when 'Appliance.Control.Toggle'
          @_setState(Boolean(payload.toggle[0].onoff))
        when 'Appliance.System.Online'
          if (Number payload.online.status) == 1 
            @_setDeviceStatus(true) 
          else 
            @_setDeviceStatus(false)
        when 'Appliance.Control.Electricity' # power, voltage, current
          @_voltage = payload.electricity.voltage / 10
          @_current = payload.electricity.current / 1000
          @_power = payload.electricity.power / 1000
          @emit 'voltage', @_voltage
          @emit 'current', @_current
          @emit 'power', @_power

    changeStateTo: (state) =>
      env.logger.debug "@_deviceStatus " + @_deviceStatus + ", @device? " + @device? + ", state " + state
      if @_deviceStatus and @device?
        env.logger.debug "Change state to " + state
        if state
          @device.controlToggleX(0,1, (err)=>
            if err?
              env.logger.debug "Handled error controlToggleX on " + err
          )
        else
          @device.controlToggleX(0,0, (err)=>
            if err?
              env.logger.debug "Handled error controlToggleX off " + err
          )


    _setDeviceStatus: (value) =>
      @_deviceStatus = value
      @emit 'deviceStatus', @_deviceStatus

    getDeviceStatus: => Promise.resolve(@_deviceStatus)
    getCurrent: => Promise.resolve(@_current)
    getVoltage: => Promise.resolve(@_voltage)
    getPower: => Promise.resolve(@_power)
    getPowerConsumption: => Promise.resolve(@_powerConsumption)

    execute: (device, command, options) =>
      env.logger.debug "Execute command: #{command} with options: #{options}"
      return new Promise((resolve, reject) =>
        unless @_deviceStatus and @device?
          env.logger.info "Device '#{@name}' is offline"
          return reject()
        reject("Not implemented")
      )


    destroy:() =>
      if @device?
        @device.removeListener('data', @handleData)
      clearTimeout(@pollElectricityTimer)
      clearTimeout(@pollConsumptionTimer)
      super()



  class MerossActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>

      merossDevice = null
      merossDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => (device.config.class).indexOf("MerossGaragedoor")>= 0
      ).value()
      @options = []

      setCommand = (command) =>
        @command = command

      m = M(input, context)
        .match('meross ')
        .matchDevice(merossDevices, (m, d) ->
          # Already had a match with another device?
          if merossDevice? and merossDevice.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return
          merossDevice = d
        )
        .or([
          ((m) =>
            return m.match(' open', (m) =>
              setCommand('open')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' close', (m) =>
              setCommand('close')
              match = m.getFullMatch()
            )
           )
        ])

      match = m.getFullMatch()
      if match? #m.hadMatch()
        env.logger.debug "Rule matched: '", match, "' and passed to Action handler"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new MerossActionHandler(@framework, merossDevice, @command, @options)
        }
      else
        return null


  class MerossActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @merossDevice, @command, @options) ->

    executeAction: (simulate) =>
      if simulate
        return __("would have cleaned \"%s\"", "")
      else
        @merossDevice.execute(@homeconnectDevice,@command, @options)
        .then(()=>
          return __("\"%s\" Rule executed", @command)
        ).catch((err)=>
          return __("\"%s\" Rule not executed", "")
        )



  plugin = new MerossPlugin
  return plugin
