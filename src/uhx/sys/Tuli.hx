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
using haxe.io.Path;
using sys.FileSystem;

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
	
	private var defines:Array<String>;
	private var variables:StringMap<String>;
	private var environment:StringMap<String>;
	private var userEnvironment:StringMap<String>;
	
	private var eregMap:StringMap<EReg>;
	private var memoryMap:StringMap<BIO>;
	
	public var allFiles:Array<String>;
	
	public function new(cf:String) {
		if ( cf == null ) throw 'The configuration file can not be null.';
		
		defines = [];
		eregMap = new StringMap();
		variables = new StringMap();
		memoryMap = new StringMap();
		environment = Sys.environment();
		userEnvironment = new StringMap();
		config = Json.parse( cf.getContent() );
		
		var values:DynamicAccess<Dynamic>;
		
		for (key in config.keys()) switch(key) {
			case 'define':
				defines = defines.concat( (config.get( key ):Array<String>) );
				
			case 'environment', 'env':
				values = config.get( key );
				
				for (key in values.keys()) {
					var name = key;
					var value = values.get( key );
					
					if (value != null && !environment.exists( name )) {
						Sys.putEnv( name, value );
						
						environment.set( name, value );
						userEnvironment.set( name, value );
						
					}
					
				}
				
			case 'variables', 'var':
				values = config.get( key );
				
				for (key in values.keys()) {
					var name = key;
					var value = values.get( key );
					
					if (value != null && !variables.exists( name )) variables.set( name, value );
					
				}
				
			case 'if':
				trace( conditional( config.get( key ) ) );
				
			case _:
				// Ignore for now, need to setup `environment` and `variables`.
				
		}
		
		for (key in config.keys()) switch(key) {
			case 'variables', 'environment', 'var', 'env', 'if', 'define':
				// Skip these.
				
			case _ if (key.indexOf("${") > -1):
				eregMap.set( key, new EReg( substitution( key ), '' ) );
				
			case _:
				eregMap.set( key, new EReg(key, '') );
				
		}
		
		allFiles = recurse( '${Sys.getCwd()}/${variables.exists("input") ? variables.get("input") : ""}/'.normalize() );
		
		for (id in eregMap.keys()) {
			var ereg = eregMap.get( id );
			var content:DynamicAccess<Array<String>> = config.get( id );
			
			// Make sure `#` and `cmd` are at the front.
			var defaults = ['#', 'cmd'].filter( function(d) return content.exists(d) );
			var keys = defaults.concat( [for (k in content.keys()) k].filter( function(k) return defaults.indexOf( k ) == -1 ) );
			
			for (file in allFiles) if (ereg.match( file )) {
				for (key in keys) switch (key) {
					case 'memory', 'mem':
						for (value in content.get( key )) {
							memoryMap.set( '$id$key', new BIO( Bytes.alloc( file.stat().size ) ) );
						}
						
					case 'commands', 'cmd':
						for (value in content.get( key )) {
							run( actions( substitution( value, ereg ) ) );
							
						}
						
					case _:
						continue;
						
				}
				
			}
			
		}
		
	}
	
	/**
	 * Replace `${name}` with a matching value from `variables` or `environment`.
	 * Replace `$0` with whatever is returned by the `ereg` regular expression.
	 */
	private function substitution(value:String, ?ereg:EReg):String {
		var i = -1;
		var result = '';
		
		// Look for `${variable_name}` statements and replace
		// with a match from either variables or environments.
		while (i++ < value.length) switch (value.fastCodeAt(i)) {
			case '$'.code if (value.fastCodeAt(i + 1) == '{'.code):
				var id = '';
				var j = i + 2;
				
				while (true) switch (value.fastCodeAt(j)) {
					case '}'.code: 
						break;
						
					case _:
						id += value.charAt( j );
						j++;
						
				}
				
				// Remove any surrounding whitespace.
				id = id.trim();
				var exists = false;
				
				// See if the value exists and add it if it does.
				if (exists = variables.exists( id )) {
					result += variables.get( id );
					
				} else if (exists = environment.exists( id )) {
					result += environment.get( id );
					
				}
				
				if (exists) i = j;
				
			case '$'.code if (ereg != null && value.fastCodeAt(i + 1) >= '0'.code && value.fastCodeAt(i+1) <= '9'.code):
				var id = '';
				var no = -1;
				var j = i + 1;
				
				while (j < value.length) switch (value.fastCodeAt(j)) {
					case x if (x >= '0'.code && x <= '9'.code):
						id += String.fromCharCode(x);
						j++;
						
					case _:
						break;
						
				}
				
				// Remove any surrounding whitespace.
				id = id.trim();
				no = Std.parseInt( id );
				
				// See if the value exists and add it if it does.
				if (no != null) {
					result += ereg.matched( no );
					i = j;
					
				}
				
			case _:
				result += value.charAt(i);
				
		}
		
		return result;
	}
	
	private function actions(value:String):Array<{action:Action, command:String}> {
		var i = -1;
		var code = -1;
		var action = Action.NONE;
		var command = '';
		var results = [];
		
		while (i++ < value.length) switch (code = value.fastCodeAt(i)) {
			case '|'.code:
				results.push( { action:action, command:command.trim() } );
				action = Action.PIPELINE;
				command = '';
				
			case '<'.code:
				results.push( { action:action, command:command.trim() } );
				action = Action.REDIRECT_INPUT;
				command = '';
				
			case '>'.code:
				results.push( { action:action, command:command.trim() } );
				action = Action.REDIRECT_OUTPUT;
				command = '';
				
			case x if (x >= '0'.code && x <= '2'.code && value.fastCodeAt(i+1) == '>'.code):
				results.push( { action:action, command:command.trim() } );
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
		
		if (command != '') results.push( { action:action, command:command.trim() } );
		
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
		 * As I ignore the action value from now on.
		 */
		for (i in 0...results.length) {
			if (results[i] != null && results[i].action == Action.REDIRECT_INPUT) {
				results[i].action = Action.NONE;
				results.insert(i - 1, results[i]);
				results[i + 1] = null;
				
			}
			
			
		}
		
		return results.filter( function(f) return f != null );
	}
	
	private function run(actions:Array<{action:Action,command:String}>):Void {
		var previous:Process = null;
		var collection:Array<Process> = [];
		
		var index:Int = 0;
		var current:Process = null;
		var parts:Array<String> = [];
		
		for (action in actions) {
			trace( action );
			switch (action.action) {
				case Action.NONE if (action.command.isAbsolute() && action.command.exists()):
					trace( 'creating file read : ${action.command}' );
					index = collection.push( current = cast {
						stdin:null,
						stdout:File.read( action.command ),
						stderr:null,
						close:function() untyped __this__.stdout.close(),
					} ) -1;
					
				case Action.PIPELINE | Action.REDIRECT_OUTPUT if (action.command.isAbsolute()):
					trace( 'creating file write : ${action.command}' );
					index = collection.push( current = cast {
						stdin:File.write( action.command ),
						stdout:null,
						stderr:null,
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
	
}