# Save-commands package for Atom editor

This package allows you to define parametrized shell commands
to be automatically run, in sequence, whenever a file matching glob pattern is saved.  
You can define as many globs and commands as you want.
The command(s) and their output will be displayed in a panel at the bottom of the screen. Hit 'Esc' to dismiss the panel.

Right click on a tree view file and select "Run save-commands" to run all commands mapped to this file. Selecting a folder will run proper run commands on all files contained in it (recursively).

This effectively eliminates the need for file watchers, and simplifies your build process.

### How to use

Can set up with global configurations
### Sample config.cson for global configurations
```
"save-commands":
	"timeout": 5000,
	commands: []
```

Create save-commands.json file in your project's root folder to override the global settings
Create one entry for each command you wish to run, and assign it to a glob like this:  
glob : command {parameter}

Your save-commands.json should look similar to this:
```
{
	"timeout": 4000,
	"commands": [
		"src/**/*.coffee : coffee -c --map -o gen{relPathNoRoot} {relPath}/{filename}",
		"src/**/*.jade   : jade -P {relPath}/{filename} -o gen/{relPathNoRoot}",
		"src/**/*.styl   : stylus {relPath}/{filename} --out gen/{relPathNoRoot}"
		"test/**/*.coffee : mocha --compilers coffee:coffee-script/register"
	]
}
```

Optionally, you can add "cwd" property to define custom working directory. By default, it is your project root.

### Available parameters:  
- absPath: absolute path of the saved file (without file name)  
- relPath: relative path of the saved file (without file name)  
- relFullPath: like relPath but with filename
- relPathNoRoot: relative path without top folder  
- filename: file name and extension  
- name: file name without extension  
- ext: file extension  
- sep: os specific path separator



This sample makes Atom automatically compile all CoffeeScript
files from 'src' directory tree into 'build' directory, keeping the folder structure.  
All Jade templates and Stylus files are compiled in a similar fashion.  
In addition, Atom will run mocha test specs in 'test' folder whenever any of the specs or source files is modified and saved.

## Related packages

### [Auto-panes](https://github.com/JsonHunt/atom-auto-panes)

Take a look at one of my other packages, [auto-panes](https://github.com/JsonHunt/atom-auto-panes).
It is great for workflows where you work with related files, such as html-css-js, coffee-jade-scss, coffee-js, styl-css, etc.

It automatically opens related files with the same name in separate panels, automatically closes editors and panels when you open new file, and automatically saves modified files.

### [Make coffee](https://github.com/JsonHunt/make-coffee)

Great tool when you are migrating a project from JavaScript to CoffeeScript. Adds an option 'Make me a coffee' to .js files in tree-view.
