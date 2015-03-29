package uhx.sys;

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
	
	public var input:Input;
	public var output:Output;
	private var bytes:Bytes;
	
	public function new(bytes:Bytes, ?input:Input, ?output:Output) {
		this.bytes = bytes;
		this.input = input == null ? new BytesInput(this.bytes) : input;
		this.output = output == null ? new BytesOutput() : output;
	}
	
}

@:enum private abstract Action(Int) from Int to Int {
	public var PIPELINE = 0;
	public var REDIRECT_INPUT = 1;
	public var REDIRECT_OUTPUT = 2;
	public var APPEND = 3;
	public var REDIRECT_STDIN = 4;
	public var REDIRECT_STDOUT = 5;
	public var REDIRECT_STDERR = 6;
}

/**
 * ...
 * @author Skial Bainn
 */
class Tuli {
	
	public var config:DynamicAccess<Dynamic>;
	
	private var variables:StringMap<String>;
	private var environment:StringMap<String>;
	private var userEnvironment:StringMap<String>;
	
	private var eregMap:StringMap<EReg>;
	private var memoryMap:StringMap<BIO>;
	
	public var allFiles:Array<String>;
	
	public function new(cf:String) {
		if ( cf == null ) throw 'The configuration file can not be null.';
		
		eregMap = new StringMap();
		variables = new StringMap();
		memoryMap = new StringMap();
		environment = Sys.environment();
		userEnvironment = new StringMap();
		config = Json.parse( cf.getContent() );
		
		var pairs:Array<Dynamic> = [];
		
		for (key in config.keys()) switch(key) {
			case 'environment':
				pairs = config.get( key );
				
				for (pair in pairs) {
					var name = pair.fields()[0];
					var value = pair.field( name );
					
					if (value != null && !environment.exists( name )) {
						Sys.putEnv( name, value );
						
						environment.set( name, value );
						userEnvironment.set( name, value );
						
					}
					
				}
				
			case 'variables':
				pairs = config.get( key );
				
				for (pair in pairs) {
					var name = pair.fields()[0];
					var value = pair.field( name );
					
					if (value != null && !variables.exists( name )) variables.set( name, value );
					
				}
				
			case _:
				// Ignore for now, need to setup `environment` and `variables`.
				
		}
		
		for (key in config.keys()) switch(key) {
			case 'variables', 'environment':
				// Skip these.
				
			case _ if (key.indexOf("${") > -1):
				eregMap.set( key, new EReg( substitution( key ), '' ) );
				
			case _:
				eregMap.set( key, new EReg(key, '') );
				
		}
		
		allFiles = recurse( '${Sys.getCwd()}/${variables.exists("input") ? variables.get("input") : ""}/'.normalize() );
		
		for (id in eregMap.keys()) {
			var ereg = eregMap.get( id );
			var matches = allFiles.filter( function(path) return ereg.match( path ) );
			
			var content:DynamicAccess<Array<String>> = config.get( id );
			
			// Make sure `#` and `cmd` are at the front.
			var keys = ['#', 'cmd'].concat( [for (k in content.keys()) k].filter( function(k) return ['#', 'cmd'].indexOf( k ) == -1 ) );
			
			for (matched in matches) {
				var info = matched.stat();
				var input = matched.read();
				var bytes = new BIO( Bytes.alloc( info.size ), input );
				
				for (key in keys) switch (key) {
					case '#':
						for (value in content.get( key )) {
							memoryMap.set( '$id$key', bytes );
						}
						
					case 'cmd':
						for (value in content.get( key )) if (ereg.match( matched )) {
							trace( value, actions( substitution( value, ereg ) ) );
						}
						
					case _:
						
						
				}
				break;
				
			}
			
		}
		
	}
	
	// Replace `${name}` with a matching value from `variables` or `environment`.
	// Replace `$0` with whatever is returned by the `ereg` regular expression.
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
		var command = '';
		var results = [];
		
		while (i++ < value.length) switch (code = value.fastCodeAt(i)) {
			case '|'.code:
				results.push( { action:Action.PIPELINE, command:command.trim() } );
				command = '';
				
			case '<'.code:
				results.push( { action:Action.REDIRECT_INPUT, command:command.trim() } );
				command = '';
				
			case '>'.code:
				results.push( { action:Action.REDIRECT_OUTPUT, command:command.trim() } );
				command = '';
				
			case x if (x >= '0'.code && x <= '2'.code && value.fastCodeAt(i+1) == '>'.code):
				results.push( { action:switch(x) {
					case 0: Action.REDIRECT_STDIN;
					case 1: Action.REDIRECT_STDOUT;
					case 2: Action.REDIRECT_STDERR;
					case _: -1;
				}, command:command.trim() } );
				command = '';
				
			case _:
				if (code != null) command += String.fromCharCode( code );
				
		}
		
		if (command != '') results.push( { action: -1, command:command.trim() } );
		
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