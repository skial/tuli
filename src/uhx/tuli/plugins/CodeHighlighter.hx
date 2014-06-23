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

	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		Tuli.onExtension('html', handler, After);
	}
	
	public function handler(file:File) {
		var dom = file.content.parse();
		var blocks = dom.find( 'code' );
		
		for (code in blocks) {
			
			var hasLang = code.hasClass( 'language' );
			var lang = null;
			
			if (hasLang) {
				lang = [for (k in Lang.uage.keys()) if (code.hasClass( k ) ) k][0];
			}
			
			if (hasLang && lang != null) {
				var parser = Lang.uage.get( lang );
				var tokens = parser.toTokens( ByteData.ofString( code.text() ), 'code-highlighter-$lang' );
				var html = [for (token in tokens) parser.printHTML( token )].join( '\n' );
				
				code.setText('');
				code.append(null, html.parse());
			}
		}
		
		file.content = dom.html();
	}
	
}