package uhx.tuli.plugins;

import sys.FileSystem;
import uhx.sys.Tuli;
import sys.io.Process;
import haxe.ds.ArraySort;
import uhx.tuli.util.File;

using Std;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using uhx.tuli.util.File.Util;

/**
 * ...
 * @author Skial Bainn
 */
class GitDate {
	
	public static function main() return GitDate;
	private static var tuli:Tuli;

	public function new(t:Tuli) {
		tuli = t;
		
		tuli.onAllFiles( handler );
	}
	
	public function handler(files:Array<File>):Array<File> {
		var paths = files
			.map( function(s) return s.path )
			.filter( function(s) return s.trim() != '' )
			.map( function(s) return '"$s"' );
		
		var process = new Process('git', ['log', '--format=%at', '--name-only', '--diff-filter=A', '--'].concat( paths ));
		var output = process.stdout.readAll().toString();
		
		process.exitCode();
		process.close();
		
		var list = output
			.split('\n')
			.filter( function(s) return s.trim() != '' );
		
		files = setCreated( list, files );
		
		return files;
	}
	
	private function isDigits(value:String):Bool {
		var result = true;
		var code = -1;
		
		for (i in 0...value.length) {
			code = value.charCodeAt(i);
			
			if (code < '0'.code || code > '9'.code) {
				result = false;
				break;
			}
		}
		
		return result;
	}
	
	private function setCreated(list:Array<String>, files:Array<File>):Array<File> {
		var index = -1;
		var date:Date = null;
		var string = '';
		var file = '';
		var match = null;
		
		while (index < list.length-2) {
			string = list[index + 1];
			file = list[index + 2].fullPath().normalize();
			
			if (isDigits( file ) && files.exists( file )) {
				match = files.position( file );
				files[match].created = date = Date.fromTime( string.parseFloat() );
				index += 2;
				
			} else if (date != null && files.exists( string = string.fullPath().normalize() )) {
				match = files.position( string );
				files[match].created = date;
				index++;
				
			} else {
				index++;
				
			}
			
		}
		
		return files;
	}
	
}