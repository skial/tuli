package uhx.tuli.plugins;

import sys.io.File;
import uhx.sys.Tuli;
import byte.ByteData;
import uhx.lexer.MarkdownParser;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

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
	'ş' => '&#x015F;', '№' => '&#8470;',
	'ê' => '&ecirc;', 'ä' => '&auml;',
	'é' => '&eacute;', 'ø' => '&oslash;',
	'ö' => '&ouml;',
	'“'=>'&ldquo;', '”'=>'&rdquo;' ];

	public function new(tuli:Class<Tuli>) {
		untyped Tuli = tuli;
		if (fileCache == null) fileCache = new Map();
		
		Tuli.onExtension('md', handler, After);
	}
	
	public function handler(file:TuliFile, content:String):String {
		// The output location to save the generated html.
		var spawned = '${file.path.withoutExtension()}/index.html'.normalize();
		var output = '${Tuli.config.output}/$spawned';
		var skip = FileSystem.exists( output ) && file.stats.mtime.getTime() < FileSystem.stat( output ).mtime.getTime();
		
		if (!skip) {
			for (key in characters.keys()) content = content.replace(key, characters.get(key));
			
			var parser = new MarkdownParser();
			var tokens = parser.toTokens( ByteData.ofString( content ), file.path );
			var resources = new Map<String, {url:String,title:String}>();
			parser.filterResources( tokens, resources );
			
			if (file.extra.md == null) file.extra.md = { };
			file.extra.md.resources = resources;
			
			var html = [for (token in tokens) parser.printHTML( token, resources )].join('');
			
			// Look for a template in the markdown `[_template]: /path/file.html`
			var template = resources.exists('_template') ? resources.get('_template') : { url:'', title:'' };
			var location = if (template.url == '') {
				'/_template.html';
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
						case Keyword(Header(_, _, t)): t;
						case _: '';
					}
				}
			}
			
			var content = '';
			
			var tuliFiles = Tuli.config.files.filter( function(f) return [location].indexOf( f.path ) > -1 );
			for (tuliFile in tuliFiles) tuliFile.ignore = true;
			
			if (!fileCache.exists( location )) {
				// Grab the templates content.
				if (Tuli.fileCache.exists( location )) {
					content = Tuli.fileCache.get(location);
					fileCache.set(location, content);
				} else {
					content = File.getContent( (Tuli.config.input + '/${location}').normalize() );
					Tuli.fileCache.set( location, content );
					fileCache.set( location, content );
				}
			} else {
				content = fileCache.get( location );
			}
			
			var dom = content.parse();
			
			dom.find('content[select="markdown"]').replaceWith( null, dtx.Tools.parse( html ) );
			content = dom.html();
			
			// Add the new file location and contents into Tuli's `fileCache` which
			// it will save for us.
			Tuli.fileCache.set( spawned, content );
			
			if (file.spawned.indexOf( spawned ) == -1) {
				file.spawned.push( spawned );
				Tuli.config.spawn.push( {
					size: 0,
					extra: {
						md: {
							resources: resources,
						}
					},
					spawned: [],
					ext: 'html',
					ignore: false,
					path: spawned,
					parent: file.path,
					created: Tuli.asISO8601(Date.now()),
					modified: Tuli.asISO8601(Date.now()),
					name: spawned.withoutDirectory().withoutExtension(),
					stats: file.stats,
				} );
			}
			
		}
		
		file.ignore = true;
		
		return content;
	}
	
}