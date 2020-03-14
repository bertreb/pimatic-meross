module.exports = {
  title: "Meross"
  type: "object"
  properties:
    username:
      description: "The Meross username"
      type: "string"
      required: true
    password:
      description: "The Meross password"
      type: "string"
      required: true
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
}
