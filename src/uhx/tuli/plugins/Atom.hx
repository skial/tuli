package uhx.tuli.plugins;

import geo.TzDate;
import uhx.sys.Tuli;
import uhx.tuli.util.File;
import uhx.tuli.plugins.impl.t.Feed;

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
		var df = '%Y-%m-%dT%H:%M:%S%z';
		var config:Feed = tuli.config.data.feed;
		var feedDom = feed.content.parse();
		var entryDom = entry.content.parse();
		var entryClone = null;
		
		if (config == null) config == { };
		if (config.type == null) config.type = Link;
		
		if (tuli.config.data.domain != null) for (file in files) if (file.ext == 'md' && file.spawned.length > 0) {
			var spawns = file.spawned.map( function(f) {
				return tuli.spawn.get( f );
			} );
			
			for (spawn in spawns) {
				var content = spawn.content.parse();
				var uri = spawn.path.replace( tuli.config.output, tuli.config.data.domain ).normalize();
				
				entryClone = entryDom.clone();
				entryClone.find( 'id' ).setText( uri );
				entryClone.find( 'title' ).setText( content.find( 'title' ).text() );
				entryClone.find( 'published' ).setText( TzDate.formatAs( spawn.created, df ) );
				entryClone.find( 'updated' ).setText( TzDate.formatAs( spawn.modified, df ) );
				
				switch (config.type) {
					case Full:
						entryClone.find( 'content' ).setAttr( 'type', 'html' ).append( content.find( 'body' ) );
						
					case Summary:
						
						
					case Link, _:
						entryClone.find( 'content' ).setAttr( 'src', uri );
						
				}
				
			}
		}
		
		return files;
	}
	
}