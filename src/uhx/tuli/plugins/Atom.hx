package uhx.tuli.plugins;

import sys.io.File;
import uhx.sys.Tuli;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
class Atom {

	private static var feed:String;
	private static var entry:String;
	private static var xmlCache:Map<String, DOMCollection> = new Map();
	
	public static function main() return Atom;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		Tuli.onExtension('md', handler, After);
	}
	
	public function handler(file:TuliFile, content:String) {
		if (feed == null) feed = File.getContent('${Tuli.config.input}/_feed.atom'.normalize());
		if (entry == null) entry = File.getContent('${Tuli.config.input}/_entry.atom'.normalize());
		
		for (f in Tuli.config.files.filter(function(f) {
			return ['_feed.atom', '_entry.atom'].indexOf(f.path) != -1;
		} )) f.ignore = true;
		
		var dir = file.path.directory();
		if (dir == '') dir = 'articles';
		var path = '$dir/atom.xml'.normalize();
		var html = '${file.path.withoutExtension()}/'.normalize();
		var id = 'http://haxe.io/$html';
		
		var xmlFeed = null;
		
		if (Tuli.fileCache.exists( path )) {
			xmlFeed = Tuli.fileCache.get( path );
			
		} else {
			xmlFeed = feed;
			
		}
		
		if (xmlFeed.indexOf(id) == -1 && Tuli.fileCache.exists( '${html}index.html' )) {
			var dom = null;
			var domFeed = null;
			var domEntry = null;
			//trace( id );
			if (xmlCache.exists( html + 'index.html' )) {
				dom = xmlCache.get( html + 'index.html' );
				
			} else {
				dom = Tuli.fileCache.get( html + 'index.html' ).parse();
				
			}
			
			if (xmlCache.exists( path )) {
				domFeed = xmlCache.get( path );
				
			} else {
				domFeed = xmlFeed.parse();
				
			}
			
			var title = dom.find('h1').first().text().trim();
			
			if (title != '') {
				domEntry = entry.parse();
				
				domEntry.find('id').setText( id );
				domEntry.find('title').setText( title );
				domEntry.find('summary').setText( dom.find('p').first().text() );
				domEntry.find('content').setAttr('src', id).setAttr('type','text/html');
				domEntry.find('published').setText( Tuli.asISO8601( file.stats.ctime ) );
				
				domFeed.find('updated').setText( Tuli.asISO8601( file.stats.mtime ) );
				domEntry.find('updated').setText( Tuli.asISO8601( file.stats.mtime ) );
				
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
					result = result.replace(Markdown.characters.get( key ), key );
				}
				
				Tuli.fileCache.set( path, result );
				
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
		
		return content;
	}
	
}