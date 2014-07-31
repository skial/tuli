package uhx.tuli.plugins;

import uhx.sys.Tuli;
import byte.ByteData;
import uhx.tuli.util.File;

using Detox;

/**
 * ...
 * @author Skial Bainn
 */
class CodeHighlighter {
	
	public static function main() return CodeHighlighter;
	private static var tuli:Tuli;

	public function new(t:Tuli) {
		tuli = t;
		tuli.onExtension('html', handler, After);
	}
	
	public function handler(file:File) {
		var dom = file.content.parse();
		var blocks = dom.find( 'code' );
		
		for (code in blocks) {
			
			var hasLang = false;
			var lang = null;
			
			for (attribute in code.attributes) {
				if (attribute.name == 'language') {
					lang = attribute.value;
					hasLang = Lang.uage.exists( lang );
				}
			}
			
			if (hasLang && lang != null) {
				var parser = Lang.uage.get( lang );
				var tokens = parser.toTokens( ByteData.ofString( code.text() ), 'code-highlighter-$lang' );
				var html = [for (token in tokens) parser.printHTML( token )].join( '\n' );
				
				code.setText('');
				code.append(null, html.parse());
				
				var link = dom.find('link[href*="/css/haxe.flat16.css"]');
				if (link.length == 0) {
					dom.find('head').append(null, '<link rel="stylesheet" type="text/css" href="/css/$lang.flat16.css" />'.parse());
				}
			}
		}
		
		file.content = dom.html();
	}
	
}