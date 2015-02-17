module.exports =
class AtomSaveCommandsView
  constructor: (serializeState) ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('atom-save-commands')

    # Create message element
    @message = document.createElement('div')
    @message.textContent = "The AtomSaveCommands package is Alive! It's ALIVE!"
    @message.classList.add('message')
    @element.appendChild(@message)

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element
