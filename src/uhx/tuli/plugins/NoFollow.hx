package uhx.tuli.plugins;

import sys.io.File;
import uhx.sys.Tuli;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
class NoFollow {
	
	public static function main() return NoFollow;

	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
	}

	public function handler(file:TuliFile, content:String) {
		var dom = content.parse();
		
		for (a in dom.find('a')) {
			if (a.attr('rel').indexOf('nofollow') == -1) {
				a.set('rel', (a.attr('rel') + ' nofollow').ltrim());
			}
		}
		
		return dom.html();
	}
	
}