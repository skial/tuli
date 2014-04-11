package uhx.macro;

import std.*;
import haxe.*;
import sys.FileStat;
import tjson.TJSON;
import uhx.macro.Tuli;

import byte.ByteData;
import haxe.Json;
import sys.io.Process;
import haxe.macro.Type;
import haxe.macro.Expr;
import uhx.lexer.MarkdownParser;
import uhx.macro.KlasImp;
import haxe.macro.Context;
import haxe.macro.Compiler;
//import uhx.macro.help.TemCommon;

import Detox;
//import uhx.tem.Parser;

using sys.io.File;
using sys.FileSystem;

using Lambda;
using Detox;
using StringTools;
using haxe.io.Path;

typedef TuliConfig = {
	var input:String;
	var output:String;
	var ignore:Array<String>;
	var extra:Dynamic;
	var files:Array<TuliFile>;
	var users:Array<TuliUser>;
	var spawn:Array<TuliSpawn>;
}

typedef TuliFile = {
	var name:String;
	var ext:String;
	var path:String;
	var size:Int;
	var created:String;
	var modified:String;
	var ignore:Bool;
	var extra:Dynamic;
	var spawned:Array<String>;
}

typedef TuliSpawn = {>TuliFile,
	var parent:String;
}

typedef TuliUser = {
	var name:String;
	var email:String;
	var avatar_url:String;
	var profiles:Array<TuliProfile>;
	var isAuthor:Bool;
	var isContributor:Bool;
}

typedef TuliProfile = {
	var service:String;
	var data:Dynamic;
}

enum TuliState {
	Before;
	After;
}

/**
 * ...
 * @author Skial Bainn
 */
class Tuli {
	
	public static var config:TuliConfig = null;
	public static var secrets:Dynamic = null;
	
	// Every single file.
	public static var files:Array<String>;
	public static var fileCache:Map<String, String>;
	
	private static var extPluginsBefore:Map<String, Array<TuliFile->String->String>> = null;
	private static var extPluginsAfter:Map<String, Array<TuliFile->String->String>> = null;
	
	// Register a callback that is interested in a certain extension.
	// This allows for multiply extensions to deal with the same file.
	// Call via your `hxml` file `--macro uhx.macro.Tuli.onExtension('html', pack.age.Class.callback)`
	public static function onExtension(extension:String, callback:TuliFile->String->String, ?when:TuliState):Void {
		initialize();
		var map = (when == null || when == Before) ? extPluginsBefore : extPluginsAfter;
		var cbs = map.exists( extension ) ? map.get( extension ) : [];
		cbs.push( callback );
		map.set( extension, cbs );
	}
	
	private static var dataPluginsBefore:Array<Dynamic->Dynamic> = null;
	private static var dataPluginsAfter:Array<Dynamic->Dynamic> = null;
	
	// Register a callback that adds data to the global `config.data` object.
	// This is currently not saved, so the data has to be recreated on each call.
	// Call via your `hxml` file `--macro uhx.macro.Tuli.onData(pack.age.Class.callback)`
	public static function onData(callback:Dynamic->Dynamic, ?when:TuliState):Void {
		initialize();
		(when == null || when == Before) ? dataPluginsBefore.push( callback ) : dataPluginsAfter.push( callback );
	}
	
	private static var finishCallbacksBefore:Array<Void->Void> = null;
	private static var finishCallbacksAfter:Array<Void->Void> = null;

	public static function onFinish(callback:Void->Void, ?when:TuliState):Void {
		initialize();
		(when == null || when == After) ? finishCallbacksAfter.push( callback ) : finishCallbacksBefore.push( callback );
	}
	
	private static var isSetup:Bool = false;
	
