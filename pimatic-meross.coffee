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
          #device.getSystemAbilities((err, res) =>
          #    #env.logger.debug 'Abilities: ' + JSON.stringify(res,null,2)
          #    device.getSystemAllData((err, res) =>
          #      env.logger.debug 'All-Data: ' # + JSON.stringify(res,null,2)
          #    )
          #)

        device.on 'close', (error) =>
          env.logger.debug 'DEV: ' + deviceId + ' closed: ' + error
          @emit 'deviceDisonnected', device.dev.uuid

        device.on 'error', (error) =>
          env.logger.debug 'DEV: ' + deviceId + ' error: ' + error
          @emit 'deviceDisonnected', device.dev.uuid

        device.on 'reconnect', () =>
          env.logger.debug 'DEV: ' + deviceId + ' reconnected'
          @emit 'deviceConnected', device.dev.uuid

        ###
        device.on 'data', (namespace, payload) =>
          env.logger.debug 'DEV: ' + deviceId + ' ' + namespace + ' - data: ' + JSON.stringify(payload)
          switch namespace
            when 'Appliance.Control.ToggleX'
              device.emit 'togglex', payload
              env.logger.debug "namespace received: " + namespace
              #setValuesToggleX(deviceId, payload);
            when 'Appliance.Control.Toggle'
              env.logger.debug "namespace received: " + namespace
              #device.emit 'smartplug', payload
              #setValuesToggle(deviceId, payload);
            when 'Appliance.System.Online'
              env.logger.debug "namespace received: " + namespace
              device.emit "onlineStatus", payload
              #adapter.setState(deviceId + '.online', (payload.online.status === 1), true);
            when 'Appliance.GarageDoor.State'
              #env.logger.debug "namespace received: " + namespace
              @emit 'garagedoor', payload
              #setValuesGarageDoor(deviceId, payload);
            when 'Appliance.System.DNDMode'
              env.logger.debug "namespace received: " + namespace
              #adapter.setState(deviceId + '.dnd', !!payload.DNDMode.mode, true);
            when 'Appliance.Control.Light'
              env.logger.debug "namespace received: " + namespace
              #setValuesLight(deviceId, payload);
            when 'Appliance.Control.Spray'
              env.logger.debug "namespace received: " + namespace
              #setValuesSpray(deviceId, payload);
            when 'Appliance.Hub.ToggleX'
              env.logger.debug "namespace received: " + namespace
              #setValuesHubToggleX(deviceId, payload);
            when 'Appliance.Hub.Battery'
              env.logger.debug "namespace received: " + namespace
              #setValuesHubBattery(deviceId, payload);
            when 'Appliance.Hub.Mts100.Temperature'
              env.logger.debug "namespace received: " + namespace
              #setValuesHubMts100Temperature(deviceId, payload);
            when 'Appliance.Hub.Mts100.Mode'
              env.logger.debug "namespace received: " + namespace
              #setValuesHubMts100Mode(deviceId, payload);
            when 'Appliance.Hub.Sensor.TempHum'
              env.logger.debug "namespace received: " + namespace
              #setValuesHubMts100TempHum(deviceId, payload);
            when 'Appliance.Control.Upgrade'
              env.logger.debug "namespace received: " + namespace
            when 'Appliance.System.Report'
              env.logger.debug "namespace received: " + namespace
            when 'Appliance.Control.ConsumptionX'
              env.logger.debug "namespace received: " + namespace
            else
              env.logger.debug "Unknown namespace received: " + namespace
        ###

        #device.on 'rawData', (deviceId, message) =>
        #  env.logger.debug "Device raw: " + deviceId + ' data: ' + JSON.stringify(message)

        device.on 'rawSendData', (message) =>
          #env.logger.debug "Device Send raw: " + deviceId + ' data: ' + JSON.stringify(message)

      @meross.on 'connected', (deviceId) =>
        env.logger.debug deviceId + ' connected'

      @meross.on 'close', (deviceId, error) =>
        env.logger.debug deviceId + ' closed: ' + error

      @meross.on 'error', (deviceId, error) =>
        env.logger.debug deviceId + ' error: ' + error

      @meross.on 'reconnect', (deviceId) =>
        env.logger.debug deviceId + ' reconnected'

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

      @framework.ruleManager.addActionProvider(new MerossActionProvider(@framework))

      @supportedTypes = [
        {merossType: 'mss210', pimaticType: 'MerossSmartplug'},
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

  class MerossGaragedoor extends env.devices.PowerSwitch

    constructor: (@config, lastState, @framework, @plugin) ->
      #@config = config
      @id = @config.id
      @name = @config.name
      @deviceId = @config.deviceId

      if @_destroyed then return

      @_contact = lastState?.contact?.value or false
      @_status = false
      @deviceConnected = false

      @addAttribute 'contact',
        description: "Garagedoor status"
        type: "boolean"
        labels: ["open","closed"]
        acronym: "garagedoor"

      @addAttribute 'status',
        description: "Garagedoor status",
        type: "boolean"
        labels: ["online","offline"]
        acronym: "status"

      @_setStatus(@_status)

      @framework.on 'deviceChanged', (device) =>
        if @_destroyed then return
        if device.id is @id
          env.logger.info "deviceChanged " + device.id
          @device = @plugin.meross.getDevice(@id)
          if @device?
            @device.on 'data', @handleData
          else
            env.logger.info "Unknown device " + @id

      @plugin.on 'deviceConnected', (uuid) =>
        if uuid is @id and @deviceConnected is false
          @device = @plugin.meross.getDevice(@id)
          unless @device?
            env.logger.debug "Device '#{@name}' does not exsist"
            return
          @device.getSystemAllData((err,allData)=>
            if err
              env.logger.debug "Error getSystemAllData for device '#{@id}' " + err
              return
            env.logger.debug "AllData: " + JSON.stringify(allData,null,2)
            #set initial state
            if allData?.all?.digest?.garageDoor?.open
                newState = Boolean(allData.all.digest.garageDoor.open)
              else
                newState = false # contact is closed = garagedoor closed
              @_setContact(newState)
              .then(()=>
                @device.on 'data', @handleData
                if allData?.all?.system?.online?.status
                  newOnlineState = Boolean(allData.all.system.online.status)
                  if newOnlineState
                    @deviceConnected = true
                else
                  newOnlineState = false
                @_setStatus(newOnlineState)
                env.logger.debug 'Online status: ' + newOnlineState
              )
          )
      @plugin.on 'deviceDisonnected', (uuid) =>
        if uuid is @id
          @deviceConnected = false
          @_setStatus(false)
          @device.removeListener('data', @handleData)

      super()


    handleData: (namespace, payload) =>
      env.logger.debug "Handledata, device: " + @id + ", namespace: " + namespace + ", Payload: " + JSON.stringify(payload,null,2)
      try
        switch namespace
          when 'Appliance.GarageDoor.State'
            env.logger.debug "Garagedoor State: " + JSON.stringify(payload,null,2)
            if payload.state[0]?.open?
              newState = Boolean(payload.state[0].open)
            else
              newState = false # contact is closed = garagedoor closed
            @_setContact(newState)
            .then(()=>
              if newState is true
                # contact is open -> garagdoor is open
                @changeStateTo(true)
              else # newState is false
                # contact is closed -> garagdoor is closed
                @changeStateTo(false)
            )
          when 'Appliance.System.Online'
            if payload.online.status == "1" then @_setStatus(true) else @_setStatus(false)
      catch err
        env.logger.debug "error handleData handled: " + err


    _setContact: (value) ->
      return new Promise((resolve,reject)=>
        if @_contact is value
          resolve()
        @_contact = value
        @emit 'contact', value
        resolve()
      )

    _setStatus: (value) ->
      @_status = value
      @emit 'status', value

    getContact: -> Promise.resolve(@_contact)
    getStatus: -> Promise.resolve(@_status)

    changeStateTo: (newState) =>
      @getState((state)=>
        if state is newState
          env.logger.debug "Switch is already is requested state"
          return
        else
          unless @deviceConnected and @device?
            env.logger.debug "Device '#{@name}' is offline"
            return
          if newState then _newState = 1 else _newState = 0
          @getContact((contact)=>
            if not contact and _newState # door is closed (contact is closed) and intend is to open garagedoor
              env.logger.debug "Open garagedoor"
              @device.controlGarageDoor(1, 1, (err,resp)=>
                if err
                  env.logger.debug "Error executing garagedoor open " + err
                  return
                env.logger.debug "Garagedoor open command executed: " + resp
              )
            if contact and not _newState # door is open (contact is open) and intent is to close garagedoor
              env.logger.debug "Close garagedoor"
              @device.controlGarageDoor(1, 0, (err,resp)=>
                if err
                  env.logger.debug "Error executing close garagedoor " + err
                  return
                env.logger.debug "Garagedoor close command executed: " + resp
              )
          )
      )


    execute: (device, command, options) =>
      env.logger.debug "@attributes.OperationState '#{@attributeValues.OperationState}', command #{command}"
      return new Promise((resolve, reject) =>

        switch command
          when "open"
            device.controlGarageDoor(1, 1, (err,resp)=>
              if err
                env.logger.debug "Error executing garagedoor open"
                reject()
              env.logger.debug "Garagedoor open command execute: " + resp
              resolve()
            )
          when "close"
            device.controlGarageDoor(1, 0, (err,resp)=>
              if err
                env.logger.debug "Error executing garagedoor closed"
                reject()
              env.logger.debug "Garagedoor close command execute: " + resp
              resolve()
            )
          else
            env.logger.debug "Unknown command received: " + command
        reject()
      )


    destroy:() =>
      if device?
        @device.removeListener('data', @handleData)
      #@removeAllListeners()
      super()

  class MerossSmartplug extends env.devices.SwitchActuator

    constructor: (@config, lastState, @framework, @plugin) ->
      #@config = config
      @id = @config.id
      @name = @config.name
      #@_state = lastState?.state?.value
      @_status = lastState?.status?.value
      @deviceConnected = false

      if @_destroyed then return

      @addAttribute 'status',
        description: "Smartplug status",
        type: "boolean"
        labels: ["offline","online"]
        acronym: "status"

      @_setStatus(false)

      @framework.on 'deviceChanged', (device) =>
        if @_destroyed then return
        if device.id is @id
          env.logger.info "deviceChanged " + device.id
          @device = @plugin.meross.getDevice(@id)
          @device.on 'data', @handleData

      @plugin.on 'deviceConnected', (uuid) =>
        if uuid is @id and @deviceConnected is false
          @deviceConnected = true
          @device = @plugin.meross.getDevice(@id)
          #@device.getSystemAbilities((err,abilities)=>
          #  @abilities = abilities
          #  env.logger.info "Abilities " + JSON.stringify(@abilities,null,2)
          #)
          @device.on 'data', @handleData
          @device.getOnlineStatus((err, res) =>
            if err?
              env.logger.debug "error getOnlineStatus: " + err
            else
              if res.online.status == 1 then @_setStatus(true) else @_setStatus(false)
              env.logger.debug 'Online status: ' + JSON.stringify(res,null,2)
          )
      @plugin.on 'deviceDisonnected', (uuid) =>
        if uuid is @id
          @deviceConnected = false
          @_setStatus(false)
          @device.removeListener('data', @handleData)

      super()


    handleData: (namespace, payload) =>
      env.logger.debug "device: " + @id + ", namespace: " + namespace + ", Payload: " + JSON.stringify(payload,null,2)
      switch namespace
        when 'Appliance.Control.ToggleX'
          @_setState(Boolean(payload.togglex[0].onoff))
        when 'Appliance.Control.Toggle'
          @_setState(Boolean(payload.toggle[0].onoff))
        when 'Appliance.System.Online'
          if payload.online.status == "1" then @_setStatus(true) else @_setStatus(false)


    changeStateTo: (state) =>
      if state
        @device.controlToggleX(0,1, (res)=>
          env.logger.info "Response " + res
        )
      else
        @device.controlToggleX(0,0, (res)=>
          env.logger.info "Response " + res
        )

    _setStatus: (value) ->
      @_status = value
      @emit 'status', value

    getStatus: () =>
      Promise.resolve @_status


    destroy:() =>
      @device.removeListener('data', @handleData)
      super()


  class MerossActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>

      merossDevice = null
      merossDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => (device.config.class).indexOf("Meross")>= 0
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
