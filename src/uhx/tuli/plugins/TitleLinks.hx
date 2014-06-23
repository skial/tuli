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
class TitleLinks {

	public static function main() return TitleLinks;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
	}
	
	public function handler(file:File) {
		var dom = file.content.parse();
		
		for (header in dom.find('article section > h2')) {
			var text = header.text();
			var link = text.replace(' ', '-').replace('.', '-');
			header = header.replaceWith(null, '<h2><a href="#$link" id="$link" type="text/html"><span></span></a>$text</h2>'.parse());
		}
		
		file.content = dom.html();
	}
	
}