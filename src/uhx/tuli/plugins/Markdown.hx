package uhx.tuli.plugins;

import dtx.Tools;
import haxe.Json;
import haxe.io.Eof;
import uhx.sys.Ioe;
import sys.io.File;
import tjson.TJSON;
import byte.ByteData;
import haxe.io.Input;
import haxe.io.Output;
import uhx.sys.ExitCode;
import uhx.lexer.MarkdownParser;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

@:forward @:enum abstract OutputFormat(String) from String to String {
	public var HTML = 'html';
	public var JSON = 'json';
}

/**
 * ...
 * @author Skial Bainn
 */
@:cmd
@:usage( 
	'markdown [options]',
	'markdown -i /src/package/Main.hx -o /bin/package/Main.html',
	'markdown -i /src/package/Main.hx -o /bin/data/Main.json -f json'
)
class Markdown extends Ioe implements Klas {
	
	public static function main() {
		var md = new Markdown( Sys.args() );
		md.exit();
	}
	
	@alias('f')
	public var format:OutputFormat = 'html';
	
	@alias('i')
	public var input:String;
	
	@alias('o')
	public var output:String;
	
	// I hate this, need to spend some time on UTF8 so I dont have to manually
	// add international characters.
	private static var characters = [
	'ş' => '&#x015F;', '№' => '&#x2116;',
	'ê' => '&ecirc;', 'ä' => '&auml;',
	'é' => '&eacute;', 'ø' => '&oslash;',
	'ö' => '&ouml;',
	'“'=>'&ldquo;', '”'=>'&rdquo;',
	'É' => '&Eacute;', 'õ' => '&otilde;'];

	public function new(args:Array<String>) {
		super();
		@:cmd _;
		process();
	}
	
	override private function process(?i:Input, ?o:Output) {
		super.process(
			input == null ? null : (File.read( input ):Input), 
			output == null ? null : (File.write( output ):Output)
		);
		
		if (input == null) {
			// On windows, text entered on the command line with `""` are included, remove them.
			if (content.startsWith('"')) content = content.substring(1);
			if (content.endsWith('"')) content = content.substr(0, content.length - 1);
			
		}
		
		for (key in characters.keys()) content = content.replace(key, characters.get(key));
		
		var parser = new MarkdownParser();
		var tokens = parser.toTokens( ByteData.ofString( content ), 'markdown-cmd' );
		var resources = new Map<String, {url:String,title:String}>();
		parser.filterResources( tokens, resources );
		
		var result = '';
		
		switch (format.toLowerCase()) {
			case HTML:
				result = [for (token in tokens) parser.printHTML( token, resources )].join('');
				for (key in characters.keys()) result = result.replace( characters.get( key ), key );
				
			case JSON:
				var _output = {
					resources: { },
					html: [for (token in tokens) parser.printHTML( token, resources )].join(''),
				};
				
				for (key in resources.keys()) Reflect.setField( _output.resources, key, resources.get( key ) );
				result = TJSON.encode( _output, 'fancy' );
				
			case _:
				
		}
		
		stdout.writeString( result );
		
		parser = null;
		tokens = null;
		result = null;
		resources = null;
		
		exitCode = ExitCode.SUCCESS;
	}
	
}