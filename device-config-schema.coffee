module.exports = {
  title: "pimatic-meross device config schemas"
  MerossGaragedoor: {
    title: "MerossGaragedoor config options"
    type: "object"
    extensions: ["xAttributeOptions"]
    properties:{
      region:
        description: "The region"
        type: "string"
      devIconId:
        description: "The device icon"
        type: "string"
      fmwareVersion:
        description: "The firmware version number"
        type: "string"
      hdwareVersion:
        description: "The hardware version number"
        type: "string"
    }
  },
  MerossSmartplug: {
    title: "MerossSmartplug config options"
    type: "object"
    extensions: ["xAttributeOptions"]
    properties:{
      region:
        description: "The region"
        type: "string"
      devIconId:
        description: "The device icon"
        type: "string"
      fmwareVersion:
        description: "The firmware version number"
        type: "string"
      hdwareVersion:
        description: "The hardware version number"
        type: "string"
    }
  },
  MerossSmartplugEnergy: {
    title: "MerossSmartplugEnergy config options"
    type: "object"
    extensions: ["xAttributeOptions"]
    properties:{
      region:
        description: "The region"
        type: "string"
      devIconId:
        description: "The device icon"
        type: "string"
      fmwareVersion:
        description: "The firmware version number"
        type: "string"
      hdwareVersion:
        description: "The hardware version number"
        type: "string"
      polltimeElectricity:
        description: "The electricity stats polling time in seconds"
        type: "number"
        default: 5
      polltimeConsumption:
        description: "The (daily) consumption stats polling time in seconds"
        type: "number"
        default: 86400
    }
  }
}
