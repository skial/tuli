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
		
		var index = -1;
		var date:Date = null;
		var string = '';
		var file = '';
		var match = null;
		
		while (index < list.length-2) {
			string = list[index + 1];
			file = list[index + 2];
			var justDigits = false;
			
			for (i in 0...string.length) {
				if (string.charCodeAt(i) >= '0'.code && string.charCodeAt(i) <= '9'.code) {
					justDigits = true;
				} else {
					justDigits = false;
					break;
				}
			}
			
			if (justDigits && files.exists( file.fullPath().normalize() )) {
				match = files.position( file.fullPath().normalize() );
				files[match].created = files[match].modified = date = Date.fromTime( string.parseFloat() );
				index += 2;
				
			} else if (date != null && files.exists( string.fullPath().normalize() )) {
				match = files.position( string.fullPath().normalize() );
				files[match].created = files[match].modified = date;
				index++;
				
			} else {
				index++;
				
			}
			
		}
		
		return files;
	}
	
}