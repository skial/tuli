package uhx.tuli.plugins;

import uhx.sys.Tuli;

using Detox;

/**
 * ...
 * @author Skial Bainn
 */
class ImageGroup {

	public static function main() return ImageGroup;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		Tuli.onExtension('html', handler, After);
	}
	
	public function handler(file:TuliFile, content:String):String {
		var dom = content.parse();
		
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
		
		return dom.html();
	}
	
}