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
class ImageLetterbox {
	
	public static function main() return ImageLetterbox;
	private var tuli:Tuli;
	private var config:Dynamic;

	public function new(t:Tuli, c:Dynamic) {
		tuli = t;
		config = c;
		tuli.onExtension( 'html', handler, After );
	}
	
	private static var counter:Int = 0;
	
	public function handler(file:File) {
		var dom = file.content.parse();
		
		for (img in dom.find( 'img[alt*="letterbox"]' )) {
			var caption = img.attr( 'title' );
			img = img.replaceWith(null, '<figure><input type="checkbox" id="pic$counter" /><label for="pic$counter"></label><div>${img.html()}</div><figcaption>$caption</figcaption></figure>'.parse());
			counter++;
		}
		
		file.content = dom.html();
	}
	
}