package uhx.sys;

import haxe.ds.ArraySort;
import haxe.io.Input;
import haxe.io.Output;
import haxe.Json;
import haxe.io.Bytes;
import sys.io.Process;
import haxe.ds.StringMap;
import haxe.io.BytesInput;
import haxe.DynamicAccess;
import haxe.io.BytesOutput;
import uhx.tuli.util.AlphabeticalSort;

using Lambda;
using Reflect;
using StringTools;
using sys.io.File;
using uhx.sys.Tuli;
using haxe.io.Path;
using sys.FileSystem;

private class Job {
	
	public var expression:EReg;
	public var memory:Array<String>;
	public var commands:Array<String>;
	public var variables:StringMap<String>;
	
	public var execute:EReg->Void = null;
	
	public function new(expression:EReg) {
		this.expression = expression;
		memory = [];
		commands = [];
		variables = new StringMap();
		
	}
	
}

private typedef CachedCommand = {
	var action:Action;
	var command:EReg->String;
}

private typedef PopulatedCommand = {
	var action:Action;
	var command:String;
}

private class BIO {
	
	public var stdin:Output;
	public var stdout:Input;
	public var stderr:Input;
	private var bytes:Bytes;
	
	public function new(bytes:Bytes, ?stdin:Output, ?stdout:Input, ?stderr:Input) {
		this.bytes = bytes;
		this.stdin = stdin == null ? new BytesOutput() : stdin;
		this.stdout = stdout == null ? new BytesInput(this.bytes) : stdout;
		this.stderr = stderr == null ? new BytesInput(this.bytes) : stderr;
	}
	
	public function close():Void {
		stdin.close();
		stdout.close();
		stderr.close();
		bytes = null;
	}
	
}

@:enum private abstract Action(Int) from Int to Int {
	public var PIPELINE = 0;			//	|
	public var REDIRECT_INPUT = 1;		//	<
	public var REDIRECT_OUTPUT = 2;		//	>
	public var APPEND = 3;				//	>>
	public var REDIRECT_STDIN = 4;		//	0>
	public var REDIRECT_STDOUT = 5;		//	1>
	public var REDIRECT_STDERR = 6;		//	2>
	public var NONE = 7;				//	No action
}

/**
 * ...
 * @author Skial Bainn
 */
class Tuli {
	
	public var config:DynamicAccess<Dynamic>;
	
	private var jobs:StringMap<Job>;
	private var defines:Array<String>;
	private var variables:StringMap<String>;
	private var environment:StringMap<String>;
	private var userEnvironment:StringMap<String>;
	
	public var allFiles:Array<String>;
	
	public function new(cf:String) {
		if ( cf == null ) throw 'The configuration file can not be null.';
		
		defines = [];
		jobs = new StringMap();
		variables = new StringMap();
		environment = Sys.environment();
		userEnvironment = new StringMap();
		config = Json.parse( cf.getContent() );
	}
	
	public function setupConfig():Void {
		setupTopLevel( config );
		setupJobs( config );
		
		allFiles = recurse( '${Sys.getCwd()}/${variables.exists("input") ? variables.get("input") : ""}/'.normalize() );
	}
	
	public function runJobs():Void {
		trace( defines );
		for (id in jobs.keys()) {
			var job = jobs.get( id );
			
			for (file in allFiles) if (job.expression.match( file )) {
				job.execute(job.expression);
				
				
			}
			
		}
	}
	
	/**
	 * Sets up `define`, `environment`, `variables` and any
	 * toplevel `if` statements.
	 */
	private function setupTopLevel(config:DynamicAccess<Dynamic>):Void {
		for (key in config.keys()) switch(key) {
			case 'define':
				defines = defines.concat( (config.get( key ):Array<String>) );
				
			case 'environment', 'env':
				setupEnvironment( config.get( key ) );
				
			case 'variables', 'var':
				variables = variables.concat( setupVariables( config.get( key ) ) );
				
			case 'if':
				for (config in conditional( config.get( key ) )) {
					setupTopLevel( config );
					setupJobs( config );
					
				}
				
			case _:
				// Ignore for now, need to setup `environment` and `variables`.
				
		}
	}
	
	private function setupEnvironment(config:DynamicAccess<Dynamic>):Void {
		var value = null;
		
		for (key in config.keys()) switch (key) {
			case 'if':
				for (config in conditional( config.get( key ) )) {
					setupEnvironment( config );
					
				}
				
			case _:
				value = '' + config.get( key );
				trace( key, value );
				if (value != null && !environment.exists( key )) {
					Sys.putEnv( key, value );
					
					environment.set( key, value );
					userEnvironment.set( key, value );
					
				}
				
		}
	}
	
