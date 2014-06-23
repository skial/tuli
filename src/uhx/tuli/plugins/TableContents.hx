package uhx.tuli.plugins;

import uhx.sys.Tuli;
import uhx.tuli.util.File;

using Detox;
using StringTools;

/**
 * ...
 * @author Skial Bainn
 */
class TableContents {

	public static function main() return TableContents;
	
	public static var processed:Array<String> = [];
	
	public function new(tuli:Tuli) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'html', handler, After );
	}
	
	public function handler(file:File) {
		var dom = file.content.parse();
		var h2s = dom.find( 'h2' );
		
		if (h2s.length > 0 && processed.indexOf( file.path ) == -1) {
			var side = dom.find( 'article aside' );
			var table = '';
			var title = '';
			var anchor = '';
			
			if (side.length > 0) {
				for (h2 in h2s) {
					title = h2.text();
					anchor = title.replace(' ', '-');
					table += '<li><a href="#$anchor">$title</a></li>\r\n';
				}
				
				table = '<nav><h1>Table of Contents</h1><ul>$table</ul></nav>';
				side.prepend( table.parse() );
				processed.push( file.path );
			}
			
			file.content = dom.html();
			
		}
		
	}
	
}