	public static function initialize():Void {
		if (isSetup == null || isSetup == false) {
			KlasImp.initalize();
			
			files = [];
			fileCache = new Map();
			dataPluginsBefore = new Array();
			dataPluginsAfter = new Array();
			extPluginsBefore = new Map();
			extPluginsAfter = new Map();
			finishCallbacksBefore = new Array();
			finishCallbacksAfter = new Array();
			
			if ( 'config.json'.exists() ) {
				// Load `config.json` if it exists.
				config = Json.parse( File.getContent( 'config.json' ) );
				
				// Clear the list of generated files.
				config.spawn = [];
				
				if (config.files == null) config.files = [];
				
				// If `output` is null set it to output provided to the compiler.
				if (config.output != null) {
					config.output = config.output.fullPath().normalize();
				} else {
					config.output = Compiler.getOutput().normalize();
				}
				
				// If `input` was set, start processing files only when 
				// objects are starting to be typed.
				if (config.input != null) {
					KlasImp.ONCE.push( function() input( config.input = config.input.fullPath().normalize() ) );
				}
				
				if ('secrets.json'.exists()) {
					secrets = Json.parse( File.getContent( 'secrets.json' ) );
				} else {
					secrets = { };
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
			
			/*if (!location.isDirectory()) {
				files.push( item );
			} else {*/
			if (location.isDirectory()) {
				allItems = allItems.concat( location.readDirectory().map( function(d) return '$item/$d'.normalize() ) );
			}
			
			index++;
		}
		
		var newItems = allItems.filter( function(a) return !config.files.exists( function(b) return a == b.path ) );
		var missingItems = config.files.filter( function(a) return !allItems.exists( function(b) return a.path == b ) );
		
		for (missing in missingItems) {
			config.files.remove( missing );
		}
		
		for (file in config.files) {
			var stats = '$path/${file.path}'.stat();
			file.size = stats.size;
			file.modified = asISO8601(stats.mtime);
		}
		
		config.files = config.files.concat( [for (newItem in newItems) if (!'$path/$newItem'.isDirectory()) {
			var stats = '$path/$newItem'.stat();
			{
				name: newItem.withoutExtension().withoutDirectory(),
				ext: newItem.extension(),
				path: newItem,
				size: stats.size,
				created: asISO8601(stats.ctime),
				modified: asISO8601(stats.mtime),
				ignore: false, 
				spawned: [],
				extra: {},
			}
		}] );
		
		// Set any file matching `config.ignore` with its extension
		// to be ignored.
		for (file in config.files) if (config.ignore.indexOf( file.ext ) > -1) file.ignore = true;
		
		// Clear the files `spawned` array.
		for (file in config.files) file.spawned = [];
		
		// Build `config.data` from the data plugins.
		for (cb in dataPluginsBefore) {
			config.extra = cb(config.extra);
		}
		
		// Send files to content plugins for modification.
		for (extension in extPluginsBefore.keys()) {
			var cbs = extPluginsBefore.get( extension );
			var files = config.files.filter( function(s) return s.ext == extension );
			var contents = files.map( function(s) return if (s.ext == 'html') loadHTML('$path/${s.path}') else '$path/${s.path}'.getContent() );
			
			for (i in 0...files.length) for (cb in cbs) {
				contents[i] = cb(files[i], contents[i]);
			}
			
			for (i in 0...files.length) fileCache.set( files[i].path, contents[i] );
		}
		
		// Last chance to modify files before the
		// re-creation stage starts.
		for (cb in finishCallbacksBefore) cb();
		
		// Recreate everything in `config.output` directory.
		Context.onAfterGenerate( finish );
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
		
		// Build `config.data` from the data plugins.
		for (cb in dataPluginsAfter) {
			config.extra = cb(config.extra);
		}
		
		// Send files to content plugins for modification if not in `fileCache`.
		for (extension in extPluginsAfter.keys()) {
			var cbs = extPluginsAfter.get( extension );
			var files = config.files.filter( function(s) return s.ext == extension );
			var contents = files.map( function(s) return if (fileCache.exists(s.path)) fileCache.get(s.path) else '${config.input}/${s.path}'.getContent() );
			
			for (i in 0...files.length) for (cb in cbs) {
				contents[i] = cb(files[i], contents[i]);
			}
			
			for (i in 0...files.length) fileCache.set( files[i].path, contents[i] );
		}
		
		// Send cached files to content plugins for modification.
		for (extension in extPluginsAfter.keys()) {
			var cbs = extPluginsAfter.get( extension );
			//var files = [for (key in fileCache.keys()) key].filter( function(s) return files.indexOf(s) == -1 && s.extension() == extension );
			var files = [for (key in fileCache.keys()) key]
				.filter( function(s) return !config.files.exists( function(f) return f.path == s ) && s.extension() == extension )
				.map( function(s) return tempFile( s ) );
			
			var contents = files.map( function(s) return fileCache.get( s.path ) );
			
			for (i in 0...files.length) for (cb in cbs) {
				contents[i] = cb(files[i], contents[i]);
			}
			
			for (i in 0...files.length) fileCache.set( files[i].path, contents[i] );
		}
		
		// Ignore extensions which have been added by plugins.
		if (config.ignore != null && config.ignore.length > 0) {
			files = files.filter( function(f) return config.ignore.indexOf( f.extension() ) == -1 );
		}
		
		// Last chance to modify `Tuli.fileCache` or `Tuli.file`.
		for (cb in finishCallbacksAfter) cb();
		
		for (file in config.files) if(!file.ignore) {
			var input = (config.input + '/${file.path}').normalize();
			var output = (config.output + '/${file.path}').normalize();
			
			createDirectory( output );
			
			if (!fileCache.exists( file.path )) {
				File.copy( input, output );
			} else {
				if (file.ext == 'html') {
					saveHTML( output, fileCache.get( file.path ) );
				} else {
					File.saveContent( output, fileCache.get( file.path ) );
				}
				fileCache.remove( file.path );
			}
		}
		
		for (file in fileCache.keys()) {
			var f = config.files.filter( function(f) return f.path == file )[0];
			
			if (f == null) f = tempFile( file );
			
			if (!f.ignore && config.ignore.indexOf(f.ext) == -1) {
				var output = '${config.output}/${f.path}'.normalize();
				
				createDirectory( output );
				
				if (f.ext == 'html') {
					saveHTML( output, fileCache.get( f.path ) );
				} else {
					File.saveContent( output, fileCache.get( f.path ) );
				}
				fileCache.remove( file );
			}
		}
		
		// Save the modified config file.
		File.saveContent( 'config.json', TJSON.encode(config, 'fancy') );
		
	}
	
	private static function loadHTML(path:String):String {
		var process = new Process('tidy', [
			// Indent elements.
			'-i', 
			// Be quiet.
			'-q', 
			// Convert to xml.
			'-asxml', 
			// Force the doctype to valid html5
			'--doctype', 'html5',
			// Don't add the tidy html5 meta
			'--tidy-mark', 'n',
			// Keep empty elements and paragraphs.
			'--drop-empty-elements', 'n',
			'--drop-empty-paras', 'n', 
			'--drop-proprietary-attributes', 'n',
			'--escape-cdata', 'y',
			'--indent-cdata', 'n',
			'--wrap', '0',
			//'--new-pre-tags', '',
			// Add missing block elements.
			'--new-blocklevel-tags', 
			'article aside audio canvas datalist figcaption figure footer ' +
			'header hgroup output section video details element main menu ' +
			'template shadow nav ruby source',
			// Add missing inline elements.
			'--new-inline-tags', 'bdi data mark menuitem meter progress rp' +
			'rt summary time',
			// Add missing void elements.
			'--new-empty-tags', 'content keygen track wbr',
			// Don't wrap partials in `<html>`, or `<body>` and don't add `<head>`.
			'--show-body-only', 'auto', 
			// Make the converted html easier to read.
			'--vertical-space', 'y', path]);
			
		var content = process.stdout.readAll().toString();
		
		process.close();
		
		return content;
	}
	
	private static function saveHTML(path:String, content:String) {
		var process = new Process('tidy', [
			// Encode as utf8.
			'-utf8',
			// Be quite.
			//'-q',
			// Output as html, as the input is xml.
			'-ashtml',
			// Set the output location.
			'-o', '"$path"',
			// Force the doctype to html5.
			'--doctype', 'html5',
			// Don't add the tidy html5 meta
			'--tidy-mark', 'n',
			//'-f', 'errors_$key.txt',
			// Keep empty elements and paragraphs.
			'--drop-empty-elements', 'n',
			'--drop-empty-paras', 'n', 
			'--drop-proprietary-attributes', 'n',
			'--escape-cdata', 'y',
			'--indent-cdata', 'n',
			'--wrap', '0',
			// Add missing block elements.
			'--new-blocklevel-tags', 
			'article aside audio canvas datalist figcaption figure footer ' +
			'header hgroup output section video details element main menu ' +
			'template shadow nav ruby source',
			// Add missing inline elements.
			'--new-inline-tags', 'bdi data mark menuitem meter progress rp' +
			'rt summary time',
			// Add missing void elements.
			'--new-empty-tags', 'content keygen track wbr',
			// Don't wrap partials in `<html>`, or `<body>` and don't add `<head>`.
			'--show-body-only', 'auto', 
			// Make the converted html easier to read.
			'--vertical-space', 'y',
		]);
		
		process.stdin.writeString( content );
		process.close();
	}
	
	// This just spits out the correct format. Its not utc aware.
	public static function asISO8601(d:Date):String {
		var YYYY = d.getFullYear();
		var MM = d.getMonth() + 1;
		var DD = d.getDay() + 1;
		var hh = d.getHours() + 1;
		var mm = d.getMinutes();
		var ss = d.getSeconds() + 1;
		return '$YYYY-${MM<10?"0"+MM:""+MM}-${DD<10?"0"+DD:""+DD}T${hh<10?"0"+hh:""+hh}:${mm<10?"0"+mm:""+mm}:${ss<10?"0"+ss:""+ss}Z';
	}
	
	private static function tempFile(path:String):TuliFile {
		return {
			size: 0,
			extra: {},
			path: path,
			spawned: [],
			ignore: false,
			ext: path.extension(),
			created: asISO8601(Date.now()),
			modified: asISO8601(Date.now()),
			name: path.withoutDirectory().withoutExtension(),
		}
	}
	
}