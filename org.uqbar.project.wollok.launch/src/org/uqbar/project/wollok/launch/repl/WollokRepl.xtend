package org.uqbar.project.wollok.launch.repl

import com.google.inject.Injector
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.util.LazyStringInputStream
import org.uqbar.project.wollok.interpreter.WollokInterpreter
import org.uqbar.project.wollok.launch.WollokLauncher
import org.uqbar.project.wollok.wollokDsl.WFile
import org.uqbar.project.wollok.WollokConstants

class WollokRepl {
	val Injector injector
	val WollokLauncher launcher
	val WollokInterpreter interpreter
	val File mainFile
	val reader = new BufferedReader(new InputStreamReader(System.in))
	val prompt = ">>> "

	new(WollokLauncher launcher, Injector injector, WollokInterpreter interpreter, File mainFile) {
		this.injector = injector
		this.launcher = launcher
		this.interpreter = interpreter
		this.mainFile = mainFile
	}

	def void startRepl() {
		var String input

		println("Wollok interactive console (type \"quit\" to quit): ")
		print(prompt)
		
		while ((input = readInput) != "quit") {
			executeInput(input)
			print(prompt)
		}
	}
	
	def String readInput(){
		val input = reader.readLine.trim
		if(input == ""){
			print(prompt)
			readInput
		}
		else
			if(input.endsWith(";")) 
				input + " " + readInput
			else input
	}
	
	def executeInput(String input){
			try {
				val returnValue = interpreter.interpret(
					'''
						program repl {
						«input»
						}
					'''.parseRepl(mainFile))
				if(returnValue != null)
					println(formatReturnValue(returnValue))
			} catch (ReplParserException e) {
				e.issues.forEach [
					println("" + severity.name + ":" + message + "(line:" + (lineNumber - 1) + ")")
				]
			}
	}
	
	def dispatch formatReturnValue(Object obj){
		obj?.toString
	}

	def dispatch formatReturnValue(String obj){
		'"' + obj +'"'
	}
	

	def parseRepl(CharSequence content, File mainFile) {
		val resourceSet = injector.getInstance(XtextResourceSet)
		val resource = resourceSet.createResource(uriToUse(resourceSet));
		val in = new LazyStringInputStream(content.toString)

		launcher.createClassPath(mainFile, resourceSet)

		resourceSet.getResources().add(resource);

		resource.load(in, #{});
		launcher.validate(injector, resource, [], [throw new ReplParserException(it)])
		resource.getContents().get(0) as WFile;
	}

	def uriToUse(ResourceSet resourceSet) {
		var name = "__synthetic";
		for (var i = 0; i < Integer.MAX_VALUE; i++) {
			var syntheticUri = URI.createURI(name + i + "." + WollokConstants.PROGRAM_EXTENSION);
			if (resourceSet.getResource(syntheticUri, false) == null)
				return syntheticUri;
		}
		throw new IllegalStateException();
	}

}
