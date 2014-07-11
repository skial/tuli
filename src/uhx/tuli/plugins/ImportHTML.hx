package uhx.tuli.plugins;

import uhx.sys.Tuli;
import uhx.tuli.util.File;
import uhx.select.Json in JsonSelect;

using Lambda;
using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
class ImportHTML {
	
	public static function main() return ImportHTML;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
		//Tuli.onFinish( finish, After );
	}
	
	public function handler(file:File) {
		var dom = file.content.parse();
		var head = dom.find('head');
		var isPartial = head.length == 0;
		var hasInjectPoint = dom.find('content[select]').length > 0;
		
		if (isPartial) {
			file.ignore = true;
			
		} else if (hasInjectPoint) {
			var output = file.path.replace( Tuli.config.input, Tuli.config.output ).normalize();
			//var skip = FileSystem.exists( output ) && FileSystem.stat( output ).mtime.getTime() < file.modified.getTime();
			
			//if (!skip) {
				var contents = dom.find('content[select]');
				
				for (c in contents) {
					var selector = c.attr('select');
					
					if (selector.startsWith('#')) {
						selector = selector.substring(1);
						var key = '${selector}.html';
						var partialFile = Tuli.files.filter( function(f) return f.name == selector && f.ext == 'html' )[0];
						
						if (partialFile != null) {
							var partial = partialFile.content.parse();
							
							c = c.replaceWith(null, partial.first().children());
							c.removeFromDOM();
						}
						
					} else {
						
					}
					
				}
				dom.find('link[rel="import"]').remove();
				
				// Find any remaining `<content />` and try filling them
				// with anything that matches their own selector.
				contents = dom.find('content[select]:not(content[targets])');
				
				for (c in contents) {
					var selector = c.attr('select');
					var items = dom.find( selector );
					var attributes = [for (a in c.attributes) a];
					var isText = attributes.exists( function(attr) return attr.name == 'data-text' || attr.name == 'text' );
					var isJson = attributes.exists( function(attr) return attr.name == 'data-json' || attr.name == 'json' );
					var doRemove = attributes.exists( function(attr) return (attr.name == 'data-match' || attr.name == 'match') && attr.value == 'remove' );
					
					if (isText) {
						c = c.replaceWith(items.text().parse());
					} else if (isJson) {
						var data = JsonSelect.find(Tuli.config, selector);
						trace( data.length );
					} else {
						c = c.replaceWith(items);
					}
					
					if (doRemove) {
						items.remove();
					}
					
				}
				
				// Remove all '<content />` from the DOM.
				dom.find('content[select]').remove();
				file.content = dom.html();
			//}
		}
	}
	
}