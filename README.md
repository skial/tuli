# Tuli

> Swahili for static

## Installation

With haxelib git.

```
haxelib git tuli https://github.com/skial/tuli master src
```	
	
With haxelib local.

```
# Download the archive.
https://github.com/skial/tuli/archive/master.zip

# Install archive contents.
haxelib local master.zip
```

## Reservered Keywords

+ `var`, `variables`
+ `env`, `environment`
+ `cmd`, `commands`
+ `mem`, `memory`
+ `pre`, `prerequisites`
+ `define`
+ `if`

## Keyword Scopes

+ global scope
	- `if`

+ toplevel scope
	- `var`, `variables`
	- `env`, `environment`
	- `define`

+ section scope
	- `pre`, `prerequisites`
	
+ job scope
	- `var`, `variables`
	- `cmd`, `commands`
	- `mem`, `memory`
	
The following code example explains the above scopes.

```json
{
	"toplevel":{
		"local":{
			
		}
	},
	"toplevel":{
		"local":{
			"if":{
				
			}
		},
		"if":{
			
		}
	},
	"if":{
		
	}
}
```

## Introduction

Tuli accepts a `json` file, looking for by default, a file named `config.json`.
Anything not a [reservered keyword](#reservered-keywords) in the toplevel or global
[scope](#keyword-scopes) will be treated as a Haxe [regular expression][l1].

A basic `config.json` file looks like the following.

```json
{
	"([a-zA-Z0-9~/:]+).md$":{
		"cmd":[
			"$0 | marked | $1.html"
		]
	}
}
```

### Rectification

#### Regular Expression Groups

```json
{
	"([a-zA-Z0-9~/:]+).md$":{
		"cmd":[
			"$0 | marked | $1.html"
		]
	}
}
```

The example above provides a regular expression grouping everything up to
`.md` of the path.

To access a group, use dollar `$` followed by an integer representing an index, 
where the index starts at `1`. To access the original matched path use `$0`.

#### Variables and Environment

```json
{
	"var":{
		"path":"([a-zA-Z0-9~/:]+)"
	},
	"(${path}).md$":{
		"cmd":[
			"$0 | marked | $1.html"
		]
	},
	"(${path}).js$":{
		"cmd":[
			"$0 | uglifyjs - --compress --mangle | $1.min.js
		]
	}
}
```

To access a variable or environment value, use `${` followed by the variables
or environments name followed by a closing bracket `}`. Variable names are always 
assessed before environment names.

[l2]: http://haxe.org/manual/lf-string-interpolation.html "Haxe String Interpolation"
[l1]: http://haxe.org/manual/std-regex.html "Haxe Regular Expressions"

