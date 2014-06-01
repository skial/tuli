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
class TitleLinks {

	public static function main() return TitleLinks;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
	}
	
	public function handler(file:TuliFile, content:String) {
		var dom = content.parse();
		
		for (header in dom.find('h2')) {
			var text = header.text();
			var link = text.replace(' ', '-').replace('.', '-');
			header = header.replaceWith(null, '<h2><a href="#$link" name="$link" type="text/html"><span></span></a>$text</h2>'.parse());
		}
		
		return dom.html();
	}
	
}