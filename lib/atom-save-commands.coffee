minimatch = require 'minimatch'
child_process = require 'child_process'
path = require 'path'
S = require 'string'

AtomSaveCommandsView = require './atom-save-commands-view'
{CompositeDisposable} = require 'atom'

module.exports = AtomSaveCommands =
  atomSaveCommandsView: null
  modalPanel: null
  subscriptions: null

  config:
    saveCommands:
      type: 'array'
      default: []
      items:
        type: 'string'
      title: 'Glob : command on save'
      description: '''
        Command can contain parameters {...}
      '''

  activate: (state) ->
    console.log "Project paths: " + atom.project.getPaths()
    @atomSaveCommandsView = new AtomSaveCommandsView(state.atomSaveCommandsViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @atomSaveCommandsView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-save-commands:toggle': => @toggle()

    # console.log 'Save-commands registered text editor observer'
    @subscriptions.add atom.workspace.observeTextEditors (editor)=>
      # console.log "Registered onSave event with '#{editor.getPath()}'"
      @subscriptions.add editor.onDidSave (event)=>
        arr = atom.config.get('atom-save-commands.saveCommands')
        for gc in arr
          kv = gc.split(':')
          glob = kv[0].trim()
          command = kv[1].trim()
          relativePath = atom.project.relativize(event.path)
          if minimatch(relativePath, glob)
            apo = path.parse event.path
            rpo = path.parse relativePath
            model = {}
            model.absPath = apo.dir
            model.relPath = rpo.dir
            index = rpo.dir.indexOf(path.sep)
            model.relPathNoRoot = rpo.dir.substr(index) if index isnt -1
            model.relPathNoRoot = '' if index is -1
            model.name = rpo.name
            model.ext = rpo.ext
            model.filename = rpo.base
            for key,value of model
              fkey = '{' + key + '}'
              command = S(command).replaceAll(fkey,value).s

            panel = atom.workspace.addBottomPanel(
              item: document.createElement('div')
              visible: true
              priority: 100
            )
            commandDiv = document.createElement('div')
            commandDiv.classList.add('save-command')
            resultDiv = document.createElement('div')
            resultDiv.classList.add('save-result')

            panel.item.appendChild(commandDiv)
            panel.item.appendChild(resultDiv)

            commandDiv.textContent = command
            # console.log "Executing command #{command}\nin #{atom.project.getPaths()[0]}"
            # @atomSaveCommandsView.message.textContent = ""
            child_process.exec command, { cwd: atom.project.getPaths()[0], timeout: 2000 }, (error, stdout, stderr) =>
              resultDiv.classList.add('save-result-visible')
              if error
                # @atomSaveCommandsView.message.textContent += '\n'+ error.toString()
                resultDiv.textContent += '\n'+ error.toString()
                resultDiv.classList.add('save-result-error')
                # console.log error.toString()
              if stdout
                # @atomSaveCommandsView.message.textContent += '\n'+ stdout
                resultDiv.textContent += '\n'+ stdout

                # console.log stdout
              if stderr
                # @atomSaveCommandsView.message.textContent += '\n'+ stderr
                resultDiv.textContent += '\n'+ stderr
                # console.log stderr
              # @modalPanel.show()
              if !error and !stderr and !stdout
                resultDiv.textContent += "Done."


              setTimeout ()=>
                panel.destroy()
              ,4000

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomSaveCommandsView.destroy()

  serialize: ->
    atomSaveCommandsViewState: @atomSaveCommandsView.serialize()

  toggle: ->
    console.log 'AtomSaveCommands was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
