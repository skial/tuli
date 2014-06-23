package uhx.tuli.plugins;

import uhx.sys.Tuli;
import haxe.ds.ArraySort;
import uhx.tuli.util.File;

using Detox;
using StringTools;
using haxe.io.Path;
using uhx.tuli.util.File.Util;

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
	
	public function handler(file:File) {
		if (articles.indexOf( file.path ) == -1 && file.spawned.length > 0) {
			articles.push( file.path );
			var spawned = file.spawned.filter( function (s) return s.extension().indexOf( 'html' ) > -1 );
			var contents = spawned.map( function(s) return Tuli.files.get( s ) );
			
			for (i in 0...spawned.length) {
				var spawn = spawned[i];
				var content = contents[i].content;
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
				
				var m = file.modified;
				fragments.set( entry, m );
				
			}
			
		}
	}
	
	public function finish():Void {
		if (!Tuli.files.exists( '${Tuli.config.input}/index.html' )) {
			var pairs = [for (k in fragments.keys()) { e:k, d:fragments.get(k) } ];
			
			ArraySort.sort( pairs, function(a, b) return a.d.getTime() > b.d.getTime() ? -1 : a.d.getTime() < b.d.getTime() ? 1 : 0 );
			
			var file = Tuli.files.get( '${Tuli.config.input}/index.html' );
			var list = [for (p in pairs) p.e].join('\n').parse();
			var index = file.content.parse();
			var main = index.find( 'main' );
			
			main = main.prepend( list );
			
			file.content = index.html();
			
		}
	}
	
}