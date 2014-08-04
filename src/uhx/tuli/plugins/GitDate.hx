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
		
		// Get a list of dates & files for when they where first committed.
		var created = gitLog('A', paths);
		// Get a list of dates & files for when they where last modified.
		var modified = gitLog('M', paths);
		
		files = setCreated( created, files );
		files = setModified( modified, files );
		
		return files;
	}
	
	private function gitLog(type:String, paths:Array<String>):Array<String> {
		var process = new Process('git', ['log', '--format=%at', '--name-only', '--diff-filter=$type', '--'].concat( paths ));
		var output = process.stdout.readAll().toString();
		
		process.exitCode();
		process.close();
		
		/**
		 * The output is similar to the following:
		 * 
		 * 0123456789\n
		 * path/to/file.txt\n
		 * path/to/another/file.txt\n
		 * \n
		 * 0123456789\n
		 * path/to/a/different/file.txt\n
		 */
		return output.split('\n').filter( function(s) return s.trim() != '' );
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
	
	private function setDate(list:Array<String>, files:Array<File>, access:File->Date->Void):Array<File> {
		var path = '';
		var index = -1;
		var number = '';
		var date:Date = null;
		
		while (index < list.length-2) {
			number = list[index + 1];
			path = list[index + 2].fullPath().normalize();
			
			if (isDigits( number ) && files.exists( path )) {
				access(files.get( path ), date = Date.fromTime( number.parseFloat() ));
				index += 2;
				
			} else if (date != null && files.exists( number = number.fullPath().normalize() )) {
				access(files.get( number ), date);
				index++;
				
			} else {
				index++;
				
			}
			
		}
		
		return files;
	}
	
	private inline function setCreated(list:Array<String>, files:Array<File>):Array<File> {
		return setDate(list, files, function(f, d) f.created = d);
	}
	
	private inline function setModified(list:Array<String>, files:Array<File>):Array<File> {
		return setDate(list, files, function(f, d) f.modified = d);
	}
	
}