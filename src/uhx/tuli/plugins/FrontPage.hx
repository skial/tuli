package uhx.tuli.plugins;

import haxe.ds.ArraySort;
import uhx.sys.Tuli;

using Detox;
using StringTools;
using haxe.io.Path;

/**
 * ...
 * @author Skial Bainn
 */
class FrontPage {

	public static function main() return FrontPage;
	
	public var articles:Array<String> = [];
	public var fragments:Map<String,Date> = new Map();
	
	public function new(tuli:Tuli) {
		untyped Tuli = tuli;
		
		Tuli.onExtension( 'md', handler, After );
		Tuli.onFinish( finish, After );
	}
	
	public function handler(file:TuliFile, content:String):String {
		if (articles.indexOf( file.path ) == -1 && file.spawned.length > 0) {
			articles.push( file.path );
			var spawned = file.spawned.filter( function (s) return s.extension().indexOf( 'html' ) > -1 );
			var contents = spawned.map( function(s) return Tuli.fileCache.get( s ) );
			
			for (i in 0...spawned.length) {
				var spawn = spawned[i];
				var content = contents[i];
				var dom = content.parse();
				var title = dom.find( 'article h1:first-of-type' ).text();
				var date = dom.find( 'time' ).attr( 'datetime' );
				var path = spawn.directory().addTrailingSlash();
				var social = dom.find( '[alt*="social"]' ).first().html();
				//var description = dom.find( 'p' )
				var entry = '
				<li itemscope="" itemtype="http://schema.org/Article">
					<h1 itemprop="headline">
						<a itemprop="url" href="/$path" title="$title">$title</a>
					</h1>
					<time pubdate="" datetime="$date" dateCreated="$date"></time>
					$social
				</li>
				';
				trace( file.created() );
				trace( file.modified() );
				
				var m = file.modified();
				fragments.set( entry, m );
				
			}
			
		}
		
		return content;
	}
	
	public function finish():Void {
		if (Tuli.fileCache.exists( 'index.html' )) {
			var pairs = [for (k in fragments.keys()) { e:k, d:fragments.get(k) } ];
			
			ArraySort.sort( pairs, function(a, b) return a.d.getTime() > b.d.getTime() ? -1 : a.d.getTime() < b.d.getTime() ? 1 : 0 );
			
			var list = [for (p in pairs) p.e].join('\n').parse();
			var index = Tuli.fileCache.get( 'index.html' ).parse();
			var main = index.find( 'main' );
			
			main = main.prepend( list );
			
			Tuli.fileCache.set( 'index.html', index.html() );
			
		}
	}
	
}