	private function setupVariables(config:DynamicAccess<Dynamic>):StringMap<String> {
		var result = new StringMap<String>();
		var value = null;
		
		for (key in config.keys()) switch (key) {
			case 'if':
				for (config in conditional( config.get( key ) )) {
					result = result.concat( setupVariables( config ) );
					
				}
				
			case _:
				value = config.get( key );
				trace( key, value );
				if (value != null && !result.exists( key )) result.set( key, value );
			
		}
		
		return result;
	}
	
	/**
	 * Anything not `variables`, `environment`, `define`, `if` or one of
	 * their short forms gets treated as a regular expression.
	 */
	private function setupJobs(config:DynamicAccess<Dynamic>):Void {
		for (key in config.keys()) switch(key) {
			case 'variables', 'environment', 'var', 'env', 'if', 'define':
				// Skip these.
				
			case _:
				var job = new Job( new EReg( key.indexOf("${") > -1 ? substitution( key )(null) : key, '') );
				populateJob(job, config.get( key ));
				prepareJob(job);
				jobs.set( key, job );
				
		}
	}
	
	private function populateJob(job:Job, data:DynamicAccess<Dynamic>):Void {
		for (key in data.keys()) switch (key) {
			case 'variables', 'var':
				job.variables = job.variables.concat( setupVariables( data.get( key ) ) );
				
			case 'commands', 'cmd':
				job.commands = job.commands.concat( (data.get( key ):Array<String>) );
				
			case 'memory', 'mem':
				job.memory = job.memory.concat( (data.get( key ):Array<String>) );
				
			case 'if':
				for (data in conditional( data.get( key ) )) {
					populateJob(job, data);
					
				}
				
			case _:
		}
	}
	
	public function prepareJob(job:Job):Void {
		var commands = [for (cmd in job.commands) actions(cmd)];
		job.execute = function(e:EReg) {
			for (actions in commands) {
				run( [for(action in actions(e)) { action:action.action, command:action.command(e) }] );
			}
		}
	}
	
	/**
	 * Replace `${name}` with a matching value from `variables` or `environment`.
	 * Replace `$0` with whatever is returned by the `ereg` regular expression.
	 */
	private function substitution(value:String, ?ereg:EReg):EReg->String {
		var sections:Array<EReg->String> = [];
		var i = -1;
		var result = '';
		
		// Look for `${variable_name}` statements and replace
		// with a match from either variables or environments.
		while (i++ < value.length) switch (value.fastCodeAt(i)) {
			case '$'.code if (value.fastCodeAt(i + 1) == '{'.code):
				var id = '';
				var j = i + 1;
				var code = -1;
				
				while (j++ < value.length) switch (code = value.fastCodeAt(j)) {
					case '}'.code: 
						break;
						
					case _:
						id += String.fromCharCode( code );
						
				}
				
				// Remove any surrounding whitespace.
				id = id.trim();
				var exists = false;
				
				// See if the value exists and add it if it does.
				if (exists = variables.exists( id )) {
					sections.push( function(s, _) { return s + variables.get(id); }.bind(new String(result), _) );
					result = '';
					
				} else if (exists = environment.exists( id )) {
					sections.push( function(s, _) { return s + environment.get(id); }.bind(new String(result), _) );
					result = '';
					
				}
				
				if (exists) i = j;
				
			case '$'.code if (isCharacter(value.fastCodeAt(i + 1))):
				var id = '';
				var j = i;
				var code = -1;
				
				while (j++ < value.length) switch (code = value.fastCodeAt(j)) {
					case _ if(!isCharacter(code) && !isNumerical(code) && code != '_'.code):
						break;
						
					case _:
						id += String.fromCharCode( code );
						
				}
				
				var exists = false;
				
				// See if the value exists and add it if it does.
				if (exists = variables.exists( id )) {
					sections.push( function(s, _) { return s + variables.get(id); }.bind(new String(result), _) );
					result = '';
					
				} else if (exists = environment.exists( id )) {
					sections.push( function(s, _) { return s + environment.get(id); }.bind(new String(result), _) );
					result = '';
					
				}
				
				if (exists) i = j;
				
			case '$'.code if (ereg != null && isNumerical(value.fastCodeAt(i + 1))):
				var id = '';
				var no = -1;
				var j = i;
				
				while (j++ < value.length) switch (value.fastCodeAt(j)) {
					case x if (x >= '0'.code && x <= '9'.code):
						id += String.fromCharCode(x);
						
					case _:
						break;
						
				}
				
				// Remove any surrounding whitespace.
				id = id.trim();
				no = Std.parseInt( id );
				
				// See if the value exists and add it if it does.
				if (no != null) {
					i = j;
					
					sections.push( function(s:String, i:Int, e:EReg) { return s + e.matched( no ); } .bind(new String(result), no, _) );
					result = '';
					
				}
				
			case _:
				result += value.charAt(i);
				
		}
		
		if (result != null && result != '') sections.push( function(_) return new String(result) );
		
		return function(e:EReg) {
			var buffer = new StringBuf();
			for (section in sections) buffer.add( section(e) );
			return buffer.toString();
		}
	}
	
