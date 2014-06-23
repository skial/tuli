package uhx.tuli.util;

import uhx.tuli.util.File;

/**
 * ...
 * @author Skial Bainn
 */
class Spawn extends File {
	
	public var parent:String;

	public function new(path:String, parent:String) {
		super( path );
		
		this.parent = parent;
	}
	
}