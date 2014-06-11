package uhx.tuli.plugins;

import sys.io.File;
import uhx.sys.Tuli;
import byte.ByteData;
import uhx.lexer.CssLexer;
import uhx.lexer.CssParser;
import neko.imagemagick.Imagick;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
class ImageResize {

	public static function main() return ImageResize;

	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'css', handler, Before );
	}
	
	public function handler(file:TuliFile, content:String):String {
		var parser = new CssParser();
		var tokens = parser.toTokens( ByteData.ofString( content ), 'ImageResize-css' );
		var mediaQueries = tokens.filter( function(t) {
			return t.token.match(Keyword(AtRule(_, _, _)));
		} );
		
		for (mq in mediaQueries) {
			switch( mq.token ) {
				case Keyword(AtRule(n, q, t)):
					trace(n, q);
					
				case _:
					
			}
		}
		
		return [for (token in tokens) parser.printString( token )].join('\r\n');
	}
	
}