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
		var df = '%Y-%m-%dT%H:%M:%S%z';
		var config:Feed = tuli.config.data.feed;
		var feedDom = feed.content.parse();
		var entryDom = entry.content.parse();
		var entryClone = null;
		
		if (config == null) config = { type:null };
		if (config.type == null) config.type = Link;
		
		if (tuli.config.data.domain != null) feedDom.find( 'id' ).setText( tuli.config.data.domain );
		
		if (tuli.config.data.domain != null) for (file in files) if (file.ext == 'md' && file.spawned.length > 0) {
			var spawns = file.spawned.map( function(f) {
				return tuli.spawn.get( f );
			} );
			
			for (spawn in spawns) {
				var content = spawn.content.parse();
				var uri = spawn.path.replace( tuli.config.output, (tuli.config.data.domain:String).addTrailingSlash() ).normalize();
				var details:Details = spawn.data;
				
				entryClone = entryDom.clone();
				entryClone.find( 'id' ).setText( uri );
				entryClone.find( 'title' ).setText( details.title );
				entryClone.find( 'published' ).setText( spawn.created.format( df ) );
				entryClone.find( 'updated' ).setText( spawn.modified.format( df ) );
				feedDom.find( 'feed > updated' ).setText( spawn.modified.format( df ) );
				
				if (tuli.config.data.author != null) {
					entryClone.find( 'author name' ).setText( (tuli.config.data.author:String) );
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
				
				feedDom.find( 'feed > author' ).afterThisInsert( null, entryClone );
				
			}
		}
		
		var atom = new File( '${tuli.config.output}/atom.xml'.normalize() );
		atom.content = feedDom.html();
		files.push( atom );
		
		return files;
	}
	
}