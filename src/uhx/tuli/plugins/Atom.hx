package uhx.tuli.plugins;

import uhx.sys.Ioe;
import sys.io.File;
import sys.io.FileInput;
import uhx.sys.ExitCode;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
@:cmd
@:allow( Markdown )
@:usage('atom [options]')
class Atom extends Ioe implements Klas {

	@alias('i')
	public var input:String;
	
	@alias('o')
	public var output:String;
	
	private static var feed:FileInput;
	private static var entry:FileInput;
	private static var xmlCache:Map<String, DOMCollection> = new Map();
	
	public static function main() {
		var atom = new Atom( Sys.args() );
		atom.exit();
	}
	
	public function new(args:Array<String>) {
		if (feed == null) feed = File.read( '/templates/_feed.atom'.normalize() );
		if (entry == null) entry = File.read( '/templates/_entry.atom'.normalize() );
		process();
	}
	
	public function process() {
		if (input == null) {
			stderr.writeString( 'You must specify an input directory.' );
			exitCode = ExitCode.ERRORS;
		}
		
		if (output == null) {
			stderr.writeString( 'You must specify an output directory.' );
			exitCode = ExitCode.ERRORS;
		}
		
		if (exitCode == ExitCode.ERRORS) exit();
		
		var dir = input;
		var path = '$dir/atom.xml'.normalize();
		var html = '$input/'.normalize();
		var id = 'http://haxe.io/$html';
		
		var files = ''.readDirectory().map( function(p) return p.normalize() );
		var xmlFeed = feed.readAll().toString();
		if (xmlFeed.indexOf(id) == -1 && files.exists( '${html}index.html' )) {
			var dom = null;
			var domFeed = null;
			var domEntry = null;
			
			if (xmlCache.exists( html + 'index.html' )) {
				dom = xmlCache.get( html + 'index.html' );
				
			} else {
				dom = tuli.config.files.get( html + 'index.html' ).content.parse();
				
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
				domEntry.find('published').setText( tuli.asISO8601( file.created ) );
				
				domFeed.find('updated').setText( tuli.asISO8601( file.modified ) );
				domEntry.find('updated').setText( tuli.asISO8601( file.modified ) );
				
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