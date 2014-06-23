package uhx.tuli.util;

import haxe.io.Eof;
import byte.ByteData;
import hxparse.Lexer;

/**
 * ...
 * @author Skial Bainn
 */
class AlphabeticalSort {
	
	private var l:Lexer;
	
	/**
	 * This allows us to reuse the same instance
	 * over and over.
	 */
	private function resetLexer(value:String) {
		if (l == null) {
			l = new Lexer( ByteData.ofString( value ), 'AlphabeticalSort' );
		} else untyped {
			var i = ByteData.ofString( value );
			l.current = "";
			l.bytes = i;
			l.input = i;
			l.pos = 0;
		}
		return l;
	}
	
	public function new() { 
		
	}
	
	public function alphaSort(values:Array<String>) {
		var unordered:Array<Array<String>> = [];
		
		// Split each value into chuncks of numbers and strings.
		for (value in values) {
			var results = [];
			
			l = resetLexer(value);
			
			try while (true) {
				results.push( l.token( root ) );
			} catch (e:Eof) { } catch (e:Dynamic) {
				trace( e );
			}
			
			unordered.push( results );
		}
		
		var ordered = [];
		
		unordered.sort( function(a, b) {
			var x = 0;
			// Make sure we run against the largest array.
			var l = (a.length - b.length <= 0 ? a.length : b.length);
			var t = 0;
			
			while (x < l) {
				// Thanks http://www.davekoelle.com/files/alphanum.js
				if (a[x] != b[x]) {
					var c = Std.parseInt(a[x]);
					var d = Std.parseInt(b[x]);
					
					if ('$c' == a[x] && '$d' == b[x]) {
						return c - d;
					} else {
						return (a[x] > b[x]) ? 1 : -1;
					}
				}
				x++;
			}
			
			return a.length - b.length;
		} );
		
		// Put the parts back together.
		for (u in unordered) {
			ordered.push( u.join('') );
		}
		
		return ordered;
	}
	
	public static var root = Mo.rules( [
	'[0-9]+' => lexer.current,
	'[^0-9]+' => lexer.current,
	] );
	
}