package uhx.tuli.util;

import sys.io.Process;

using StringTools;
using sys.io.File;
using sys.FileSystem;
using haxe.io.Path;

/**
 * ...
 * @author Skial Bainn
 */
class File {
	
	public static var useGit:Bool = false;
	
	//public var size:Int;
	public var ext:String;
	public var name:String;
	public var path:String;
	public var extra:Dynamic = { };
	public var ignore:Bool = false;
	public var fetched(get, null):Bool;
	public var spawned:Array<String> = [];
	@:isVar public var created(get, set):Date;
	@:isVar public var modified(get, set):Date;
	@:isVar public var content(get, set):String;

	public function new(path:String) {
		this.path = path;
		this.ext = path.extension();
		this.name = path.withoutDirectory().withoutExtension();
	}
	
	public function save(output:String = null):Void {
		if (output == null) output = path;
		
		if (content == null || !fetched) {
			output.saveContent( content );
			
		} else if (path != output) {
			path.copy( output );
			
		}
	}
	
	public inline function copy(output:String):Void {
		save( output );
	}
	
	private inline function get_fetched():Bool {
		return content == null;
	}
	
	private function get_created():Date {
		if (created == null) {
			if (useGit) {
				var process = new Process('git', ['log', '--pretty=format:%at', '--diff-filter=A', '--', path]);
				var output = process.stdout.readAll().toString();
				process.exitCode();
				process.close();
				
				if (output.trim() != '') {
					created = Date.fromTime( DateTools.seconds( Std.parseFloat( output ) ) );
				} else {
					created = path.stat().ctime;
				}
				
			} else if (path.exists()) {
				created = path.stat().ctime;
				
			} else {
				created = Date.now();
				
			}
		}
		
		return created;
	}
	
	private function set_created(d:Date):Date {
		created = d;
		return d;
	}
	
	private function get_modified():Date {
		if (modified == null) {
			if (useGit) {
				var process = new Process('git', ['log', '--pretty=format:%at', '--diff-filter=A', '--', path]);
				var output = process.stdout.readAll().toString();
				process.exitCode();
				process.close();
				
				if (output.trim() != '') {
					modified = Date.fromTime( DateTools.seconds( Std.parseFloat( output ) ) );
				} else {
					modified = path.stat().ctime;
				}
				
			} else if (path.exists()) {
				modified = path.stat().ctime;
				
			} else {
				modified = Date.now();
				
			}
		}
		
		return modified;
	}
	
	private function set_modified(d:Date):Date {
		modified = d;
		return d;
	}
	
	private function get_content():String {
		if (content == null) {
			content = path.getContent();
			fetched = true;
		}
		
		return content;
	}
	
	private function set_content(v:String):String {
		fetched = true;
		return content = v;
	}
	
}

class Util {
	
	public static function exists(files:Array<File>, path:String):Bool {
		var result = false;
		
		for (file in files) if (file.path == path) {
			result = true;
			break;
		}
		
		return result;
	}
	
	public static function get(files:Array<File>, path:String):File {
		var result = null;
		
		for (file in files) if (file.path == path) {
			result = file;
			break;
		}
		
		return result;
	}
	
}