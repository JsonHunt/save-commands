minimatch = require 'minimatch'
child_process = require 'child_process'
path = require 'path'
S = require 'string'
spawn = require 'win-spawn'
_ = require 'underscore'
fs = require 'fs'
async = require 'async'

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

	showError: (gc)->
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
		, @config.timeout

	convertCommand: (eventPath, relativePath, command) ->
			apo = path.parse eventPath
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
			model.name = rpo.name
			model.ext = rpo.ext
			model.filename = rpo.base
			model.relFullPath = model.relPath + model.filename
			model.sep = path.sep
			for key,value of model
				fkey = '{' + key + '}'
				command = S(command).replaceAll(fkey,value).s
			command

	executeCommand: (command, callback) ->
		@priority -= 10
		panel = atom.workspace.addBottomPanel(
			item: document.createElement('div')
			visible: true
			priority: @priority
		)

		setTimeout ()=>
			panel.destroy()
		, @config.timeout

		commandDiv = document.createElement('div')
		commandDiv.classList.add('save-command')
		resultDiv = document.createElement('div')
		resultDiv.classList.add('save-result')

		panel.item.appendChild(commandDiv)
		panel.item.appendChild(resultDiv)

		commandDiv.textContent = command
		# console.log "Executing command #{command}\nin #{atom.project.getPaths()[0]}"
		# @atomSaveCommandsView.message.textContent = ""
		cmdarr = command.split(' ')
		command = cmdarr[0]
		args = _.rest(cmdarr)
		cspr = spawn command, args ,
			cwd: atom.project.getPaths()[0]

		resultDiv.classList.add('save-result-visible')
		cspr.stdout.on 'data', (data)->
			resultDiv.textContent += data.toString()

		cspr.stderr.on 'data', (data)->
			resultDiv.textContent += data.toString()
			resultDiv.classList.add('save-result-error')

		cspr.stdout.on 'close', (code,signal)->
			callback()
		cspr.stderr.on 'close', (code,signal)->
			callback()

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
				@priority = 300
				confFile = atom.project.getPaths()[0] + path.sep + 'save-commands.json'
				fs.readFile confFile, (err,data)=>
					if data
						@config = JSON.parse(data)
					if err
						@config =
							timeout: 4000
							commands: []

					#timeoutMs = config.timeout # atom.config.get('save-commands.timeoutDuration')
					arr = @config.commands # atom.config.get('save-commands.saveCommands')

					return if arr is undefined
					cmdqueue = []
					for gc in arr
						kv = gc.split(':')
						if kv.length isnt 2
							@showError(gc)
							continue

						glob = kv[0].trim()
						command = kv[1].trim()
						relativePath = atom.project.relativize(event.path)
						if minimatch(relativePath, glob)
							command = @convertCommand(event.path, relativePath, command)
							cmdqueue.push command

					async.eachSeries cmdqueue, @executeCommand.bind(@), (err,result)->

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
