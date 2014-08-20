package uhx.tuli.plugins;

import geo.TzDate;
import uhx.sys.Tuli;
import uhx.tuli.util.File;
import uhx.tuli.plugins.impl.t.*;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using uhx.tuli.util.File.Util;

private typedef Config = {
	var feed:Null<String>;
	var entry:Null<String>;
}

/**
 * ...
 * @author Skial Bainn
 */
class Atom {
	
	public static function main() return Atom;
	
	private var tuli:Tuli;
	private var config:Config;
	private var feed:File;
	private var entry:File;
	
	public function new(t:Tuli, c:Config) {
		tuli = t;
		config = c;
		
		feed = new File( (c.feed == null ? '${tuli.config.input}/templates/_feed.atom' : '${tuli.config.input}/${c.feed}').normalize() );
		entry = new File( (c.entry == null? '${tuli.config.input}/templates/_entry.atom' : '${tuli.config.input}/${c.entry}').normalize() );
		
		tuli.onAllFiles(handler, After);
	}
	
	public function handler(files:Array<File>):Array<File> {
		var df = '%Y-%m-%dT%H:%M:%SZ%z';
		var site:Site = tuli.config.data.site;
		var config:Feed = tuli.config.data.feed;
		var feedDom = feed.content.parse();
		var entryDom = entry.content.parse();
		var entryClone = null;
		
		if (config == null) config = { type:null };
		if (config.type == null) config.type = Link;
		
		if (site.title != null) feedDom.find( 'title' ).setText( site.title );
		if (site.domain != null) feedDom.find( 'id' ).setText( site.domain );
		if (site.authors != null && site.authors.length > 0) {
			var authorDom = feedDom.find( 'feed > author' );
			
			for (author in site.authors) {
				var authorClone = authorDom.clone();
				authorClone.find( 'name' ).setText( author );
				feedDom.find( 'feed > author' ).last().afterThisInsert( null, authorClone );
			}
			
			authorDom.remove();
		}
		
		if (site.contributors != null && site.contributors.length > 0) {
			var contributorDom = feedDom.find( 'feed > contributor' );
			
			for (contributor in site.contributors) {
				var contributorClone = contributorDom.clone();
				contributorClone.find( 'name' ).setText( contributor );
				feedDom.find( 'feed > contributor' ).last().afterThisInsert( null, contributorClone );
			}
			
			contributorDom.remove();
		}
		
		feedDom.find( 'feed > link' ).setAttr( 'rel', 'self' ).setAttr( 'href', '${site.domain}/atom.xml'.normalize() );
		
		if (site.domain != null) for (file in files) if (file.ext == 'md' && file.spawned.length > 0) {
			var spawns = file.spawned.map( function(f) {
				return tuli.spawn.get( f );
			} );
			
			for (spawn in spawns) {
				var content = spawn.content.parse();
				var uri = spawn.path.replace( tuli.config.output, site.domain.addTrailingSlash() ).normalize();
				var details:Details = spawn.data;
				
				entryClone = entryDom.clone();
				// See http://web.archive.org/web/20110514113830/http://diveintomark.org/archives/2004/05/28/howto-atom-id
				entryClone.find( 'id' ).setText( 'tag:${site.domain},${spawn.created.format("%Y-%m-%d")}' );
				entryClone.find( 'title' ).setText( details.title );
				entryClone.find( 'published' ).setText( spawn.created.format( df ) );
				entryClone.find( 'updated' ).setText( spawn.modified.format( df ) );
				feedDom.find( 'feed > updated' ).setText( spawn.modified.format( df ) );
				
				if (details.authors != null && details.authors.length > 0) {
					var authorDom = entryClone.find( 'entry > author' );
					
					for (author in details.authors) {
						var authorClone = authorDom.clone();
						authorClone.find( 'name' ).setText( author );
						entryClone.find( 'entry > author' ).last().afterThisInsert( null, authorClone );
					}
					
					authorDom.remove();
				} else {
					entryClone.find( 'entry > author' ).remove();
				}
				
				switch (config.type) {
					case Full:
						entryClone.find( 'content' ).setAttr( 'type', 'html' ).append( content.find( 'body' ) );
						entryClone.find( 'summary' ).remove();
						
					case Summary if (details.summary != null):
						entryClone.find( 'summary' ).setText( details.summary );
						
					case Summary if (details.summary == null):
						entryClone.find( 'summary' ).remove();
						
					case Link, _:
						entryClone.find( 'content' ).setAttr( 'src', uri );
						entryClone.find( 'summary' ).remove();
						
				}
				
				feedDom.find( 'feed > contributor' ).last().afterThisInsert( null, entryClone );
				
			}
		}
		
		var atom = new File( '${tuli.config.output}/atom.xml'.normalize() );
		atom.content = feedDom.html();
		files.push( atom );
		
		return files;
	}
	
}