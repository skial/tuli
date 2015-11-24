package uhx.sys;

import haxe.crypto.Md5;
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

using Lambda;
using Reflect;
using StringTools;
using sys.io.File;
using uhx.sys.Tuli;
using haxe.io.Path;
using sys.FileSystem;

private class Base {
	
	public var variables:StringMap<String>;
	public var environment:StringMap<String>;
	
	public inline function new() {
		variables = new StringMap();
		environment = new StringMap();
	}
	
}

private class Job extends Base {
	
	public var expression:EReg;
	public var memory:Array<String> = [];
	public var commands:Array<String> = [];
	
	public var execute:EReg->Void = null;
	
	public inline function new(expression:EReg) {
		this.expression = expression;
		super();
		
	}
	
}

private class Section extends Base {
	
	public var name:String;
	public var jobs:Array<Job> = [];
	public var prerequisites:Array<String> = [];
	
	public inline function new(name:String) {
		this.name = name;
		super();
	}
	
}

private class TopLevel extends Section {
	
	public var defines:Array<String> = [];
	
	public inline function new(name:String) {
		super( name );
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

private typedef FakeProcess = {
	var stdin:Output;
	var stdout:Input;
	var stderr:Input;
	function close():Void;
}

private abstract Proc(FakeProcess) from FakeProcess to FakeProcess {
	
	public var stdin(get, never):Output;
	public var stdout(get, never):Input;
	public var stderr(get, never):Input;
	
	public inline function close() this.close();
	public inline function new(v:FakeProcess) this = v;
	private inline function get_stdin():Output return this.stdin;
	private inline function get_stdout():Input return this.stdout;
	private inline function get_stderr():Input return this.stderr;
	
	@:noCompletion @:from public static inline function fromOutput(io:Output):Proc {
		return new Proc( { stdin:io, stdout:null, stderr:null, close:function() io.close() } );
	}
	
	@:noCompletion @:from public static inline function fromInput(io:Input):Proc {
		return new Proc( { stdin:null, stdout:io, stderr:null, close:function() io.close() } );
	}
	
	@:noCompletion @:from public static inline function fromProcess(process:Process):Proc {
		return new Proc( cast process );
	}
	
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
	
	private static var toplevel:TopLevel;
	private static var allFiles:Array<String> = [];
	private static var sections:Array<Section> = [];
	private static var sessionEnvironment:StringMap<String> = new StringMap();
	
	public var config:DynamicAccess<Dynamic>;
	
	public function new(cf:String) {
		if ( cf == null ) throw 'The configuration file can not be null.';
		
		trace( 'parse json' );
		config = Json.parse( cf.getContent() );
		
		trace( 'new toplevel' );
		toplevel = new TopLevel( 'toplevel' + Md5.encode(cf) );
		/*trace( 'copy environment' );
		sessionEnvironment = toplevel.environment.copy();*/
		trace( 'add env' );
		toplevel.environment = toplevel.environment.concat( Sys.environment() );
		
		trace( 'set env' );
		// Only set user defined enviroment `key:value` passed in by command argument or json.
		for (key in sessionEnvironment.keys()) Sys.putEnv(key, sessionEnvironment.get( key ));
		
		trace( 'push toplevel' );
		sections.push( toplevel );
	}
	
	public function setup():Void {
		trace( 'setup toplevel' );
		setupToplevel( config );
		trace( 'setup unknowns' );
		setupUnknowns( config );
		trace( 'setup lineage' );
		setupLineages();
		trace( 'sort sections' );
		sortSections();
		
		allFiles = recurse( '${Sys.getCwd()}/${toplevel.variables.exists("input") ? toplevel.variables.get("input") : ""}/'.normalize() );
	}
	
	public function runJobs():Void {
		trace( 'run jobs' );
		for (section in sections) {
			trace( section.name );
			for (job in section.jobs) {
				for (file in allFiles) if (job.expression.match( file )) {
					job.execute( job.expression );
					
				}
				
			}
			
		}
		
	}
	
	private function setupLineages():Void {
		for (section in sections) section.prerequisites = lineage( section );
	}
	
	private function sortSections():Void {
		ArraySort.sort(sections, function(a, b) {
			if (a.name == 'clean') return 1;
			if (b.name == 'clean') return -1;
			if (a.prerequisites.indexOf( b.name ) > -1) return 1;
			if (b.prerequisites.indexOf( a.name ) > -1) return -1;
			return 0;
		});
	}
	
	private function setupToplevel(config:DynamicAccess<Dynamic>):Void {
		for (key in config.keys()) switch(key) {
			case 'define':
				toplevel.defines = toplevel.defines.concat( (config.get( key ):Array<String>) );
				
			case 'environment', 'env':
				toplevel.environment = toplevel.environment.concat( populateMap( config.get( key ) ) );
				
			case 'variables', 'var':
				toplevel.variables = toplevel.variables.concat( populateMap( config.get( key ) ) );
				
			case 'if':
				for (config in conditional( config.get( key ) )) {
					setupToplevel( config );
					
				}
				
			case _:
				// Ignore for now, need to setup `environment` and `variables`.
				
		}
	}
	
	private function populateMap(config:DynamicAccess<Dynamic>):StringMap<String> {
		var result = new StringMap<String>();
		var value = null;
		
		for (key in config.keys()) switch (key) {
			case 'if':
				for (config in conditional( config.get( key ) )) {
					result = result.concat( populateMap( config ) );
					
				}
				
			case _:
				value = config.get( key );
				if (value != null && !result.exists( key )) {
					trace( key, value );
					result.set( key, '$value' );
					
				}
				
		}
		
		return result;
	}
	
	private function setupUnknowns(config:DynamicAccess<Dynamic>):Void {
		for (key in config.keys()) switch(key) {
			case 'variables', 'environment', 'var', 'env', 'define':
				// Skip these.
				
			case 'if':
				for (config in conditional( config.get( key ) )) {
					setupUnknowns( config );	//	TODO maybe lift key:values into global scope? as this is run before global unknowns.
					
				}
				
			case _:
				var value:DynamicAccess<Dynamic> = config.get( key );
				
				if (value.exists('cmd')) {
					var job = new Job( new EReg( key.indexOf("${") > -1 ? substitution( key )(null) : key, '') );
					populateData(job, value);
					populateJob(job, value);
					prepareJob(job);
					
					toplevel.jobs.push( job );
					
				} else {
					var section = new Section( key );
					populateData( section, value );
					populateSection( section, value );
					sections.push( section );
					
				}
				
		}
	}
	
	private function populateData(base:Base, data:DynamicAccess<Dynamic>):Void {
		for (key in data.keys()) switch (key) {
			case 'variables', 'var':
				base.variables = base.variables.concat( populateMap( data.get( key ) ) );
				
			case 'environment', 'env':
				base.environment = base.environment.concat( populateMap( data.get( key ) ) );
				
			case 'if':
				for (data in conditional( data.get( key ) )) {
					populateData(base, data);
					
				}
				
			case _:
		}
	}
	
	private function populateSection(section:Section, data:DynamicAccess<Dynamic>):Void {
		for (key in data.keys()) switch (key) {
			case 'variables', 'environment', 'var', 'env':
				// Skip
				
			case 'if':
				for (data in conditional( data.get( key ) )) {
					populateSection(section, data);
					
				}
				
			case 'prerequisite', 'pre':
				section.prerequisites = section.prerequisites.concat( (data.get( key ):Array<String>) );
				
			case _ if ((data.get( key ):DynamicAccess<Dynamic>).exists( 'cmd' )):
				var job = new Job( new EReg( key.indexOf("${") > -1 ? substitution( key )(null) : key, '') );
				populateData(job, data.get( key ));
				populateJob(job, data.get( key ));
				prepareJob(job);
				section.jobs.push( job );
				
			case _:
				
		}
	}
	
	private function populateJob(job:Job, data:DynamicAccess<Dynamic>):Void {
		for (key in data.keys()) switch (key) {
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
		var parts:Array<EReg->String> = [];
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
				if (exists = toplevel.variables.exists( id )) {
					parts.push( function(s, _) { return s + toplevel.variables.get(id); }.bind(new String(result), _) );
					result = '';
					
				} else if (exists = toplevel.environment.exists( id )) {
					parts.push( function(s, _) { return s + toplevel.environment.get(id); }.bind(new String(result), _) );
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
				if (exists = toplevel.variables.exists( id )) {
					parts.push( function(s, _) { return s + toplevel.variables.get(id); }.bind(new String(result), _) );
					result = '';
					
				} else if (exists = toplevel.environment.exists( id )) {
					parts.push( function(s, _) { return s + toplevel.environment.get(id); }.bind(new String(result), _) );
					result = '';
					
				}
				
				if (exists) i = j;
				
			case '$'.code if (ereg != null && isNumerical(value.fastCodeAt(i + 1))):
				var id = '';
				var no:Null<Int> = -1;
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
					
					parts.push( function(s:String, i:Int, e:EReg) { return s + e.matched( no ); } .bind(new String(result), no, _) );
					result = '';
					
				}
				
			case _:
				result += value.charAt(i);
				
		}
		
		if (result != null && result != '') parts.push( function(_) return new String(result) );
		
		return function(e:EReg) {
			var buffer = new StringBuf();
			for (part in parts) buffer.add( part(e) );
			return buffer.toString();
		}
	}
	
	private function actions(value:String):EReg->Array<CachedCommand> {
		var i = -1;
		var code:Null<Int> = -1;
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
		var index:Int = 0;
		var parts:Array<String> = [];
		var collection:Array<Proc> = [];
		
		for (action in actions) {
			switch (action.action) {
				case Action.NONE if (action.command.isAbsolute() && action.command.exists()):
					trace( 'creating file read : ${action.command}' );
					index = collection.push( File.read( action.command ) ) -1;
					trace( collection[index] );
					
				case Action.PIPELINE | Action.REDIRECT_OUTPUT if (action.command.isAbsolute()):
					trace( 'creating file write : ${action.command}' );
					index = collection.push( File.write( action.command ) ) -1;
					trace( collection[index] );
					
				case _:
					trace( 'creating process : ${action.command}' );
					parts = action.command.split(' ');
					index = collection.push( new Process(parts.shift(), parts) ) - 1;
					trace( collection[index] );
					
			}
			
		}
		
		var length = collection.length - 1;
		trace( actions );
		trace( collection );
		for (i in 0...collection.length) if (i + 1 <= length) {
			var current = collection[i];
			var next = collection[i + 1];
			trace(current);
			trace(next);
			next.stdin.writeInput( current.stdout );
			next.stdin.close();
		}
		
		for (item in collection) try item.close() catch (e:Dynamic) { };
		
	}
	
	//// STATICS METHODS
	
	/**
	 * Returns the index if `name` matches a section, if not `-1`.
	 */
	private static function findSection(name:String):Int {
		var result = -1;
		
		for (i in 0...sections.length) if (sections[i].name == name) {
			result = i;
			break;
			
		}
		
		return result;
	}
	
	/**
	 * Returns an array of section names that come before this `section`.
	 */
	private static function lineage(section:Section):Array<String> {
		var results = section.prerequisites;
		
		for (pre in section.prerequisites) {
			var index = findSection( pre );
			
			if (index > -1) for (pre in sections[index].prerequisites) if (pre != section.name) {
				index = findSection( pre );
				
				if (results.indexOf( pre ) == -1 && index > -1) {
					results.push( pre );
					results = results.concat( lineage(sections[index]).filter( function(s) return results.indexOf(s) == -1 ) );
					
				}
				
			}
		}
		
		return results;
	}
	
	/**
	 * Converts `value` into a boolean based on its
	 * existence in `Tuli.toplevel.defines`.
	 */
	private static function toBoolean(value:String):Bool {
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
		
		return bool ? toplevel.defines.indexOf( name ) > -1 : toplevel.defines.indexOf( name ) == -1;
	}
	
	/**
	 * Find the next `&&`, `||`, `==` or '!=' binop and return its `index-1`.
	 */
	private static function nextBinop(value:String):Int {
		var index = -1;
		var result = value.length;
		
		while (index++ < value.length) switch([value.fastCodeAt(index), value.fastCodeAt(index + 1)]) {
			case ['|'.code, '|'.code], ['&'.code, '&'.code], ['='.code, '='.code], ['!'.code, '='.code]:
				result = index - 1;
				break;
				
			case _:
				
		}
		
		return result;
	}
	
	/**
	 * Return an array containing objects whos `key` evaluates to `true`.
	 */
	private static function conditional(object:DynamicAccess<Dynamic>):Array<Dynamic> {
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
	private static function recurse(path:String):Array<String> {
		var results = [];
		path = path.normalize();
		
		if (path.isDirectory()) for (directory in path.readDirectory()) {
			var current = '$path/$directory/'.normalize();
			current.isDirectory() ? results = results.concat( recurse( current ) ) : results.push( current );
			
		}
		
		return results;
	}
	
	/**
	 * Recursively create the directory in `path`.
	 */
	private static function createDirectory(path:String) {
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
	
	/**
	 * Returns a new `StringMap<String>` containing `key` and `value` from both `a` and `b`.
	 */
	private static function concat(a:StringMap<String>, b:StringMap<String>):StringMap<String> {
		var map = new StringMap<String>();
		
		for (x in [a, b]) for (key in x.keys()) map.set(key, x.get( key ));
		
		return map;
	}
	
	/**
	 * Returns a `Bool` if `value` is an ASCII number.
	 */
	private inline static function isNumerical(value:Int):Bool {
		return value >= '0'.code && value <= '9'.code;
	}
	
	/**
	 * Returns a `Bool` if `value1 is an ASCII text character.
	 */
	private inline static function isCharacter(value:Int):Bool {
		return value >= 'a'.code && value <= 'z'.code || value >= 'A'.code && value <= 'Z'.code;
	}
	
	private static function bypass(a:Bool):Bool return a;
	
	private static function and(a:Bool, b:Bool):Bool return a && b;
	
	private static function or(a:Bool, b:Bool):Bool return a || b;
	
}