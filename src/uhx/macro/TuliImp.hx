package uhx.macro;

import haxe.macro.MacroStringTools;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import uhx.macro.KlasImp;
import uhx.sys.Tuli;

import std.*;
import haxe.*;

/**
 * ...
 * @author Skial Bainn
 */
class TuliImp {
	
	public static function setup():Void {
		
	}

	public static macro function initialize():Void {
		try {
			if (!KlasImp.setup) {
				KlasImp.initalize();
			}
			
			KlasImp.CLASS_META.set(':tuli', TuliImp.handler);
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `uhx.sys.Tuli.build()` method.
		}
	}
	
	public static function build():Array<Field> {
		return handler( Context.getLocalClass().get(), Context.getBuildFields() );
	}
	
	public static function handler(cls:ClassType, fields:Array<Field>) {
		var fil = function(f:Field, n:String) return f.name == n && f.access.indexOf(AStatic) > -1;
		var dir = fields.filter( fil.bind(_, 'input') )[0];
		var bin = fields.filter( fil.bind(_, 'output') )[0];
		var tuli = new Tuli();
		
		var pairs = [ { field:dir, set:function(v) tuli.source = v }, { field:bin, set:function(v) tuli.destination = v } ];
		
		for (item in pairs) if (item.field != null) switch (item.field.kind) {
			case FVar(_, e) if (e != null):
				switch (e.expr) {
					case EConst(CString(s)): item.set(s);
					case _:
				}
				
			case _:
				
		}
		
		tuli.build();
		
		return fields;
	}
	
}