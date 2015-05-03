package ;

import haxe.Json;
import sys.io.File;
import haxe.io.Path;
import sys.FileSystem;
import haxe.Unserializer;
import uhx.sys.Tuli;

using haxe.io.Path;
using sys.FileSystem;

using Lambda;

/**
 * ...
 * @author Skial Bainn
 */

@:cmd
@:access(uhx.sys.Tuli)
@:usage( 'haxelib run tuli [options]' )
class LibRunner implements Klas {
	
	static function main() {
		var runner = new LibRunner( Sys.args() );
	}
	
	/**
	 * Makes tuli global.
	 */
	@alias('g') 
	public var global:Bool;
	
	/**
	 * The location of your json file. Default config.json.
	 */
	@alias('c') 
	public var config:String = 'config.json';
	
	/**
	 * Define a conditional flag.
	 */
	@alias('D', 'd')
	public var defines:Array<String> = [];
	
	private var tuli:Tuli;
	
	public function new(args:Array<String>) {
		directory = args[args.length - 1].normalize();
		config = '$directory/$config'.normalize();
		
		Sys.setCwd( directory );
		
		if (config.exists()) {
			tuli = new Tuli( config );
			
			if (defines.length > 0) tuli.defines = tuli.defines.concat( defines );
			
		} else {
			Sys.println( 'A configuration file could not be found in $directory, please use -c <path> to set one.' );
			return;
			
		}
		
		if (global) makeGlobal();
		
		if (tuli != null) {
			tuli.setup();
			tuli.runJobs();
			
		}
	}
	
	private var directory:String;
	
	private function makeGlobal() {
		if (!Sys.environment().exists( 'HAXEPATH' )) {
			Sys.println( 'The enviroment HAXEPATH does not exist.' );
			return;
			
		}
		
		var path = Sys.environment().get( 'HAXEPATH' ).normalize();
		
		switch (Sys.systemName().toLowerCase()) {
			case _.indexOf( 'windows' ) > -1 => true if ('$path/tuli.bat'.normalize().exists()):
				Sys.println( 'Tuli has already been made global.' );
				return;
				
			case _ if ('$path/tuli.sh'.normalize().exists()): 
				Sys.println( 'Tuli has already been made global.' );
				return;
				
		}
		
		switch (Sys.systemName().toLowerCase()) {
			case _.indexOf( 'windows' ) > -1 => true:
				File.saveContent( '$path/tuli.bat'.normalize(), '@echo off\r\nhaxelib run tuli %*' );
				
			case _.indexOf( 'linux' ) > -1 => true:
				File.saveContent( '$path/tuli.sh'.normalize(), '# Bash\r\n#!/bin/sh\r\nhaxelib run tuli $@' );
				
			case _.indexOf( 'mac' ) > -1 => true:
				File.saveContent( '$path/tuli.sh'.normalize(), '# Bash\r\n#!/bin/sh\r\nhaxelib run tuli $@' );
				
			case _: 
				Sys.println( 'Can not determine the OS type, apologies.' );
				
		}
	}
	
}