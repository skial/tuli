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
	
	/*public function testDefines() {
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
	
	public function testEnvironment_ifTrue() {
		var t = process( { env: { always:'awesome', 'if': { 'HAXEPATH': { everythingis:'awesome' }}}} );
		var e = Tuli.toplevel.environment;
		Assert.isTrue( e.exists( 'always' ) );
		Assert.equals( 'awesome', e.get( 'always' ) );
		Assert.isTrue( e.exists( 'HAXEPATH' ) );
		Assert.isTrue( e.exists( 'everythingis' ) );
		Assert.equals( 'awesome', e.get( 'everythingis' ) );
	}
	
	public function testEnvironment_ifFalse() {
		var t = process( { env: { always:'awesome', 'if': { '!blahTuli': { everythingis:'awesome' }}}} );
		var e = Tuli.toplevel.environment;
		Assert.isTrue( e.exists( 'always' ) );
		Assert.equals( 'awesome', e.get( 'always' ) );
		Assert.isFalse( e.exists( 'blahTuli' ) );
		Assert.isTrue( e.exists( 'everythingis' ) );
		Assert.equals( 'awesome', e.get( 'everythingis' ) );
	}
	
	public function testEnvironment_definesIfTrue() {
		var t = process( { define:['a'], env: { 'if': { 'a': { everythingis:'awesome' }}}} );
		var d = Tuli.toplevel.defines;
		var e = Tuli.toplevel.environment;
		Assert.isTrue( d.indexOf( 'a' ) > -1 );
		Assert.isTrue( e.exists( 'everythingis' ) );
		Assert.equals( 'awesome', e.get( 'everythingis' ) );
	}
	
	public function testEnvironment_definesIfFalse() {
		var t = process( { define:[], env: { 'if': { '!a': { everythingis:'awesome' }}}} );
		var d = Tuli.toplevel.defines;
		var e = Tuli.toplevel.environment;
		Assert.isTrue( d.length == 0 );
		Assert.isTrue( e.exists( 'everythingis' ) );
		Assert.equals( 'awesome', e.get( 'everythingis' ) );
	}
	
	public function testEnvironment_definesIfFail() {
		var t = process( { define:[], env: { 'if': { 'a': { everythingis:'awesome' }}}} );
		var d = Tuli.toplevel.defines;
		var e = Tuli.toplevel.environment;
		Assert.isTrue( d.length == 0 );
		Assert.isFalse( e.exists( 'everythingis' ) );
		Assert.isNull( e.get( 'everythingis' ) );
	}
	
	public function testIf_Or() {
		var t = process( { define:['b'], 'if': { 'a || b': { define:['c'] }} } );
		var d = Tuli.toplevel.defines;
		Assert.contains( 'b', d );
		Assert.contains( 'c', d );
	}
	
	public function testIf_And() {
		var t = process( { define:['a', 'b'], 'if': { 'a && b': { define:['c'] }}} );
		var d = Tuli.toplevel.defines;
		Assert.contains( 'a', d );
		Assert.contains( 'b', d );
		Assert.contains( 'c', d );
	}
	
	public function testIf_Equals() {
		var t = process( { env:{a:'b'}, 'if': { 'a == b': { define:['c'] }}} );
		var d = Tuli.toplevel.defines;
		var e = Tuli.toplevel.environment;
		Assert.isTrue( e.exists( 'a' ) );
		Assert.equals( 'b', e.get( 'a' ) );
		Assert.contains( 'c', d );
	}
	
	@:access(uhx.sys.Tuli)
	public function testStringSubstitution_simpleText() {
		var t:Tuli = process( { 'var':{ a:'B', b:'A', c:'C2C' } } );
		var s = t.substitution( "${b}-${c}-${a}" )( new EReg('', '') );
		Assert.equals( 'A-C2C-B', s );
	}*/
	
	@:access(uhx.sys.Tuli)
	public function testStringSubstitution_ereg() {
		var t:Tuli = process( { 'var':{ a:'B', b:'A', c:'C2C' } } );
		var e = new EReg( '([a-z]+)[0-9]*([a-z]+)', 'i' );
		var x = 'abc123cba';
		Assert.isTrue( e.match( x ) );
		var s = t.substitution( "$2_$1::$0", e )( e );
		Assert.equals( 'cba_abc::abc123cba', s );
	}
	
}
