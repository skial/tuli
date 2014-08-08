package uhx.tuli.plugins;

import uhx.sys.Tuli;
import uhx.tuli.util.File;

using Detox;

/**
 * ...
 * @author Skial Bainn
 */
class ResponsiveEmbed {
	
	public static function main() return ResponsiveEmbed;
	private var tuli:Tuli;
	private var config:Dynamic;

	public function new(t:Tuli, c:Dynamic) {
		tuli = t;
		config = c;
		tuli.onExtension('html', handler, After);
	}
	
	public function handler(file:File) {
		var dom = file.content.parse();
		var iframes = dom.find( 'iframe' );
		
		for (iframe in iframes) {
			for (attribute in iframe.attributes) {
				if (attribute.name == 'width' || attribute.name == 'height') {
					iframe.removeAttribute( attribute.name );
				}
				
				iframe.replaceWith( '<div class="embed-container">${iframe.html()}</div>'.parse() );
			}
		}
		
		file.content = dom.html();
	}
	
}