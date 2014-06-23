package uhx.tuli.plugins;

import uhx.sys.Tuli;
import uhx.tuli.util.File;

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
	
	public function handler(file:File) {
		var dom = file.content.parse();
		var skip:Array<String> = Tuli.config.extra.plugins.nofollow.skip;
		var links = dom.find('a');
		
		links = links.filter( function(n) {
			var r = false;
			for (s in skip) {
				var href = n.attr('href').normalize();
				if (href.startsWith('/') || href.indexOf(s) > -1) return false;
			}
			return true;
		} );
		
		for (a in links) {
			
			if (a.attr('rel').indexOf('nofollow') == -1) {
				a.setAttr('rel', (a.attr('rel') + ' nofollow').ltrim());
			}
		}
		
		file.content = dom.html();
	}
	
}