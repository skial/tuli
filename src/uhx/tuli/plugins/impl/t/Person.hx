package uhx.tuli.plugins.impl.t;

import uhx.tuli.plugins.impl.a.ContactType;
import uhx.tuli.plugins.impl.a.ProfileType;

/**
 * @author Skial Bainn
 */
typedef Person = {
	var name:Details;
	var avatar:String,
	var contacts:Array<Pair<ContactType, String>>,
	var profiles:Array<Pair<ProfileType, String>>,
}

typedef Details = {
	var user:String;
	var full:String;
	var first:String;
	var last:String;
}

typedef Pair<A,B> = {
	var type:A;
	var value:B;
}