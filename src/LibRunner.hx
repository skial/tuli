package ;

import haxe.Json;
import sys.io.File;
import haxe.io.Path;
import sys.FileSystem;
import haxe.Unserializer;
import uhx.sys.Tuli;
import uhx.tuli.util.Directory;

using haxe.io.Path;
using sys.FileSystem;

using Lambda;

/**
 * ...
 * @author Skial Bainn
 */

@:cmd
@:usage( 'haxelib run tuli [options]' )
class LibRunner implements Klas {
	
	static function main() {
		var runner = new LibRunner( Sys.args() );
	}
	
	/**
	 * Allows you to run `tuli [options]` from now on.
	 */
	@alias('g') 
	public var global:Bool = false;
	
	/**
	 * Remove the output directory.
	 */
	@alias('c') 
	public var clean:Bool = false;
	
	/**
	 * Removes the output directory and builds
	 * everything from scratch.
	 */
	@alias('b') 
	public var build:Bool = false;
	
	/**
	 * Only processes files that have changed or been created
	 * since the last time Tuli was run.
	 */
	@alias('u') 
	public var update:Bool = false;
	
	/**
	 * Run `update` and start a server from the output directory
	 * on port 8080.
	 */
	@alias('t') 
	public var test:Bool = false;
	
	/**
	 * Sets the location of your configuration file.
	 * The default location is the current working directory with
	 * the name of `_config.json`.
	 */
	@alias('f') 
	public var file:String = '_config.json';
	
	/**
	 * Setups a the folder structure in the current directory.
	 */
	public var init:Bool = false;
	
	private var tuli:Tuli;
	private var directory:String;
	
	public function new(args:Array<String>) {
		var set = [global, clean, build, update, test, init].filter( function(b) {
			return b;
		} );
		
		if (set.length == 0) {
			// Make update the default action.
			update = true;
			
		}
		
		directory = args[args.length - 1].normalize();
		file = '$directory/$file'.normalize();
		
		Sys.setCwd( directory );
		
		if (init) {
			runInit();
			
		}
		
		if (file.exists()) {
			tuli = new Tuli( new uhx.tuli.util.File( file ) );
			
		} else {
			Sys.println( 
				'A configuration file could not be found in $directory, please' +
				' use -f <path> to set one or use --init to setup a new project.'
			);
			return;
			
		}
		
		if (global) {
			makeGlobal();
			
		}
		
		if (clean) {
			runClean();
			
		}
		
		if (build) {
			runClean();
			runBuild();
			
		}
		
		if (update) {
			runUpdate();
			
		}
		
		if (test) {
			runUpdate();
			serve();
			
		}
	}
	
	private function runInit() {
		for (folder in ['src/_data', 'src/_templates', 'bin']) {
			Directory.create( '$directory/$folder'.normalize() );
		}
		
		var _config = new uhx.tuli.util.File( '$directory/_config.json' );
		_config.content = '{\r\n\t"input":"$directory/src/",\r\n\t"output":"$directory/bin/",\r\n\t"ignore":[],\r\n\t"plugins":[]\r\n\t"data":{}\r\n}';
		_config.save();
	}
	
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
	
	private function runClean() {
		FileSystem.deleteDirectory( tuli.config.output );
		FileSystem.createDirectory( tuli.config.output );
	}
	
	private function runBuild() {
		tuli.start();
	}
	
	private function runUpdate() {
		tuli.start();
	}
	
	private function serve() {
		
	}
	
}