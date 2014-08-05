package uhx.tuli.util;

import geo.TzDate;
import sys.io.Process;

using StringTools;
using sys.io.File;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
class File {
	
	public var ext:String;
	public var name:String;
	public var path:String;
	public var data:Dynamic = { };
	public var ignore:Bool = false;
	public var fetched(get, null):Bool;
	public var spawned:Array<String> = [];
	@:isVar public var created(get, set):TzDate;
	@:isVar public var modified(get, set):TzDate;
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
	
	private function get_created():TzDate {
		if (created == null) {
			if (path.exists()) {
				created = new TzDate( path.stat().ctime );
				
			} else {
				created = TzDate.now();
				
			}
		}
		
		return created;
	}
	
	private function set_created(d:TzDate):TzDate {
		created = d;
		return d;
	}
	
	private function get_modified():TzDate {
		if (modified == null) {
			if (path.exists()) {
				modified = new TzDate( path.stat().mtime );
				
			} else {
				modified = TzDate.now();
				
			}
		}
		
		return modified;
	}
	
	private function set_modified(d:TzDate):TzDate {
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