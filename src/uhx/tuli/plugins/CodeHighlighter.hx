package uhx.tuli.plugins;

import uhx.sys.Tuli;

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
	
	public function handler(file:TuliFile, content:String):String {
		var dom = content.parse();
		var blocks = dom.find( 'code' );
		
		for (code in blocks) {
			var lang = code.attr( 'language' );
			if (lang != '' && Lang.uage.exists( lang )) {
				code = code.replaceWith( null, Lang.uage.get( lang ).printHTML( code.text() ).parse() );
			}
		}
		
		return dom.html();
	}
	
}