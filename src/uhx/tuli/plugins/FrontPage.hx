package uhx.tuli.plugins;

import byte.ByteData;
import uhx.lexer.CssParser;
import uhx.sys.Tuli;
import haxe.ds.ArraySort;
import uhx.tuli.util.File;

using Detox;
using StringTools;
using haxe.io.Path;
using uhx.tuli.util.File.Util;

private class Item {
	
	public var url:String;
	public var title:String;
	public var created:Date;
	public var modified:Date;
	public var social:String;
	
	public function new(url:String, title:String, created:Date, modified:Date, social:String) {
		this.url = url;
		this.title = title;
		this.created = created;
		this.modified = modified;
		this.social = social;
	}
	
	public function toString():String {
		return '
		<li itemscope="" itemtype="http://schema.org/Article" id="${url.replace('/','_')}">
			<h1 itemprop="headline">
				<a itemprop="url" href="/$url" title="$title">$title</a>
			</h1>
			<time pubdate="${created.toString()}" datetime="${modified.toString()}" dateCreated="${created.toString()}"></time>
		</li>
		';
	}
	
}

/**
 * ...
 * @author Skial Bainn
 */
class FrontPage {

	public static function main() return FrontPage;
	private static var tuli:Tuli;
	
	public var css:File;
	public var fragments:Array<Item> = [];
	public var articles:Array<String> = [];
	
	
	public function new(t:Tuli) {
		tuli = t;
		
		tuli.onExtension( 'md', mdHandler, After );
		tuli.onExtension( 'css', cssHandler, After );
		tuli.onFinish( finish, After );
	}
	
	public function mdHandler(file:File) {
		if (articles.indexOf( file.path ) == -1 && file.spawned.length > 0) {
			articles.push( file.path );
			var spawned = file.spawned.filter( function (s) return s.extension().indexOf( 'html' ) > -1 );
			var contents = spawned.map( function(s) return tuli.config.spawn.get( s ) );
			
			for (i in 0...spawned.length) if (spawned[i] != null && contents[i] != null) {
				var spawn = spawned[i];
				var content = contents[i].content;
				var dom = content.parse();
				var item = new Item(
					spawn.directory().addTrailingSlash(),
					dom.find( 'article h1:first-of-type' ).text(),
					file.created, file.modified, dom.find( '[alt*="social"]' ).first().attr('src')
				);
				
				fragments.push( item );
				
			}
			
		}
	}
	
	public function cssHandler(file:File) {
		if (file.name == 'frontpage') css = file;
	}
	
	public function finish():Void {
		if (tuli.config.files.exists( '${tuli.config.input}/index.html' )) {
			
			ArraySort.sort( fragments, function(a, b) {
				return a.modified.getTime() > b.modified.getTime() ? -1 : a.modified.getTime() < b.modified.getTime() ? 1 : 0;
			} );
			
			var file = tuli.config.files.get( '${tuli.config.input}/index.html' );
			var list = [];
			var html = '';
			var cssRules = [];
			var cssParser = new CssParser();
			
			for (item in fragments) {
				html = list.toString();
				list.push( html );
				cssRules.push( cssParser.toTokens( ByteData.ofString( '#${item.url.replace("/","_")} {url(${item.social});}' ), 'frontpage-css1' ) );
			}
			
			if (css != null) {
				var tokens = cssParser.toTokens( ByteData.ofString( css.content), 'frontpage-css2' );
				for (rule in cssRules) tokens = tokens.concat( rule );
				css.content = [for (token in tokens) cssParser.printString( token )].join('\r\n');
			}
			
			var items = list.join('\n').parse();
			var index = file.content.parse();
			var main = index.find( 'main' );
			
			main = main.prepend( items );
			
			file.content = index.html();
			
		}
	}
	
}