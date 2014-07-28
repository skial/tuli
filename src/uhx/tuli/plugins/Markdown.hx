package uhx.tuli.plugins;

import dtx.Tools;
import uhx.sys.Tuli;
import byte.ByteData;
import uhx.tuli.util.File;
import uhx.tuli.util.Spawn;
import uhx.lexer.MarkdownParser;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using uhx.tuli.util.File.Util;

/**
 * ...
 * @author Skial Bainn
 */
class Markdown {
	
	public static function main() return Markdown;
	
	private static var fileCache:Map<String, String>;
	
	// I hate this, need to spend some time on UTF8 so I dont have to manually
	// add international characters.
	public static var characters = [
	'ş' => '&#x015F;', '№' => '&#x2116;',
	'ê' => '&ecirc;', 'ä' => '&auml;',
	'é' => '&eacute;', 'ø' => '&oslash;',
	'ö' => '&ouml;',
	'“'=>'&ldquo;', '”'=>'&rdquo;' ];

	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		if (fileCache == null) fileCache = new Map();
		
		Tuli.onExtension('md', handler, Before);
	}
	
	public function handler(file:File) {
		// The output location to save the generated html.
		var spawned = (file.path.replace( Tuli.config.input, Tuli.config.output ).withoutExtension() + '/index.html').normalize();
		var output = spawned;
		var skip = FileSystem.exists( output ) && file.modified.getTime() < FileSystem.stat( output ).mtime.getTime();
		
		if (!skip) {
			for (key in characters.keys()) file.content = file.content.replace(key, characters.get(key));
			
			var parser = new MarkdownParser();
			var tokens = parser.toTokens( ByteData.ofString( file.content ), file.path );
			var resources = new Map<String, {url:String,title:String}>();
			parser.filterResources( tokens, resources );
			
			if (file.extra.md == null) file.extra.md = { };
			file.extra.md.resources = resources;
			
			var html = [for (token in tokens) parser.printHTML( token, resources )].join('');
			
			// Look for a template in the markdown `[_template]: /path/file.html`
			var template = resources.exists('_template') ? resources.get('_template') : { url:'', title:'' };
			var location = if (template.url == '') {
				'${Tuli.config.input}/templates/_template.html'.normalize();
			} else {
				(file.path.directory() + '/${template.url}').normalize();
			}
			
			if (template.title == null || template.title == '') {
				var token = tokens.filter(function(t) return switch (t.token) {
					case Keyword(Header(_, _, _)): true;
					case _: false;
				})[0];
				
				if (token != null) {
					template.title = switch (token.token) {
						case Keyword(Header(_, _, t)): 
							parser.printString( token );
							
						case _: 
							'';
					}
				}
			}
			
			var content = '';
			var tuliFiles = Tuli.config.files.filter( function(f) return [location].indexOf( f.path ) > -1 );
			for (tuliFile in tuliFiles) tuliFile.ignore = true;
			
			if (!fileCache.exists( location )) {
				// Grab the templates content.
				if (Tuli.config.files.exists( location )) {
					content = Tuli.config.files.get( location ).content;
					fileCache.set( location, content );
				} else {
					var f = new File( location );
					content = f.content;
					Tuli.config.files.push( f );
					fileCache.set( location, content );
				}
			} else {
				content = fileCache.get( location );
			}
			
			var dom = content.parse();
			
			for (key in characters.keys()) html = html.replace( characters.get(key), key );
			dom.find('content[select="markdown"]').replaceWith( null, dtx.Tools.parse( html ) );
			content = dom.html();
			/*if (file.path.toLowerCase().indexOf( 'one year of haxe' ) > -1) {
				trace( dtx.Tools.parse( html ) );
				trace( content );
			}*/
			if (file.spawned.indexOf( spawned ) == -1) {
				file.spawned.push( spawned );
				
				var spawn = new Spawn( spawned, file.path );
				spawn.content = content;
				spawn.extra.md = {};
				spawn.extra.md.resources = resources;
				spawn.created = file.created;
				spawn.modified = file.modified;
				
				Tuli.config.spawn.push( spawn );
			}
			
		}
		
		file.ignore = true;
	}
	
}