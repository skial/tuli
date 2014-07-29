package uhx.tuli.plugins;

import uhx.sys.Tuli;
import uhx.tuli.util.File;
import neko.imagemagick.Imagick;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
class ImageMeta {

	public static function main() return ImageMeta;
	private static var tuli:Tuli;

	public function new(t:Tuli) {
		tuli = t;
		
		tuli.onExtension( 'html', handler, After );
	}
	
	public function handler(file:File) {
		var dom = file.content.parse();
		var images = dom.find( 'img' );
		
		if (images.length > 0) for (image in images) {
			var src = image.attr( 'src' );
			
			if (src.indexOf( 'http' ) == -1) {
				src = (tuli.config.input + '/$src').normalize();
			}
			
			try {
				var magick = new Imagick( src );
				var width = Math.round(magick.getWidth() / 100) * 100;
				var height = Math.round(magick.getHeight() / 100) * 100;
				var metaWidth = image.attr( 'data-width' );
				var metaHeight = image.attr( 'data-height' );
				var value = '';
				
				metaWidth = metaWidth == '' ? '' : metaWidth += ' ';
				value = magick.getWidth() > width ? 'gt$width' : 'lt$width';
				if (metaWidth.indexOf( value ) == -1) metaWidth += value;
				
				metaHeight = metaHeight == '' ? '' : metaHeight += ' ';
				value = magick.getHeight() > height ? 'gt$height' : 'lt$height';
				if (metaHeight.indexOf( value ) == -1) metaHeight += value;
				
				image.setAttr( 'data-width', metaWidth.rtrim() );
				image.setAttr( 'data-height', metaHeight.rtrim() );
				
			} catch (e:Dynamic) {
				// image probably couldnt be loaded...
				// trace( e );
			}
		}
	}
	
}