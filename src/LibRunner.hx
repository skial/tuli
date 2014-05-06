package ;

import sys.io.File;
import haxe.io.Path;
import sys.FileSystem;
import haxe.Unserializer;
import uhx.sys.Tuli;

using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */

class LibRunner {
	
	static function main() {
		trace('main');
		var args = Sys.args();
		var len = args.length;
		
		var cwd = args.pop().normalize();
		var path = if (len == 3) args.pop() else '';
		var cmd = args.pop();
		
		switch (cmd) {
			case 'build':
				Sys.setCwd( cwd );
				Tuli.initialize();
				
			case _:
				
		}
	}
	
}