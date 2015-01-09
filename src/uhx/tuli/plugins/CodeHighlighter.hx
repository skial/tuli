package uhx.tuli.plugins;

import haxe.io.Eof;
import uhx.sys.Ioe;
import sys.io.File;
import tjson.TJSON;
import haxe.Resource;
import byte.ByteData;
import haxe.io.Input;
import haxe.io.Output;
import uhx.sys.ExitCode;

#if macro
import haxe.macro.Expr;
#end

using Detox;
using StringTools;
using haxe.io.Path;

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
	'highlight [options]',
	'highlight -i /src/package/Main.hx -o /bin/package/Main.html',
	'highlight -i /src/package/Main.hx -o /bin/data/Main.json -f json'
)
class CodeHighlighter extends Ioe implements Klas {
	
	@alias('i')
	public var input:String;
	
	@alias('o')
	public var output:String;
	
	@:isVar
	@alias('l')
	public var language(default, set):String;
	
	@alias('d')
	public var directory:String;
	
	//@alias('a')
	//public var auto:Bool = false;
	
	@alias('f')
	public var format:OutputFormat = 'html';
	
	public static function main() {
		var high = new CodeHighlighter( Sys.args() );
		high.exit();
	}

	public function new(args:Array<String>) {
		super();
		@:cmd _;
		if (exitCode != ExitCode.SUCCESS) exit();
		process();
	}
	
	/**
	 * Provides more information on certain commands.
	 */
	public function info(?topic:String = ''):Void {
		switch (topic) {
			case 'language':
				Sys.println( 'The supported languages are:\n' + [for (key in Lang.uage.keys()) key].filter( function(s) return s.length > 2 ).map( function(s) return '\t$s\n' ).join('') );
				
			case _:
				Sys.println( 'You can get extra information on the following commands:\n\tlanguage' );
				
		}
		exitCode = ExitCode.WARNINGS;
	}
	
	override private function process(?i:Input, ?o:Output) {
		if (language == null) {
			if (input != null && input.extension() != '' && Lang.uage.exists( input.extension() )) {
				language = input.extension().toLowerCase();
				
			} else if (output != null && output.extension() != '' && Lang.uage.exists( output.extension() )) {
				language = output.extension().toLowerCase();
				
			} else {
				stderr.writeString( 'You must specify a programming language be to used. Try --info language' );
				exitCode = ExitCode.ERRORS;
				
			}
		}
		
		super.process(
			input == null ? null : (File.read( input ):Input), 
			output == null ? null : (File.write( output ):Output)
		);
		
		var result = '';
		var lang = Lang.uage.get( language );
		
		if (lang != null) {
			var tokens = lang.toTokens( ByteData.ofString( content ), 'code-highlighter-$language' );
			var html = [for (token in tokens) lang.printHTML( token )].join( '\n' );
			
			switch (format) {
				case HTML:
					result = html;
					
				case JSON:
					var _output = {
						html: html,
						language: language,
						css: Resource.listNames().indexOf( '$language.flat16.css' ) > -1 ? Resource.getString( '$language.flat16.css' ) : '',
					}
					
					result = TJSON.encode( _output, 'fancy' );
					
				case _:
					
			}
		}
		
		stdout.writeString( result );
		
	}
	
	@:noCompletion private function set_language(v:String):String {
		language = v.toLowerCase();
		return language;
	}
	
}