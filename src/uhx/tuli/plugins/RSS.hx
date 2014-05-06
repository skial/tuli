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
class RSS {
	
	private static var feed:String;
	private static var entry:String;
	private static var xmlCache:Map<String, DOMCollection> = new Map();
	
	public static function main() return RSS;
	
	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		Tuli.onExtension('md', handler, After);
	}
	
	public function handler(file:TuliFile, content:String):String {
		if (feed == null) feed = File.getContent('${Tuli.config.input}/_feed.rss'.normalize());
		if (entry == null) entry = File.getContent('${Tuli.config.input}/_entry.rss'.normalize());
		
		for (f in Tuli.config.files.filter(function(f) {
			return ['_feed.rss', '_entry.rss'].indexOf(f.path) != -1;
		} )) f.ignore = true;
		
		var dir = file.path.directory();
		if (dir == '') dir = 'articles';
		var path = '$dir.rss'.normalize();
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
			
			var title = dom.find('h1').first().text();
			
			if (title != '') {
				
				domEntry = entry.parse();
				
				domEntry.find('guid').setText( id );
				domEntry.find('link').setText( id );
				domEntry.find('title').setText( title );
				domEntry.find('description').setText( dom.find('p').first().text() );
				domEntry.find('pubDate').setText( DateTools.format( file.stats.ctime, '%a, %d %b %Y %H:%M:%S GMT' ) );
				
				domFeed.find('pubDate').setText( DateTools.format( file.stats.ctime, '%a, %d %b %Y %H:%M:%S GMT' ) );
				domFeed.find('lastBuildDate').setText( DateTools.format( file.stats.mtime, '%a, %d %b %Y %H:%M:%S GMT' ) );
				domFeed.find('ttl').next().setAttr('href', 'http://haxe.io/$path');
				
				domFeed.find('channel').append( null, domEntry );
				
				xmlCache.set( path, domFeed );
				
				if (!xmlCache.exists( html + 'index.html' )) {
					xmlCache.set( html + 'index.html', dom );
				}
				
				var result = domFeed.html();
				var lowered = ['pubdate>' => 'pubDate>', 'lastbuilddate>' => 'lastBuildDate>'];
				
				for (key in lowered.keys()) {
					result = result.replace(key, lowered.get( key ));
				}
				
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