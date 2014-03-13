package uhx.sys;

import haxe.io.Path;
import byte.ByteData;
import haxe.ds.StringMap;
import haxe.Json;
import sys.io.File;
import sys.io.Process;
import uhx.lexer.HttpMessageParser;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * -----
 * requires:
 *  -	lib detox
 *  -	lib selecthxml
 *  -	the program `tidyhtml` in `path`
 * -----
 * Import html fragment's by using inside your `<head>` -
 * 	`<link rel="import" href="local/path/to/fragment.html">`
 * This also work's -
 * 	`<link rel="import" href="http://raw.github.com/user/repo/master/fragment.html">`
 * Which mean's you can share template's, widget's, or entire app's.
 * -----
 * This part is not standard HTML5 WebComponent's, just stolen/similar...
 * To reference where the imported content should be put, use -
 * 	`<content select=".class"></content>`
 * The css selector should be a simple selector, or what the spec's call
 * a compound selector. http://www.w3.org/TR/selectors4/#simple
 * 
 * The `<content>` tag and anything inside will be replaced. If nothing match's
 * the `select` attribute of a `<content>` tag, then it will be removed.
 * -----
 */

/**
 * ...
 * @author Skial Bainn
 * Swahili for `static`
 */
class Tuli {
	
	private static var htmlCache:StringMap<DOMCollection> = new StringMap();
	private static var isPartial:StringMap<Bool> = new StringMap();
	
	private static var staticCache:StringMap<DOMCollection> = new StringMap();
	
	public var source:String;
	public var destination:String;
	
	public function new() {
		
	}
	
	public function build() {
		if (source == null) source = Sys.getCwd();
		if (destination == null) destination = source.addTrailingSlash() + '../bin/';
		
		source = source.addTrailingSlash().normalize();
		destination = destination.addTrailingSlash().normalize();
		
		var items = source.readDirectory();
		var htmls = items.filter( function(s) return s.extension() == 'html' );
		
		// Load and convert to xml.
		for (html in htmls) {
			
			var path = (source + html).normalize();
			var name = html.withoutExtension();
			var content = File.getContent( path );
			
			// https://developer.mozilla.org/en-US/docs/Web/HTML/Element
			// Use tidy html5 to force the html into valid xml so Detox
			// on sys platforms can parse it.
			var process = new Process('tidy', 
				[
				// Indent elements.
				'-i', 
				// Be quiet.
				'-q', 
				// Convert to xml.
				'-asxml', 
				// Force the doctype to valid html5
				'--doctype', 'html5',
				// Don't add the tidy html5 meta
				'--tidy-mark', 'n',
				// Keep empty elements and paragraphs.
				'--drop-empty-elements', 'n',
				'--drop-empty-paras', 'n', 
				// Add missing block elements.
				'--new-blocklevel-tags', 
				'article aside audio canvas datalist figcaption figure footer ' +
				'header hgroup output section video details element main menu ' +
				'template shadow nav ruby source',
				// Add missing inline elements.
				'--new-inline-tags', 'bdi content data mark menuitem meter progress rp' +
				'rt summary time',
				// Add missing void elements.
				'--new-empty-tags', 'keygen track wbr',
				// Don't wrap partials in `<html>`, or `<body>` and don't add `<head>`.
				'--show-body-only', 'auto', 
				// Make the converted html easier to read.
				'--vertical-space', 'y', path]);
			
			var out = process.stdout.readAll().toString();
			var err = process.stderr.readAll().toString();
			process.close();
			
			var parsed = out.parse();
			
			htmlCache.set(name, parsed);
			if (parsed.first().html().toLowerCase() != '<!doctype html>' ) {
				isPartial.set(name, true);
			}
			
		}
		
		// Start processing templates.
		for (html in htmls) {
			
			var name = html.withoutExtension();
			
			if (!isPartial.exists( name )) {
				
				// Grab the html collection.
				var dom = htmlCache.get( name );
				// Find all `<link rel="import" href="name.html" />`
				var imports = dom.find('link[rel="import"]');
				var partials = new StringMap<DOMCollection>();
				
				// Then grab the href value without html extension.
				for (i in imports) {
					var name = i.attr('href').withoutExtension();
					
					if (isPartial.exists( name ) && htmlCache.exists( name )) {
						// And add it to the html collections available partials list.
						partials.set( name, htmlCache.get( name ) );
					}
					
					// Remove the `<link />`.
					i.removeFromDOM();
				}
				
				// Find all insertion points `<content select="import"></content>`.
				var contents = dom.find('content[select]');
				
				// For each `<content select="name"></content>` grab the name.
				for (c in contents) {
					var name = c.attr('select');
					
					if (partials.exists( name )) {
						// Replace the current `<content></content>` with the matched partial dom contents.
						c.replaceWith( partials.get( name ) );
					} else {
						// Remove any remaining `<content></content>` that didn't match.
						c.removeFromDOM();
					}
					
				}
				
				trace( dom.html() );
				
			}
			
		}
		
	}
	
}