
merge = Array.prototype.concat

$(document).on 'templateinit', (event) ->

  class MerossGaragedoorItem extends pimatic.DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)

    getItemTemplate: => 'meross-garagedoor'

    openGaragedoor: ->
      @device.rest.openGaragedoor(global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

    closeGaragedoor: ->
      @device.rest.closeGaragedoor(global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

  pimatic.templateClasses['meross-garagedoor'] = MerossGaragedoorItem
