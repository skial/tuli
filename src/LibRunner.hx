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
class LibRunner {
	
	static function main() {
		var runner = new LibRunner( Sys.args() );
	}
	
	/**
	 * Makes tuli global.
	 */
	@alias('g') 
	public var global:Bool;
	
	/**
	 * Your json file. Default config.json.
	 */
	@alias('c') 
	public var config:String = 'config.json';
	
	/**
	 * Define a conditional flag.
	 */
	@alias('D')
	public var defines:Array<String> = [];
	
	/**
	 * Does not execute any commands.
	 */
	@alias('d')
	@:native('dry-run')
	public var dryRun:Bool;
	
	private var tuli:Tuli;
	
	public function new(args:Array<String>) {
		@:cmd _;
		
		if (args != null && args.length == 0) {
			directory = Sys.getCwd();
			
		} else {
			directory = args[args.length - 1].normalize();
			Sys.setCwd( directory );
			
		}
		
		config = '$directory/$config'.normalize();
		
		if (config.exists()) {
			trace( 'config exists' );
			tuli = new Tuli( config );
			if (defines.length > 0) Tuli.toplevel.defines = Tuli.toplevel.defines.concat( defines );
			
		} else {
			Sys.println( 'A configuration file could not be found in $directory, please use -c <path> to set one.' );
			return;
			
		}
		trace( dryRun );
		if (global) makeGlobal();
		
		if (tuli != null) {
			tuli.dryRun = dryRun;
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
