# Tuli

> Swahili for static

Its basic goal is to be a static site generator. 

You can register interest in a specific file extension, either on detection
or after creation of that specific file extension.

You can register to add new data to the global `Tuli.config` variable before or
after creation of files.

You can also register handlers to be run when everything is being created and saved.

## Installation

You will need to install the following libraries through `haxelib git <name> <url>
<branch> <folder>` or clone them locally and run `haxelib local <zip>`

1. uhu: 
	+ git - `haxelib git uhu https://github.com/skial/uhu experimental src`
	+ zip:
		* download - `https://github.com/skial/uhu/archive/experimental.zip`
		* install - `haxelib local experimental.zip`
2. klas:
	+ git - `haxelib git klas https://github.com/skial/klas master src`
	+ zip:
		* download - `https://github.com/skial/klas/archive/master.zip`
		* install - `haxelib local master.zip`
		
For any HTML file to be parsed correctly a program is required to turn it into valid
XML so the `Xml` class can parse it without croaking.

1. tidy - `http://w3c.github.io/tidy-html5/`

## Setup

You will need to create a `config.json` file in the root directory you will be running
Tuli in.

Heres the basics you will need in `config.json` -

```
{
	"input":"path/to/input/folder",
	"output":"path/to/output/folder",
	"ignore":["hx"]
}
```

Then make sure a class `implements Klas` and you have `-lib klas` and `-lib uhu` in
your `.hxml` build file.

To register interest in any markdown files that already exist, first create a static
`initialize` method. In side add -

```
Tuli.onExtension('md', Your.handler, Before);
```

then in your `.hxml` build file add -

```
--macro path.to.you.Class.initialize()
```

For safety its best to wrap all Tuli callbacks in a conditional `#if macro` and 
`#end` statement.