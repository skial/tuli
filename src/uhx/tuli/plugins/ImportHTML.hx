package uhx.tuli.plugins;

import sys.io.File;
import uhx.sys.Tuli;
import uhx.select.Json in JsonSelect;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
class ImportHTML {

	public static var partials:Array<TuliFile> = [];
	public static var templates:Array<TuliFile> = [];
	
	public static function main() return ImportHTML;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
		Tuli.onFinish( finish, After );
	}
	
	public function handler(file:TuliFile, content:String):String {
		var dom = content.parse();
		var head = dom.find('head');
		var isPartial = head.length == 0;
		var hasInjectPoint = dom.find('content[select]').length > 0;
		
		if (isPartial) {
			partials.push( file );
		} else if (hasInjectPoint) {
			templates.push( file );
		}
		
		return content;
	}
	
	public function finish() {
		// Loop through and replace any `<content select="*" />` with
		// a matching `<link rel="import" />`.
		for (template in templates) {
			var output = '${Tuli.config.output}/${template.path}'.normalize();
			//var skip = FileSystem.exists( output ) && template.stats != null && FileSystem.stat( output ).mtime.getTime() < template.stats.mtime.getTime();
			//var skip = template.isNewer();
			var skip = FileSystem.exists( output ) && template.stats != null && FileSystem.stat( output ).mtime.getTime() < template.stats.mtime.getTime();
			
			if (!skip) {
				var dom = Tuli.fileCache.get( template.path ).parse();
				var contents = dom.find('content[select]');
				
				for (content in contents) {
					var selector = content.get('select');
					
					if (selector.startsWith('#')) {
						selector = selector.substring(1);
						var key = '$selector.html';
						var partial = Tuli.fileCache.get( key ).parse();
						
						content = content.replaceWith(null, partial.first().children());
						
					} else {
						// You have to be fecking difficult, we have to
						// loop through EACH partial and check the top
						// most element for a match. Thanks.
					}
					
				}
				dom.find('link[rel="import"]').remove();
				
				// Find any remaining `<content />` and try filling them
				// with anything that matches their own selector.
				contents = dom.find('content[select]:not(content[targets])');
				
				
				for (content in contents) {
					var selector = content.get('select');
					var items = dom.find( selector );
					/*trace( selector );
					trace( items );*/
					//if (items.length > 0) {
						for (att in content.attributes()) {
							switch (att.trim()) {
								case 'data-text', 'text':
									content = content.replaceWith(items.text().parse());
									
								case 'data-json', 'json':
									var data = JsonSelect.find(Tuli.config, selector);
									trace( data.length );
									
								case _:
									content = content.replaceWith(null, items);
									
							}
						}
						/*if ([for (att in content.attributes()) att].indexOf('text') == -1) {
							content = content.replaceWith(null, items);
						} else {
							content = content.replaceWith(items.text().parse());
						}*/
					//}
				}
				
				// Remove all '<content />` from the DOM.
				dom.find('content[select]').remove();
				Tuli.fileCache.set( template.path, dom.html() );
			}
			
		}
		
		for (partial in partials) {
			partial.ignore = true;
		}
	}
	
}