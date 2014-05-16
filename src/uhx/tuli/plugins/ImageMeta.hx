package uhx.tuli.plugins;

import sys.io.File;
import uhx.sys.Tuli;
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

	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
	}
	
	public function handler(file:TuliFile, content:String) {
		var dom = content.parse();
		var images = dom.find('img');
		if (images.length > 0) for (image in images) {
			var magick = new Imagick( (Tuli.config.input + '/' + image.attr('src')).normalize() );
			var width = Math.round(magick.getWidth() / 100) * 100;
			var height = Math.round(magick.getHeight() / 100) * 100;
			var metaWidth = image.attr('data-width');
			var metaHeight = image.attr('data-height');
			var value = '';
			
			metaWidth = metaWidth == '' ? '' : metaWidth += ' ';
			value = magick.getWidth() > width ? 'gt$width' : 'lt$width';
			if (metaWidth.indexOf( value ) == -1) metaWidth += value;
			
			metaHeight = metaHeight == '' ? '' : metaHeight += ' ';
			value = magick.getHeight() > height ? 'gt$height' : 'lt$height';
			if (metaHeight.indexOf( value ) == -1) metaHeight += value;
			
			image.setAttr( 'data-width', metaWidth.rtrim() );
			image.setAttr( 'data-height', metaHeight.rtrim() );
		}
		
		return dom.html();
	}
	
}