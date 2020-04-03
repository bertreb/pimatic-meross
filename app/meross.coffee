
merge = Array.prototype.concat

$(document).on 'templateinit', (event) ->

  class MerossGaragedoorItem extends pimatic.DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)

    getItemTemplate: => 'meross-garagedoor'

    onButtonPressed: (buttonID) ->
      @device.rest.buttonPressed({buttonId: "#{buttonID}"},global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

  pimatic.templateClasses['meross-garagedoor'] = MerossGaragedoorItem
