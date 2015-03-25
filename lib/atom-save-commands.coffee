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

	convertCommand: (eventPath, command) ->
			relativePath = atom.project.relativize(eventPath)
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
		@hasError = false
		cmdDiv = document.createElement('div')
		cmdDiv.textContent = command
		cmdDiv.classList.add('command-name')
		@resultDiv.appendChild cmdDiv

		cmdarr = command.split(' ')
		command = cmdarr[0]
		args = _.rest(cmdarr)
		cspr = spawn command, args ,
			cwd: @config.cwd

		div = atom.workspaceView.find('.save-result')
		cspr.stdout.on 'data', (data)=>
			# cmdDiv = document.createElement('div')
			# cmdDiv.textContent = data.toString()
			# cmdDiv.classList.add('save-result-out')
			# @resultDiv.appendChild cmdDiv
			# div.scrollTop div.prop("scrollHeight")

		cspr.stderr.on 'data', (data)=>
			@hasError = true
			cmdDiv = document.createElement('div')
			cmdDiv.textContent = data.toString()
			cmdDiv.classList.add('save-result-error')
			@resultDiv.appendChild cmdDiv
			div.scrollTop div.prop("scrollHeight")

		cspr.stdout.on 'close', (code,signal)=>
			if not @hasError
				setTimeout ()=>
					@killPanel()
				, @config.timeout
			callback()

		cspr.stderr.on 'close', (code,signal)=>
			callback()

	activate: (state) ->
		@atomSaveCommandsView = new AtomSaveCommandsView(state.atomSaveCommandsViewState)
		@modalPanel = atom.workspace.addModalPanel(item: @atomSaveCommandsView.getElement(), visible: false)

		# Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
		@subscriptions = new CompositeDisposable

		# Register command that toggles this view
		@subscriptions.add atom.commands.add 'atom-workspace',
			'save-commands:executeOn': =>
				treeView = atom.packages.getLoadedPackage('tree-view')
				if treeView
					treeView = require(treeView.mainModulePath)
					packageObj = treeView.serialize()
					source = packageObj.selectedPath
					@executeOn(source)

		# console.log 'Save-commands registered text editor observer'
		@subscriptions.add atom.workspace.observeTextEditors (editor)=>
			# console.log "Registered onSave event with '#{editor.getPath()}'"
			@subscriptions.add editor.onDidSave (event)=> @executeOn(event.path)

		@panel = atom.workspace.addBottomPanel(
			item: document.createElement('div')
			visible: true
			priority: 300
		)

		# setTimeout ()=>
		# 	panel.destroy()
		# , @config.timeout

		# @commandDiv = document.createElement('div')
		# @commandDiv.classList.add('save-command')
		@resultDiv = document.createElement('div')
		@resultDiv.classList.add('save-result')

		# @panel.item.appendChild(@commandDiv)
		@panel.item.appendChild(@resultDiv)
		@panel.hide()

		@subscriptions.add atom.commands.add 'atom-workspace',
			'core:cancel': =>
				@killPanel()

	killPanel: ()->
		@panel.hide()
		# @commandDiv.textContent = ""
		@resultDiv.remove()
		@resultDiv = document.createElement('div')
		@resultDiv.classList.add('save-result')
		@panel.item.appendChild(@resultDiv)

	loadConfig: (callback)->
		confFile = atom.project.getPaths()[0] + path.sep + 'save-commands.json'
		fs.readFile confFile, (err,data)=>
			if data
				@config = JSON.parse(data)
			if err
				@config =
					timeout: 4000
					commands: []

			@config.cwd ?= atom.project.getPaths()[0]

			modCommands = []
			for gc in @config.commands
				kv = gc.split(':')
				modCommands.push
					glob: kv[0].trim()
					command: kv[1].trim()

			@config.commands = modCommands
			callback @config

	deactivate: ->
		@modalPanel.destroy()
		@subscriptions.dispose()
		@atomSaveCommandsView.destroy()

	serialize: ->
		atomSaveCommandsViewState: @atomSaveCommandsView.serialize()

	executeOn: (path)->
		@killPanel()
		@loadConfig ()=>
			@getFilesOn path, (files)=>
				commands = []
				for file in files
					commands = _.union commands, @getCommandsFor(file)
				if commands.length > 0
					@panel.show()
					async.eachSeries commands, @executeCommand.bind(@)

	getFilesOn: (absPath, callback)->
		fs.lstat absPath, (err,stats)=>
			if stats.isDirectory()
				fs.readdir absPath, (err,files)=>
					f = []
					async.eachSeries files, (file,fileCb)=>
						@getFilesOn "#{absPath}#{path.sep}#{file}", (filesX)->
							f = _.union f, filesX
							fileCb()
					, (err)->
						# console.log "Folder #{absPath} contains #{f.length} files"
						callback(f)

			if stats.isFile()
				callback [absPath]

	getCommandsFor: (file)->
		# console.log "Commands for #{file}:"
		commands = []
		for cmd in @config.commands
			relativePath = atom.project.relativize(file)
			if minimatch(relativePath, cmd.glob)
				commands.push @convertCommand(file, cmd.command)

		for com in commands
			console.log "  #{com}"
		return commands
