package uhx.tuli.plugins;

import dtx.Tools;
import geo.TzDate;
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
	private var tuli:Tuli;
	
	// I hate this, need to spend some time on UTF8 so I dont have to manually
	// add international characters.
	public static var characters = [
	'ş' => '&#x015F;', '№' => '&#x2116;',
	'ê' => '&ecirc;', 'ä' => '&auml;',
	'é' => '&eacute;', 'ø' => '&oslash;',
	'ö' => '&ouml;',
	'“'=>'&ldquo;', '”'=>'&rdquo;' ];

	public function new(t:Tuli) {
		tuli = t;
		tuli.onExtension('md', handler, Before);
	}
	
	public function handler(file:File) {
		// The output location to save the generated html.
		var spawned = (file.path.replace( tuli.config.input, tuli.config.output ).withoutExtension() + '/index.html').normalize();
		var output = spawned;
		var skip = FileSystem.exists( output ) && file.modified.getTime() < FileSystem.stat( output ).mtime.getTime();
		
		if (!skip) {
			for (key in characters.keys()) file.content = file.content.replace(key, characters.get(key));
			
			var parser = new MarkdownParser();
			var tokens = parser.toTokens( ByteData.ofString( file.content ), file.path );
			var resources = new Map<String, {url:String,title:String}>();
			parser.filterResources( tokens, resources );
			
			if (file.data.md == null) {
				file.data.md = { };
			}
			
			// Attach the resource's to the file for use by others.
			file.data.md.resources = resources;
			
			// Using information from `resources` update the `file` properties.
			if (resources.exists('date')) file.created = TzDate.fromFormat( '', resources.get('date').title, 0 );
			if (resources.exists('modified')) file.modified = TzDate.fromFormat( '', resources.get('modified').title, 0 );
			var template = resources.exists('template') ? resources.get('template').url : '';
			var title = resources.exists('title') ? resources.get('title').title : '';
			
			// Turn the tokens into html.
			var html = [for (token in tokens) parser.printHTML( token, resources )].join('\r\n');
			
			var location = if (template == '') {
				'${tuli.config.input}/templates/_template.html'.normalize();
			} else {
				'${file.path.directory()}/${template}'.normalize();
			}
			
			if (title == '') {
				var token = tokens.filter(function(t) return switch (t.token) {
					case Keyword(Header(_, _, _)): true;
					case _: false;
				})[0];
				
				if (token != null) {
					title = switch (token.token) {
						case Keyword(Header(_, _, t)): 
							parser.printString( token );
							
						case _: 
							'';
					}
				}
			}
			
			var content = file.content;
			var dom = content.parse();
			
			for (key in characters.keys()) html = html.replace( characters.get(key), key );
			dom.find('content[select="markdown"]').replaceWith( null, dtx.Tools.parse( html ) );
			content = dom.html();
			
			if (file.spawned.indexOf( spawned ) == -1) {
				file.spawned.push( spawned );
				
				var spawn = new Spawn( spawned, file.path );
				spawn.content = content;
				spawn.data.md = {};
				spawn.data.md.resources = resources;
				spawn.created = file.created;
				spawn.modified = file.modified;
				
				tuli.config.spawn.push( spawn );
			}
			
		}
		
		file.ignore = true;
	}
	
}