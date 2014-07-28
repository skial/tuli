package uhx.sys;

import Detox;
import dtx.Tools;
import haxe.Json;
import haxe.Timer;
import uhx.Tappi;
import tjson.TJSON;
import haxe.io.Eof;
import sys.FileStat;
import hxparse.Lexer;
import byte.ByteData;
import sys.io.Process;
import neko.vm.Loader;
import uhx.tuli.util.File;
import uhx.tuli.util.Spawn;
import uhx.lexer.MarkdownParser;
import uhx.tuli.util.AlphabeticalSort;

using Lambda;
using Detox;
using Reflect;
using StringTools;
using haxe.io.Path;
using uhx.sys.Tuli;
using sys.FileSystem;

typedef TuliConfig = {
	var input:String;
	var output:String;
	var ignore:Array<String>;
	var extra:Dynamic;
	var files:Array<File>;
	var users:Array<TuliUser>;
	var spawn:Array<Spawn>;
	var plugins:Array<String>;
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

typedef TuliPlugin = {
	function new(tuli:Tuli):Void;
	function build():Void;
	function update():Void;
	function clean():Void;
}

/**
 * ...
 * @author Skial Bainn
 */
class Tuli {
	
	public static var configFile:File;
	public static var config:TuliConfig;
	public static var secretFile:File;
	public static var secrets:Dynamic;
	
	// Every single file.
	//public static var files:Array<File> = [];
	//public static var fileCache:Map<String, String> = new Map();
	
	private static var extPluginsBefore:Map<String, Array<File->Void>> = new Map();
	private static var extPluginsAfter:Map<String, Array<File->Void>> = new Map();
	
	// Register a callback that is interested in a certain extension.
	// This allows for multiply extensions to deal with the same file.
	public static function onExtension(extension:String, callback:File->Void, ?when:TuliState):Void {
		if (when == null) when = Before;
		switch (when) {
			case Before:
				if (!extPluginsBefore.exists( extension )) {
					extPluginsBefore.set( extension, [] );
				}
				
				extPluginsBefore.get( extension ).push( callback );
				
			case After:
				if (!extPluginsAfter.exists( extension )) {
					extPluginsAfter.set( extension, [] );
				}
				
				extPluginsAfter.get( extension ).push( callback );
				
		}
	}
	
	private static var dataPluginsBefore:Array<Dynamic->Dynamic> = [];
	private static var dataPluginsAfter:Array<Dynamic->Dynamic> = [];
	
	// Register a callback that adds data to the global `config.data` object.
	// This is currently not saved, so the data has to be recreated on each call.
	public static function onData(callback:Dynamic->Dynamic, ?when:TuliState):Void {
		if (when == null) when = Before;
		switch (when) {
			case Before: dataPluginsBefore.push( callback );
			case After: dataPluginsAfter.push( callback );
		}
	}
	
	private static var finishCallbacksBefore:Array<Void->Void> = [];
	private static var finishCallbacksAfter:Array<Void->Void> = [];

	public static function onFinish(callback:Void->Void, ?when:TuliState):Void {
		if (when == null) when = After;
		switch (when) {
			case After: finishCallbacksAfter.push( callback );
			case Before: finishCallbacksBefore.push( callback );
		}
	}
	
	private static var classes:Map<String, Class<TuliPlugin>> = new Map();
	private static var instances:Map<String, TuliPlugin> = new Map();
	
	private static var isSetup:Bool;
	public static var time:Float = .0;
	
	public static function initialize():Void {
		time = Timer.stamp();
		
		if (isSetup == null || isSetup == false) {
			
			if ( config != null ) {
				
				// Clear the list of generated files.
				config.spawn = [];
				
				if (config.files == null) config.files = [];
				
				// If `output` is null set it to output provided to the compiler.
				if (config.output != null) {
					config.output = config.output.fullPath().normalize();
					
				}
				
				if (config.input != null) {
					config.input = config.input.fullPath().normalize();
					
				}
				
				if ('${Sys.getCwd()}/secrets.json'.normalize().exists()) {
					secretFile = new File( '${Sys.getCwd()}/secrets.json'.normalize() );
					secrets = Json.parse( secretFile.content );
					
				} else {
					secrets = { };
					
				}
				
				if (config.plugins.length > 0) {
					var libs = [];
					
					for (plugin in config.plugins) for (name in plugin.fields()) {
						// field equals the haxelib name
						libs.push( name );
						libs = libs.concat( (plugin.field( name ):Array<String>) );
					}
					
					var tappi = new Tappi(libs, true);
					
					tappi.find();
					tappi.load();
					
					for (id in tappi.libraries) if (tappi.classes.exists( id )) {
						var cls:Class<TuliPlugin> = cast tappi.classes.get( id );
						instances.set( id, Type.createInstance( cls, [Tuli] ));
					}
					
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
			
			if (location.isDirectory()) {
				allItems = allItems.concat( location.readDirectory().map( function(d) return '$item/$d'.normalize() ) );
			}
			
			index++;
		}
		
		allItems = new AlphabeticalSort().alphaSort( allItems );
		
		var newItems = allItems.filter( function(a) return !config.files.exists( function(b) return a == b.path ) );
		var missingItems = config.files.filter( function(a) return !allItems.exists( function(b) return a.path == b ) );
		
		for (missing in missingItems) {
			config.files.remove( missing );
		}
		
		config.files = config.files.concat( 
			[for (newItem in newItems) if (!'$path/$newItem'.isDirectory()) {
				new File( '$path/$newItem'.normalize() );
			}]
		);
		
		// Set any file matching `config.ignore` with its extension
		// to be ignored.
		for (file in config.files) if (config.ignore.indexOf( file.ext ) > -1) file.ignore = true;
		
		// Clear the files `spawned` array.
		for (file in config.files) file.spawned = [];
		
		// Build `config.data` from the data plugins.
		for (cb in dataPluginsBefore) config.extra = cb(config.extra);
		
		// Send files to content plugins for modification.
		for (extension in extPluginsBefore.keys()) {
			var cbs = extPluginsBefore.get( extension );
			var files = config.files.filter( function(s) return s.ext == extension );
			//var contents = files.map( function(s) return if (s.ext == 'html') loadHTML('$path/${s.path}') else '$path/${s.path}'.getContent() );
			
			for (file in files) for (cb in cbs) cb(file);
		}
		
		// Last chance to modify files before the
		// re-creation stage starts.
		for (cb in finishCallbacksBefore) cb();
		
		// Recreate everything in `config.output` directory.
		finish();
		trace( Timer.stamp() - time );
	}
	
	public static function finish() {
		// Build `config.data` from the data plugins.
		for (cb in dataPluginsAfter) config.extra = cb(config.extra);
		
		// Send files to content plugins for modification if not in `fileCache`.
		for (extension in extPluginsAfter.keys()) {
			var cbs = extPluginsAfter.get( extension );
			var files = config.files.filter( function(s) return s.ext == extension );
			
			for (file in files) for (cb in cbs) cb( file );
		}
		
		for (extension in extPluginsAfter.keys()) {
			var cbs = extPluginsAfter.get( extension );
			var files = config.spawn.filter( function(s) return s.ext == extension/* && fileCache.exists( s.path ) */);
			
			for (file in files) for (cb in cbs) cb( file );
		}
		
		// Ignore extensions which have been added by plugins.
		if (config.ignore != null && config.ignore.length > 0) {
			config.files = config.files.filter( function(f) return config.ignore.indexOf( f.ext ) == -1 );
		}
		
		// Last chance to modify anything.
		for (cb in finishCallbacksAfter) cb();
		
		// Lets save everything.
		for (file in config.files) save( file );
		for (file in config.spawn) save( file );
		
		// Remove all `file.stats` fields from the config file.
		var toRemove = [];
		for (file in config.files) {
			if (file.extra.github == null || file.extra.github.contributors == null) {
				toRemove.push( file );
			}
		}
		for (tr in toRemove) config.files.remove( tr );
		
		var toRemove = [];
		for (file in config.spawn) {
			if (file.extra.github == null || file.extra.github.contributors == null) {
				toRemove.push( file );
			}
		}
		for (tr in toRemove) config.spawn.remove( tr );
		
		// Save the modified config file.
		configFile.content = TJSON.encode(config, 'fancy');
		configFile.save();
		
	}
	
	// Recursively create the directory in `config.output`.
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
	
	private static function save(file:File) {
		var input = file.path.normalize();
		var output = file.path.replace(config.input, config.output).normalize().replace(' ', '-');
		
		if (!file.ignore) {
			createDirectory( output );
			file.save( output );
			
		}
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
	
	private static inline function tempFile(path:String):File {
		return new File( (Tuli.config.input + '/$path').normalize() );
	}
	
	public static function isNewer(a:File, b:File):Bool {
		
		switch ([a.path.exists(), b.path.exists()]) {
			case [true, false]: return true;
			case [false, _]: return false;
			case [true, true]:
				if (a.modified.getTime() > b.modified.getTime()) {
					return true;
				}
				
				if (a.created.getTime() > b.created.getTime()) {
					return true;
				}
				
				return false;
		}
		
	}
	
}

private typedef Commit = {
	var sha:String;
	var commit: {
		author: { name:String, email:String, date:String },
		committer: { name:String, email:String, date:String },
		message:String,
		tree: { sha:String, url:String },
		url:String,
		comment_count:Int
	};
	var url:String;
	var html_url:String;
	var comments_url:String;
	var author: {
		login:String, id:String, avatar_url:String, gravatar_id:String,
		url:String, html_url:String, followers_url:String, following_url:String,
		gists_url:String, starred_url:String, subscriptions_url:String,
		organizations_url:String, repos_url:String, events_url:String,
		received_events_url:String, type:String, site_admin:Bool
	};
	var committer: {
		login:String, id:String, avatar_url:String, gravatar_id:String,
		url:String, html_url:String, followers_url:String, following_url:String,
		gists_url:String, starred_url:String, subscriptions_url:String,
		organizations_url:String, repos_url:String, events_url:String,
		received_events_url:String, type:String, site_admin:Bool
	};
	var parents: {
		sha:String, url:String, html_url:String
	};
}

class GithubInformation /*implements Klas*/ {
	
	//#if macro
	public static function initialize() {
		//Tuli.onData(dataHandler, Before);
	}
	
	public static function dataHandler(data:Dynamic):Dynamic {
		var process:Process;
		var directory = Tuli.config.input.addTrailingSlash().normalize().replace(Sys.getCwd().normalize(), '');
		
		for (file in Tuli.config.files) {
			if (file.extra.github == null) {
				file.extra.github = { };
			}
			
			var url = 'https://api.github.com/repos/skial/haxe.io/commits?path=' + '/$directory${file.path}'.normalize();
			
			// If OAuth token and secret have been placed in
			// `secrets.json` then pass them along as this
			// increases the rate limit from 60 reqs per hour
			// to 5000.
			if (Tuli.secrets.github != null) {
				url += '&client_id=' + Tuli.secrets.github.id + '&client_secret=' + Tuli.secrets.github.secret;
			}
			
			// I'm only interested in the latest commits.
			if (file.extra.github.modified != null) {
				url += '&since=' + file.extra.github.modified;
			}
			
			// We use `curl` as https connections cant be requested
			// during macro mode.
			process = new Process('curl', [
				// On windows at least, curl fails when checking the ssl cert.
				// This forces it to be ignored.
				'-k',
				// Github needs a `User-Agent:` header to allow access to 
				// the api.
				'-A', 'skial/haxe.io tuli static site generator', 
				url
			]);
			
			var commits:Array<Commit> = Json.parse( process.stdout.readAll().toString() );
			if (commits.length > 0) {
				var first = commits[commits.length-1];
				
				// The first commit should be set as the author of the file.
				if (file.extra.github.modified == null) {
					file.extra.author = first.commit.author.name;
				}
				
				// Every other commit author to be listed as a contributor.
				file.extra.contributors = commits
					.map( function(s) return s.commit.author.name )
					.filter( function(s) return s != file.extra.author );
				
				// Set the github modified field to the last commit date.
				file.extra.github.modified = commits[0].commit.author.date;
				
				var userMap = new Map<String, Commit>();
				for (entry in commits) if (!userMap.exists(entry.commit.author.name)) {
					userMap.set(entry.commit.author.name, entry);
				}
				
				var fieldMap = [
					'login' => 'name',
					'url' => 'api_url',
					'html_url' => 'html_url',
				];
				
				for (contributor in (file.extra.contributors:Array<String>).concat([file.extra.author])) {
					var entry = userMap.get(contributor);
					var user = Tuli.config.users.filter( function(s) return s.name == contributor )[0];
					
					if (user == null) {
						user =  {
							name: contributor, 
							email: entry.commit.author.email, 
							avatar_url: 'https://secure.gravatar.com/avatar/' + entry.author.gravatar_id + '.png',
							profiles: [],
							isAuthor: false,
							isContributor: false,
						};
						Tuli.config.users.push(user);
					}
					
					if (!user.isAuthor) user.isAuthor = file.extra.author == contributor;
					if (!user.isContributor) user.isContributor = (file.extra.contributors:Array<String>).indexOf(user.name) > -1;
					if (user.avatar_url == null || user.avatar_url == '') {
						user.avatar_url = 'https://secure.gravatar.com/avatar/' + entry.author.gravatar_id + '.png';
					}
					
					var profiles = user.profiles.filter( function(s) return s.service == 'github' && user.name == contributor );
					
					if (profiles.length == 0) {
						user.profiles.push( { service: 'github', data: { name: contributor } } );
						profiles = user.profiles.filter( function(s) return s.service == 'github' );
					}
					
					for (profile in profiles) {
						var author = entry.author;
						
						for (key in fieldMap.keys()) {
							profile.data.setField( fieldMap.get(key), author.field(key) );
						}
					}
				}
			}
		}
		return data;
	}
	//#end
	
}
