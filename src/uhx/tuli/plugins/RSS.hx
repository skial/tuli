package uhx.tuli.plugins;

import uhx.sys.Tuli;
import uhx.tuli.util.File;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using uhx.tuli.util.File.Util;

private typedef RSSConfig = {
	var feed_template:String;
	var entry_template:String;
}
/**
 * ...
 * @author Skial Bainn
 */
class RSS {
	
	private static var feed:File;
	private static var entry:File;
	private static var tuli:Tuli;
	private static var options:RSSConfig;
	
	public static function main() return RSS;
	
	public function new(t:Tuli) {
		tuli = t;
		
		options = tuli.config.extra.plugins;
		
		if (options.feed_template != null) {
			feed = new File( '${tuli.config.input}/${options.feed_template}'.normalize() );
		} else {
			feed = new File( '${tuli.config.input}/templates/_feed.rss'.normalize() );
		}
		
		if (options.entry_template != null) {
			feed = new File( '${tuli.config.input}/${options.entry_template}'.normalize() );
		} else {
			entry = new File( '${tuli.config.input}/templates/_entry.rss'.normalize() );
		}
		
		tuli.onExtension('md', handler, After);
	}
	
	public function handler(file:File) {
		for (f in tuli.config.files.filter(function(f) {
			return ['_feed.rss', '_entry.rss'].indexOf(f.path) != -1;
		} )) f.ignore = true;
		
		var dir = file.path.directory();
		if (dir == '') dir = 'articles';
		var path = '$dir/rss.xml'.normalize();
		var html = path.replace( tuli.config.input, 'http://haxe.io/' ).normalize();
		var id = 'http://haxe.io/$html';
		trace( id );
		var xmlFeed = null;
		
		if (tuli.config.files.exists( path )) {
			xmlFeed = tuli.config.files.get( path );
			
		} else {
			xmlFeed = feed;
			tuli.config.files.push( xmlFeed );
			
		}
		
		if (xmlFeed.content.indexOf(id) == -1) {
			var dom = tuli.config.files.get( '${file.path.withoutExtension()}/index.html'.normalize() ).content.parse();
			var domFeed = xmlFeed.content.parse();
			var domEntry = null;
			
			var title = dom.find('h1').first().text();
			
			if (title != '') {
				
				domEntry = entry.content.parse();
				
				domEntry.find('guid').setText( id );
				domEntry.find('link').setText( id );
				domEntry.find('title').setText( title );
				domEntry.find('description').setText( dom.find('p').first().text() );
				domEntry.find('pubDate').setText( DateTools.format( file.created, '%a, %d %b %Y %H:%M:%S GMT' ) );
				
				domFeed.find('pubDate').setText( DateTools.format( file.created, '%a, %d %b %Y %H:%M:%S GMT' ) );
				domFeed.find('lastBuildDate').setText( DateTools.format( file.modified, '%a, %d %b %Y %H:%M:%S GMT' ) );
				domFeed.find('ttl').next().setAttr('href', 'http://haxe.io/$path');
				
				domFeed.find('channel').append( null, domEntry );
				
				var result = domFeed.html();
				var lowered = ['pubdate>' => 'pubDate>', 'lastbuilddate>' => 'lastBuildDate>'];
				
				for (key in lowered.keys()) {
					result = result.replace(key, lowered.get( key ));
				}
				
				while (result.indexOf('&amp;') > -1) {
					result = result.replace('&amp;', '&');
				}
				
				for (key in Markdown.characters.keys()) {
					result = result.replace( Markdown.characters.get( key ), key );
				}
				
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