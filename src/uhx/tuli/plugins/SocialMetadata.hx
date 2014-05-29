package uhx.tuli.plugins;

import haxe.imagemagick.Imagick;
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
class SocialMetadata {

	private static var files:Array<String> = [];
	
	public static function main() return SocialMetadata;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
		Tuli.onFinish( finish, After );
	}
	
	public function handler(file:TuliFile, content:String):String {
		var dom = content.parse();
		var head = dom.find('head');
		var isPartial = head.length == 0;
		
		if (!isPartial) {
			files.push( file.path );
		}
		
		return content;
	}
	
	public function finish() {
		for (file in files) {
			
			var dom = Tuli.fileCache.get( file ).parse();
			
			if (file == 'index.html') {
				dom.find('meta[property="og:type"]').setAttr('content', 'website');
			}
			
			var titles = [];
			for (id in ['property', 'name']) {
				for (meta in dom.find('meta[$id*="title"]')) {
					if (meta.attr('content') == '') titles.push( meta );
				}
			}
			
			var descriptions = [];
			for (id in ['property', 'name']) {
				for (meta in dom.find('meta[$id*="description"]')) {
					if (meta.attr('content') == '') descriptions.push( meta );
				}
			}
			
			for (title in titles) {
				title.setAttr('content', dom.find('title').text());
			}
			
			if (descriptions.length > 0) {
				var paragraphs = dom.find('p');
				var desc = ~/\s+/g.replace(paragraphs.text(), ' ').substring(0, 200);
				desc = desc.substring(0, desc.lastIndexOf(' '));
				for (description in descriptions) {
					description.setAttr('content', '$desc...');
				}
			}
			
			var img = 'img/skial.jpg';
			var alt = dom.find('img[alt*="social"]');
			var cardType = 'summary';
			
			var images = [];
			for (id in ['property', 'name']) {
				for (meta in dom.find('meta[$id*="image"]')) {
					if (meta.attr('content') == '') images.push( meta );
				}
			}
			
			if (alt.length > 0) {
				img = alt.first().attr('src');
				var data = new Imagick('${Tuli.config.input}/$img'.normalize());
				if (data.width >= 280 && data.height >= 150) {
					dom.find('meta[name="twitter:image"]').setAttr('name', 'twitter:image:src');
					cardType = 'summary_large_image';
				}
			}
			
			dom.find('meta[name="twitter:card"]').setAttr('content', cardType);
			
			for (image in images) image.setAttr('content', 'http://haxe.io/$img'.normalize());
			
			var url = dom.find('meta[property="og:url"]');
			
			if (url.length > 0) {
				var path = 'http://haxe.io/$file'.normalize();
				if (path.endsWith('index.html')) path = path.directory().addTrailingSlash();
				url.setAttr('content', path);
			}
			
			Tuli.fileCache.set( file, dom.html() );
		}
	}
	
}