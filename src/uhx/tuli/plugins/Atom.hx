package uhx.tuli.plugins;

import uhx.sys.Tuli;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using uhx.tuli.util.File;

/**
 * ...
 * @author Skial Bainn
 */
class Atom {

	private static var feed:File;
	private static var entry:File;
	private static var xmlCache:Map<String, DOMCollection> = new Map();
	
	public static function main() return Atom;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		
		if (feed == null) feed = new File( '${Tuli.config.input}/templates/_feed.atom'.normalize() );
		if (entry == null) entry = new File( '${Tuli.config.input}/templates/_entry.atom'.normalize() );
		
		Tuli.onExtension('md', handler, After);
	}
	
	public function handler(file:File) {
		for (file in Tuli.config.files.filter(function(f) {
			return ['_feed.atom', '_entry.atom'].indexOf(f.path) != -1;
		} )) file.ignore = true;
		
		var dir = file.path.directory();
		if (dir == '') dir = 'articles';
		var path = '$dir/atom.xml'.normalize();
		var html = '${file.path.withoutExtension()}/'.normalize();
		var id = 'http://haxe.io/$html';
		
		var xmlFeed = null;
		
		//if (Tuli.fileCache.exists( path )) {
		if (Tuli.config.files.exists( path )) {
			xmlFeed = Tuli.config.files.get( path );
			
		} else {
			xmlFeed = feed;
			
		}
		
		if (xmlFeed.content.indexOf(id) == -1 && Tuli.config.files.exists( '${html}index.html' )) {
			var dom = null;
			var domFeed = null;
			var domEntry = null;
			//trace( id );
			if (xmlCache.exists( html + 'index.html' )) {
				dom = xmlCache.get( html + 'index.html' );
				
			} else {
				dom = Tuli.config.files.get( html + 'index.html' ).content.parse();
				
			}
			
			if (xmlCache.exists( path )) {
				domFeed = xmlCache.get( path );
				
			} else {
				domFeed = xmlFeed.content.parse();
				
			}
			
			var title = dom.find('h1').first().text().trim();
			
			if (title != '') {
				domEntry = entry.content.parse();
				
				domEntry.find('id').setText( id );
				domEntry.find('title').setText( title );
				domEntry.find('summary').setText( dom.find('p').first().text() );
				domEntry.find('content').setAttr('src', id).setAttr('type','text/html');
				domEntry.find('published').setText( Tuli.asISO8601( file.created ) );
				
				domFeed.find('updated').setText( Tuli.asISO8601( file.modified ) );
				domEntry.find('updated').setText( Tuli.asISO8601( file.modified ) );
				
				domFeed.find('link').setAttr('href', 'http://haxe.io/$path');
				domFeed.first().next().append( null, domEntry );
				// The following line causes a memory leak.
				//domFeed.find('author').afterThisInsert( domEntry );
				
				xmlCache.set( path, domFeed );
				
				if (!xmlCache.exists( html + 'index.html' )) {
					xmlCache.set( html + 'index.html', dom );
				}
				
				var result = domFeed.html();
				
				while (result.indexOf('&amp;') > -1) {
					result = result.replace('&amp;', '&');
				}
				
				for (key in Markdown.characters.keys()) {
					result = result.replace( Markdown.characters.get( key ), key );
				}
				
				//Tuli.fileCache.set( path, result );
				xmlFeed.content = result;
				
			}
			
			dom = null;
			domFeed = null;
			domEntry = null;
		}
		
		dir = null;
		html = null;
		id = null;
		path = null;
		xmlFeed = null;
	}
	
}