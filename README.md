# atom-save-commands package

This package allows you to assign parametrized shell commands
to file globs to be automatically run whenever the file is saved.  
The command(s) and their output will be briefly displayed in a panel at the bottom of the screen.  
This effectively eliminates the need for file watchers, and simplifies your build process.

### How to use

At the time this package was developed, Atom didn't have a good GUI support for configuration items with array type, so after installing the package,
go to File -> Open your config.  
Locate atom-save-commands: saveCommands array.

Create one entry for each command you wish to run, and assign it to a glob like this:  
glob : command {parameter}


### Available parameters:  
- absPath: absolute path of the saved file (without file name)  
- relPath: relative path of the saved file (without file name)  
- relPathNoRoot: relative path without top folder  
- filename: file name and extension  
- name: file name without extension  
- ext: file extension  

### Sample config.cson

"atom-save-commands":  
  saveCommands: [  
    "src/\*\*/\*.coffee : coffee --compile --map -o build/{relPathNoRoot} {relPath}/{filename}"  
    "src/\*\*/\*.jade : jade -P {relPath}/{filename} -o build/{relPathNoRoot}"  
    "src/\*\*/\*.styl : stylus {relPath}/{filename} --out build/{relPathNoRoot}"  
    "src/\*\*/\*.coffee : mocha --compilers coffee:coffee-script/register"  
    "test/\*\*/\*.coffee : mocha --compilers coffee:coffee-script/register"
  ]

This sample makes Atom automatically compile all CoffeeScript
files from 'src' directory tree into 'build' directory, keeping the folder structure.  
All Jade templates and Stylus files are compiled in a similar fashion.  
In addition, Atom will run mocha test specs in 'test' folder whenever any of the specs or source files is modified and saved.
