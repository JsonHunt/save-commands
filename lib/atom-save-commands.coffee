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
			title: 'Glob : command'
			description: '''
				Executes commands on save for files matching the glob.
				Command can contain parameters:
				{absPath}: absolute path of the saved file (without file name)
				{relPath}: relative path of the saved file (without file name)
				{relFullPath}: like relPath but with filename
				{relPathNoRoot}: relative path without top folder
				{filename}: file name and extension
				{name}: file name without extension
				{ext}: file extension
				{sep}: os specific path separator

				To configure multiple globs, use File -> Open your config
			'''
		timeoutDuration:
			type: 'integer'
			default: '4000'
			title: 'Output panel timeout duration in ms'


	activate: (state) ->
		@atomSaveCommandsView = new AtomSaveCommandsView(state.atomSaveCommandsViewState)
		@modalPanel = atom.workspace.addModalPanel(item: @atomSaveCommandsView.getElement(), visible: false)

		# Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
		@subscriptions = new CompositeDisposable

		# Register command that toggles this view
		@subscriptions.add atom.commands.add 'atom-workspace', 'save-commands:toggle': => @toggle()

		# console.log 'Save-commands registered text editor observer'
		@subscriptions.add atom.workspace.observeTextEditors (editor)=>
			# console.log "Registered onSave event with '#{editor.getPath()}'"
			@subscriptions.add editor.onDidSave (event)=>
				timeoutMs = atom.config.get('save-commands.timeoutDuration')
				arr = atom.config.get('save-commands.saveCommands')
				return if arr is undefined
				for gc in arr
					kv = gc.split(':')
					if kv.length isnt 2
						epanel = atom.workspace.addBottomPanel(
							item: document.createElement('div')
							visible: true
							priority: 100
						)
						resultDiv = document.createElement('div')
						resultDiv.classList.add('save-result')
						resultDiv.classList.add('save-result-visible')
						resultDiv.classList.add('save-result-error')
						resultDiv.textContent = """
							Malformed save command:
							#{gc}

							Usage: glob : command
						"""
						epanel.item.appendChild(resultDiv)

						setTimeout ()->
							epanel.destroy()
						, timeoutMs

						continue

					glob = kv[0].trim()
					command = kv[1].trim()
					relativePath = atom.project.relativize(event.path)
					if minimatch(relativePath, glob)
						apo = path.parse event.path
						rpo = path.parse relativePath
						model = {}
						model.absPath = apo.dir + path.sep
						model.relPath = rpo.dir
						index = rpo.dir.indexOf(path.sep)
						model.relPathNoRoot = rpo.dir.substr(index) if index isnt -1
						model.relPathNoRoot = '' if index is -1

						if model.relPath isnt ''
							model.relPath += path.sep

						if model.relPathNoRoot isnt ''
							model.relPathNoRoot += path.sep

						# model.absPath = path.normalize model.absPath
						# model.relPath = path.normalize model.relPath
						# model.relPathNoRoot = path.normalize model.relPathNoRoot

						model.name = rpo.name
						model.ext = rpo.ext
						model.filename = rpo.base

						model.relFullPath = model.relPath + model.filename
						model.sep = path.sep

						for key,value of model
							fkey = '{' + key + '}'
							command = S(command).replaceAll(fkey,value).s

						panel = atom.workspace.addBottomPanel(
							item: document.createElement('div')
							visible: true
							priority: 100
						)

						setTimeout ()=>
							panel.destroy()
						, timeoutMs

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