	private function actions(value:String):EReg->Array<CachedCommand> {
		var i = -1;
		var code = -1;
		var action = Action.NONE;
		var command = '';
		var results:Array<CachedCommand> = [];
		
		while (i++ < value.length) switch (code = value.fastCodeAt(i)) {
			case '|'.code:
				results.push( { action:action, command:function(s, e) { return substitution(s, e)(e); }.bind(new String(command.trim()), _) } );
				action = Action.PIPELINE;
				command = '';
				
			case '<'.code:
				results.push( { action:action, command:function(s, e) { return substitution(s, e)(e); }.bind(new String(command.trim()), _) } );
				action = Action.REDIRECT_INPUT;
				command = '';
				
			case '>'.code:
				results.push( { action:action, command:function(s, e) { return substitution(s, e)(e); }.bind(new String(command.trim()), _) } );
				action = Action.REDIRECT_OUTPUT;
				command = '';
				
			case x if (x >= '0'.code && x <= '2'.code && value.fastCodeAt(i+1) == '>'.code):
				results.push( { action:action, command:function(s, e) { return substitution(s, e)(e); }.bind(new String(command.trim()), _) } );
				action = switch(x) {
					case 0: Action.REDIRECT_STDIN;
					case 1: Action.REDIRECT_STDOUT;
					case 2: Action.REDIRECT_STDERR;
					case _: -1;
				};
				command = '';
				
			case _:
				if (code != null) command += String.fromCharCode( code );
				
		}
		
		if (command != '') results.push( { action:action, command:function(s, e) { return substitution(s, e)(e); } .bind(new String(command.trim()), _) } );
		
		/**
		 * `cat < C:/path/to/File.md > C:/path/to/Output.md`
		 * results = [
		 * 		{command:'cat', action:Action.NONE},
		 * 		{command:'C:/path/to/File.md', action:Action.REDIRECT_INPUT},
		 * 		{command:'C:/path/to/Output.md', action:Action.REDURECT_OUTPUT},
		 * ]
		 * ------
		 * Needs to convert to:
		 * results = [
		 * 		{command:'C:/path/to/File.md', action:Action.NONE},
		 * 		{command:'cat', action:Action.REDIRECT_OUTPUT},
		 * 		{command:'C:/path/to/Output.md', action:Action.REDIRECT_OUTPUT},
		 * ]
		 * -----
		 */
		for (i in 0...results.length) {
			if (results[i] != null && results[i].action == Action.REDIRECT_INPUT) {
				results[i].action = Action.NONE;
				results.insert(i - 1, results[i]);
				results[i + 1] = null;
				
			}
			
			
		}
		
		var filtered = results.filter( function(f) return f != null );
		
		return function(e:EReg) return filtered;
	}
	
	private function run(actions:Array<PopulatedCommand>):Void {
		var previous:Process = null;
		var collection:Array<Process> = [];
		
		var index:Int = 0;
		var current:Process = null;
		var parts:Array<String> = [];
		
		for (action in actions) {
			switch (action.action) {
				case Action.NONE if (action.command.isAbsolute() && action.command.exists()):
					trace( 'creating file read : ${action.command}' );
					index = collection.push( current = cast {
						stdin:null,
						stdout:File.read( action.command ),
						stderr:null,
						name:new String(action.command),
						close:function() untyped __this__.stdout.close(),
					} ) -1;
					
				case Action.PIPELINE | Action.REDIRECT_OUTPUT if (action.command.isAbsolute()):
					trace( 'creating file write : ${action.command}' );
					index = collection.push( current = cast {
						stdin:File.write( action.command ),
						stdout:null,
						stderr:null,
						name:new String(action.command),
						close:function() untyped __this__.stdin.close(),
					} ) -1;
					
				case _:
					trace( 'creating process : ${action.command}' );
					parts = action.command.split(' ');
					index = collection.push( current = new Process(parts.shift(), parts) ) - 1;
					
			}
			
		}
		
		var length = collection.length - 1;
		for (i in 0...collection.length) if (i + 1 <= length) {
			var current = collection[i];
			var next = collection[i + 1];
			next.stdin.writeInput( current.stdout );
			next.stdin.close();
		}
		
		for (item in collection) try item.close() catch (e:Dynamic) { };
		
	}
	
