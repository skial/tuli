package uhx.macro;

import std.*;
import haxe.*;

import byte.ByteData;
import haxe.Json;
import sys.io.Process;
import haxe.macro.Type;
import haxe.macro.Expr;
import uhx.lexer.MarkdownParser;
import uhx.macro.KlasImp;
import haxe.macro.Context;
import haxe.macro.Compiler;
import uhx.macro.help.TemCommon;
import unifill.Utf32;

import Detox;
import uhx.tem.Parser;

using sys.io.File;
using sys.FileSystem;

using Lambda;
using Detox;
using StringTools;
using haxe.io.Path;

typedef TuliConfig = {
	var input:String;
	var output:String;
}

typedef Plugin = {
	function process(path:String, files:Array<String>):Array<String>;
	function generate(path:String):Void;
}

/**
 * ...
 * @author Skial Bainn
 */
class Tuli {
	
	private static var config:TuliConfig = null;
	
	// Every single file.
	public static var files:Array<String>;
	
	// key => plugin name, value => callback, which gets passed list of files.
	// Register a plugin with `--macro uhx.macro.Tuli.registerPlugin('pluginName', pack.age.MyClass.callback)`
	public static var plugins:Map<String, Plugin>;
	
	// callback will be passed the path to the base directory and an array of found files.
	public static function registerPlugin(name:String, onProcess:String->Array<String>->Array<String>, onGenerate:String->Void):Void {
		trace( name );
		initialize();
		plugins.set(name, { process: onProcess, generate: onGenerate } );
	}
	
	private static var isSetup:Bool = false;
	
	public static function initialize():Void {
		if (isSetup == null || isSetup == false) {
			KlasImp.initalize();
			
			files = [];
			plugins = new Map();
			
			if ( 'config.json'.exists() ) {
				// Load `config.json` if it exists.
				config = Json.parse( File.getContent( 'config.json' ) );
				
				// If `output` is null set it to output provided to the compiler.
				if (config.output != null) {
					config.output = config.output.fullPath();
				} else {
					config.output = Compiler.getOutput();
				}
				
				// If `input` was set, start processing files only when 
				// objects are starting to be typed.
				if (config.input != null) {
					KlasImp.ONCE.push( function() input( config.input = config.input.fullPath() ) );
				}
			}
			
			isSetup = true;
		}
	}
	
	public static function input(path:String) {
		path = '$path/'.normalize();
		
		// Find all files in `path`.
		var allItems = path.readDirectory();
		var index = 0;
		
		// Find all files by recursing through each directory.
		while (allItems.length > index) {
			var item = allItems[index].normalize();
			var location = '$path/$item'.normalize();
			
			if (!location.isDirectory()) {
				files.push( item );
			} else {
				allItems = allItems.concat( location.readDirectory().map( function(d) return '$item/$d'.normalize() ) );
			}
			
			index++;
		}
		
		// Send the list of files to each plugin.
		for (plugin in plugins) files = plugin.process( path, files );
		
		// Recreate everything in `config.output` directory.
		Context.onAfterGenerate( finish );
		
		return macro null;
	}
	
	public static function finish() {
		// Recursively create the directory in `config.output`.
		var createDirectory = function(path:String) {
			if (!path.directory().addTrailingSlash().exists()) {
				
				var parts = path.directory().split('/');
				var missing = [parts.pop()];
				while (!Path.join( parts ).exists()) missing.push( parts.pop() );
				
				missing.reverse();
				
				var directory = Path.join( parts );
				for (part in missing) {
					directory = '$directory/$part'.normalize();
					directory.createDirectory();
				}
				
			}
		}
		
		for (file in files) {
			var input = (config.input + '/$file').normalize();
			var output = (config.output + '/$file').normalize();
			
			createDirectory( output );
			
			File.copy( input, output );
		}
		
		for (plugin in plugins) plugin.generate( config.output );
	}
	
}