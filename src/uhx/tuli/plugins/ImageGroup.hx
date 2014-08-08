package uhx.tuli.plugins;

import uhx.sys.Tuli;
import uhx.tuli.util.File;

using Detox;

/**
 * ...
 * @author Skial Bainn
 */
class ImageGroup {

	public static function main() return ImageGroup;
	private var tuli:Tuli;
	private var config:Dynamic;
	
	public function new(t:Tuli, c:Dynamic) {
		tuli = t;
		config = c;
		tuli.onExtension('html', handler, After);
	}
	
	public function handler(file:File) {
		var dom = file.content.parse();
		
		for (p in dom.find( 'p' )) {
			var images = [for (img in p.find( 'img' )) img];
			
			if (images.length > 1) for (img in images) {
				var len = images.length;
				var grid = 'grid-1-$len';
				var alt = img.attr( 'alt' );
				
				if (alt.indexOf( grid ) == -1) alt += ' $grid';
				
				img.setAttr( 'alt', alt );
				
				
			}
		}
		
		file.content = dom.html();
	}
	
}