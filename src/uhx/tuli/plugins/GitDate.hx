package uhx.tuli.plugins;

import sys.io.Process;
import uhx.sys.Tuli;
import uhx.tuli.util.File;

using StringTools;

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
		
		var dates = output.split('\n');
		trace( dates );
		
		return files;
	}
	
}