	private function bypass(a:Bool):Bool {
		return a;
	}
	
	private function and(a:Bool, b:Bool):Bool {
		return a && b;
	}
	
	private function or(a:Bool, b:Bool):Bool {
		return a || b;
	}
	
	/**
	 * Converts `value` into a boolean based on its
	 * existence in `defines`.
	 */
	private function toBoolean(value:String):Bool {
		var index = -1;
		var bool = true;
		var name = '';
		
		while (index++ < value.length) switch (value.fastCodeAt(index)) {
			case '!'.code if (value.fastCodeAt(index + 1) > ' '.code):
				bool = !bool;
				
			case ' '.code:
				
			case _:
				name += value.charAt(index);
				
		}
		
		return bool ? defines.indexOf( name ) > -1 : defines.indexOf( name ) == -1;
	}
	
	/**
	 * Find the next `&&` or `||` binop and return its `index-1`.
	 */
	private function nextBinop(value:String):Int {
		var index = -1;
		var result = value.length;
		
		while (index++ < value.length) switch(value.fastCodeAt(index)) {
			case x if (['|'.code, '&'.code].indexOf(x) > -1 && value.fastCodeAt(index + 1) == x):
				result = index-1;
				break;
				
			case _:
				
		}
		
		return result;
	}
	
	/**
	 * Return an array containing objects whos `key` evaluates to `true`.
	 */
	private function conditional(object:DynamicAccess<Dynamic>):Array<Dynamic> {
		var results:Array<Dynamic> = [];
		trace( defines );
		for (key in object.keys()) {
			var index = -1;
			var value = '';
			var result:Bool->Bool = bypass;
			
			while (index++ < key.length) switch(key.fastCodeAt(index)) {
				case '&'.code if (key.fastCodeAt(index + 1) == '&'.code):
					index += 1;
					result = and.bind( result( toBoolean(value) ), _ );
					
				case '|'.code if (key.fastCodeAt(index + 1) == '|'.code):
					index += 1;
					result = or.bind( result( toBoolean(value) ), _ );
					
				case _:
					var nextPos = nextBinop( key.substring(index) );
					value = key.substring(index, index + nextPos).trim();
					index += nextPos;
					
			}
			
			if (result( toBoolean( value ) )) {
				results.push( object.get( key ) );
				
			}
			
		}
		
		return results;
	}
	
	/**
	 * Return a list of files contained within the `path`.
	 */
	private static function recurse(path:String) {
		var results = [];
		path = path.normalize();
		if (path.isDirectory()) for (directory in path.readDirectory()) {
			var current = '$path/$directory/'.normalize();
			if (current.isDirectory()) {
				results = results.concat( recurse( current ) );
			} else {
				results.push( current );
			}
		}
		
		return results;
	}
	
	// Recursively create the directory in `config.output`.
	private function createDirectory(path:String) {
		if (!path.directory().addTrailingSlash().exists()) {
			
			var parts = path.directory().split('/');
			var missing = [parts.pop()];
			
			while (!Path.join( parts ).normalize().exists()) missing.push( parts.pop() );
			
			missing.reverse();
			
			var directory = Path.join( parts );
			for (part in missing) {
				directory = '$directory/$part/'.normalize().replace(' ', '-');
				if (!directory.exists()) FileSystem.createDirectory( directory );
			}
			
		}
	}
	
	//// STATICS
	
	private static function concat(a:StringMap<String>, b:StringMap<String>):StringMap<String> {
		var map = new StringMap<String>();
		
		for (x in [a, b]) for (key in x.keys()) map.set(key, x.get( key ));
		
		return map;
	}
	
	private inline static function isNumerical(value:Int):Bool {
		return value >= '0'.code && value <= '9'.code;
	}
	
	private inline static function isCharacter(value:Int):Bool {
		return value >= 'a'.code && value <= 'z'.code || value >= 'A'.code && value <= 'Z'.code;
	}
	
}