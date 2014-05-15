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
class ImageLetterbox {
	
	public static function main() return ImageLetterbox;

	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
	}
	
	private static var counter:Int = 0;
	
	public function handler(file:TuliFile, content:String) {
		var dom = content.parse();
		
		for (img in dom.find('p > img:not([alt*="skip-lb"])')) {
			//var src = Tuli.config.output + '/' + img.attr('src');
			//var height = new haxe.imagemagick.Imagick(src.normalize()).height;
			var caption = img.attr('title');
			img = img.replaceWith(null, '<figure><input type="checkbox" id="pic$counter" /><label for="pic$counter"></label><div>${img.html()}</div><figcaption>$caption</figcaption></figure>'.parse());
			counter++;
		}
		
		return dom.html();
	}
	
}