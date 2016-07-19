package org.uqbar.project.wollok.server

import com.google.gson.Gson
import org.eclipse.jetty.client.HttpClient
import org.eclipse.jetty.client.util.StringContentProvider
import org.eclipse.jetty.http.HttpMethod
import org.eclipse.jetty.util.ssl.SslContextFactory
import org.junit.AfterClass
import org.junit.BeforeClass
import org.junit.Test
import org.uqbar.project.wollok.launch.WollokServerResponse

import static org.junit.Assert.*

class WollokServerTest {
	extension Gson = new Gson
	static var HttpClient httpClient
		
	@Test 
	def void testServerConsole() {
		'''
			object pepita {
			    var energia = 100
			    method energia() = energia
			}
			
			program prueba {
			    console.println(pepita.energia())
			}
		'''.sendAndValidate [
			assertEquals('100\n', consoleOutput)
		]
	}
	
	@Test
	def void testCompilationIssues() {		
		'''
			object pepita {
			    var energia = 100
			}
			
			program prueba {
			    console.println(pepita.energia())
			}			
		'''
		.sendAndValidate [
			assertEquals(2, compilation.issues.length)
			compilation.issues.get(0) => [
				assertEquals("WARNING", severity)
				assertEquals("WARNING_UNUSED_VARIABLE", code)
				assertEquals("Unused variable", message)
				assertEquals(2, lineNumber)
				assertEquals(24, offset)
				assertEquals(7, length)
			]
			compilation.issues.get(1) => [
				assertEquals("ERROR", severity)
				assertEquals("METHOD_ON_WKO_DOESNT_EXIST", code)
				assertEquals("Method does not exist in well-known object", message)
				assertEquals(6, lineNumber)
				assertEquals(85, offset)
				assertEquals(7, length)
			]
		]
	}

	@Test
	def void testRuntimeError() {		
		'''
			class Golondrina {}
			
			program prueba {
			    new Golondrina().volar()
			    console.println("Should not be printed")
			}			
		'''
		.sendAndValidate [ runtimeError => [ 
			// This assertions just follow current status of stack traces that should eventually evolve, 
			// you can change them if you are improving stack traces, but you should be careful to inform
			// the clients of wollok server, that might depend on this.
			
			assertEquals("a Golondrina[] does not understand volar()", message)
			assertEquals(2, stackTrace.size)
			stackTrace.get(0) => [
				assertEquals("wollok.lang.Object.messageNotUnderstood(name,parameters)", contextDescription)
				assertEquals("/lang.wlk:202", location)
			]			
			stackTrace.get(1) => [
				assertNull(contextDescription)
				assertEquals("__synthetic0.wpgm", location)
			]			
		]]
	}

	// ************************************************************************
	// ** Utilities
	// ************************************************************************

	@BeforeClass
	def static void initClient() {
		httpClient = new HttpClient(new SslContextFactory) => [
			followRedirects = false
			start
		]
	}

	@AfterClass
	def static void cleanup() {
		httpClient = null
	}

	def sendAndValidate(CharSequence program, (WollokServerResponse)=>void validation) {
		httpClient.newRequest("http://localhost:8080/run") => [
			method(HttpMethod.POST)
			accept("application/json")
			content(new StringContentProvider(program.toString), "application/json")
			
			send => [
				println(contentAsString)
				val content = contentAsString.fromJson(WollokServerResponse)
				content => validation
			]
		]
		
	}
}
