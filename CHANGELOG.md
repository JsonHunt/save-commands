## 0.6.1
* fixed issues with behavior of notification panel
* added 'suppress panel' setting

## 0.5.4
* panel will automatically hide after specified timeout if no errors were generates

## 0.5.2
* Removed output from stdout, kept output from stderr
* Removed panel header
* Added auto scrolling

## 0.5.1
* added batch commands for folders
* only one panel is now displayed
* removed fake options from menus

## 0.4.1
* configuration moved to save-commands.json
* commands now executed in sequence one after another
* using win-spawn for better command output
* added cwd config option

## 0.3.1
* Fixed path error for top-level project files
* relPath, absPath and relPathNoRoot now contain trailing separator
* added sep and relFullPath command options
* panel timeout moved out of the child process callback
* added better config description
* updated Readme.md
* added panel timeout duration to config
* added better handling of malformed configuration
* added newline support for output panels
* Fixed error when no commands are configured

## 0.1.0 - First Release
