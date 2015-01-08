package uhx.tuli.plugins;

import sys.io.File;
import haxe.io.Eof;
import uhx.sys.Ioe;
import haxe.io.Input;
import byte.ByteData;

using Detox;
using StringTools;

/**
 * ...
 * @author Skial Bainn
 */
@:cmd
@:usage('highlight [options]')
class CodeHighlighter extends Ioe implements Klas {
	
	@alias('i')
	public var input:String;
	
	@alias('o')
	public var output:String;
	
	@alias('d')
	public var directory:String;
	
	@alias('a')
	public var auto:Bool = false;
	
	public static function main() {
		var high = new CodeHighlighter( Sys.args() );
		high.exit();
	}

	public function new(args:Array<String>) {
		process();
	}
	
	public function process() {
		if (input != null) stdin = File.read( input );
		if (output != null) stdout = File.read( output );
		
		var code = -1;
		var content = '';
		
		try while (code != eofChar) {
			code = stdin.readByte();
			if (byte != eofChar) content += String.fromCharCode( code );
			
		} catch (e:Eof) {
			
		} catch (e:Dynamic) {
			stderr.writeString( '$e' );
			
		}
		
		content = content.trim();
		
		var dom = content.parse();
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