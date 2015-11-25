package uhx.sys;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import systools.FileUtils;
import utest.Assert;
import utest.Runner;
import sys.io.Process;
import utest.ui.Report;

using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
@:access(uhx.sys.Tuli) class TuliSpec {
	
	public static function main() {
		var runner = new Runner();
		runner.addCase( new TuliSpec() );
		Report.create( runner );
		runner.run();
		
		// Doesnt appear to work. Probably permissions.
		/*if ('${FileUtils.getTempFolder()}/tuli/test/'.exists()) {
			'${FileUtils.getTempFolder()}/tuli/test/'.deleteDirectory();
			
		}*/
	}
	
	public static inline function process(config:Dynamic) {
		var c = '${FileUtils.getTempFolder()}/tuli/test/cf.json';
		trace( FileUtils.getTempFolder() );
		if (!'${FileUtils.getTempFolder()}/tuli/test/'.exists()) {
			Tuli.createDirectory( '${FileUtils.getTempFolder()}/tuli/test/' );
			
		}
		File.saveContent( c, Json.stringify( config ) );
		var t = new Tuli( c );
		t.setup();
		return t;
	}

	public function new() {
		
	}
	
	public function testDefines() {
		var t = process( { define:['a', 'b', 'c'] } );
		var d = Tuli.toplevel.defines;
		Assert.contains( 'a', d );
		Assert.contains( 'b', d );
		Assert.contains( 'c', d );
	}
	
	public function testEnvironment_systemDefaults() {
		var t = process( { env: { } } );
		var e = Tuli.toplevel.environment;
		Assert.isTrue( e.exists( 'HAXEPATH' ) );
	}
	
	public function testEnvironment_configValues() {
		trace( [for (k in Sys.environment().keys()) k] );
		trace( [for (k in Sys.environment().keys()) '$k :: ' + Sys.environment().get( k )] );
		
		var t = process( { env: { tuliTest: 'hello world' } } );
		var e = Tuli.toplevel.environment;
		Assert.isTrue( e.exists( 'tuliTest' ) );
		Assert.isFalse( Sys.environment().exists( 'tuliTest' ) );
	}
	
	public function testEnvironment_if() {
		var t = process( { env: { always:'awesome', 'if': { 'HAXEPATH': { everythingis:'awesome' }}}} );
		var e = Tuli.toplevel.environment;
		Assert.isTrue( e.exists( 'always' ) );
		Assert.equals( 'awesome', e.get( 'always' ) );
		Assert.isTrue( e.exists( 'HAXEPATH' ) );
		Assert.isTrue( e.exists( 'everythingis' ) );
		Assert.equals( 'awesome', e.get( 'everythingis' ) );
	}
	
}