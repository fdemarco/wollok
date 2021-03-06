package org.uqbar.project.wollok.tests.typesystem

import com.google.inject.Inject
import com.google.inject.Injector
import org.eclipse.emf.common.util.Diagnostic
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.junit4.validation.AssertableDiagnostics
import org.eclipse.xtext.junit4.validation.ValidatorTester
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.validation.AbstractValidationDiagnostic
import org.junit.Before
import org.junit.runners.Parameterized.Parameter
import org.uqbar.project.wollok.interpreter.WollokClassFinder
import org.uqbar.project.wollok.scoping.WollokResourceCache
import org.uqbar.project.wollok.tests.base.AbstractWollokParameterizedInterpreterTest
import org.uqbar.project.wollok.typesystem.ClassBasedWollokType
import org.uqbar.project.wollok.typesystem.NamedObjectWollokType
import org.uqbar.project.wollok.typesystem.TypeSystem
import org.uqbar.project.wollok.typesystem.WollokType
import org.uqbar.project.wollok.validation.ConfigurableDslValidator
import org.uqbar.project.wollok.validation.WollokDslValidator
import org.uqbar.project.wollok.wollokDsl.WClass
import org.uqbar.project.wollok.wollokDsl.WFile
import org.uqbar.project.wollok.wollokDsl.WMethodContainer
import org.uqbar.project.wollok.wollokDsl.WNamedObject

import static org.eclipse.xtext.validation.ValidationMessageAcceptor.INSIGNIFICANT_INDEX

import static extension org.uqbar.project.wollok.model.WMethodContainerExtensions.*
import static extension org.uqbar.project.wollok.model.WollokModelExtensions.*
import static extension org.uqbar.project.wollok.typesystem.TypeSystemUtils.*

/**
 * Abstract base class for all type system test cases.
 * Provides utility methods for parsing, type checking
 * and asserting program types.
 * 
 * @author jfernandes
 */
abstract class AbstractWollokTypeSystemTestCase extends AbstractWollokParameterizedInterpreterTest {
	@Parameter
	public Class<? extends TypeSystem> tsystemClass

	@Accessors
	extension TypeSystem tsystem

	@Inject
	WollokClassFinder finder

	@Inject
	WollokDslValidator _validator

	@Inject
	Injector injector

	ValidatorTester<WollokDslValidator> tester

	@Before
	def void setupTypeSystem() {
		WollokResourceCache.clearCache()

		tsystem = tsystemClass.newInstance
		injector.injectMembers(tsystem)
	}
	
	// Utility
	def parseAndInfer(CharSequence file) {
		parseAndInfer(#[file])
	}

	def parseAndInfer(CharSequence... files) {
		(files.map[parse(resourceSet)].clone => [
			forEach[validate]
			forEach[analyse]
			inferTypes
			reportErrors(validator)
		]).last
	}

	def asserting(WFile f, (WFile)=>void assertions) {
		assertions.apply(f)
	}

	def getValidator() {
		tester = new ValidatorTester(_validator, injector)

		// Ensure to call validator, otherwise calls to diagnose will fail.
		val _validator = tester.validator

		new ConfigurableDslValidator() {
			override report(String description, EObject invalidObject) {
				_validator.acceptError(description, invalidObject, null, INSIGNIFICANT_INDEX, null)
			}
		}
	}

	def getDiagnose() {
		tester.diagnose
	}

	// ************************************************************
	// ** Assertions
	// ************************************************************
	def classTypeFor(EObject context, String classFQN) {
		new ClassBasedWollokType(finder.getCachedClass(context, classFQN), tsystem)
	}
	
	def classType(String className) {
		new ClassBasedWollokType(WClass.find(className), null)
	}

	def objectType(String objectName) {
		// TODO Use always fully qualified names
		new NamedObjectWollokType(WNamedObject.find(objectName.split('\\.').last), null)
	}

	def assertTypeOf(EObject program, WollokType expectedType, String programToken) {
		assertEquals("Unmatched type for '" + programToken + "'", expectedType, program.findByText(programToken).type)
	}

	def assertTypeOfAsString(EObject program, String expectedType, String token) {
		assertEquals("Unmatched type for '" + token + "'", expectedType, program.findByText(token).type.name)
	}

	def assertConstructorType(EObject program, String className, String paramsSignature) {
		val nrOfParams = paramsSignature.split(',').length;
		assertEquals(paramsSignature,
			"(" + findConstructor(className, nrOfParams).parameters.map[type?.name].join(", ") + ")")
	}

	def assertMethodSignature(EObject program, String expectedSignature, String methodFQN) {
		assertEquals(expectedSignature, findMethod(methodFQN).functionType(tsystem))
	}

	def assertInstanceVarType(EObject program, WollokType expectedType, String instVarFQN) {
		assertEquals(expectedType, findInstanceVar(instVarFQN).type)
	}

	def noIssues(EObject program) {
		// Do not call diagnose twice!
		diagnose => [
			try
				assertOK
			catch (AssertionError e) {
				fail('''
					«e.message»
					«it»
				''')

			}
		]
	}

	def assertIssues(EObject program, String programToken, String... expectedIssues) {
		val element = program.findByText(programToken)
		assertIssuesInElement(element, expectedIssues)
	}

	def assertIssuesInElement(EObject element, String... expectedIssues) {
		val expectedDiagnostics = expectedIssues.map [ message |
			new AssertableDiagnostics.Pred(null, null, null, message) {
				override apply(Diagnostic d) {
					super.apply(d) && (d as AbstractValidationDiagnostic).sourceEObject == element
				}
			}
		]
		diagnose.assertAll(expectedDiagnostics)
	}

	// FINDS
	def static findByText(EObject model, String token) {
		val found = NodeModelUtils.findActualNodeFor(model).asTreeIterable //
		.findFirst [ n |
			escapeNodeTextToCompare(n.text.trim) == token && n.hasDirectSemanticElement
		]
		assertNotNull("Could NOT find program token '" + token + "'", found)
		found.semanticElement
	}

	def static findAllByText(EObject model, String token, Class<? extends EObject> semanticElementType) {
		NodeModelUtils.findActualNodeFor(model).asTreeIterable //
		.filter [ n |
			escapeNodeTextToCompare(n.text.trim) == token && n.hasDirectSemanticElement &&
				semanticElementType.isAssignableFrom(n.semanticElement.class)
		] //
		.map[semanticElement] //
		.toList
	}

	def static findByText(EObject model, String token, Class<? extends EObject> semanticElementType) {
		val found = findAllByText(model, token, semanticElementType)
		if (found.empty) fail("Could NOT find program token '" + token + "'")
		return found.get(0)
	}

	def static findAllByText(EObject model, String token) {
		NodeModelUtils.findActualNodeFor(model).asTreeIterable //
		.filter [ n |
			escapeNodeTextToCompare(n.text.trim) == token && n.hasDirectSemanticElement
		] //
		.map[semanticElement]
	}

	def static String escapeNodeTextToCompare(String nodeText) {
		if (nodeText.startsWith(System.lineSeparator))
			nodeText.substring(1).escapeNodeTextToCompare
		else if (nodeText.startsWith("\t"))
			nodeText.substring(1).escapeNodeTextToCompare
		else
			nodeText
	}

	def findConstructor(String className, int nrOfParams) {
		WClass.find(className).constructors.findFirst[matches(nrOfParams)]
	}

	def findMethod(String methodFQN) {
		val fqn = methodFQN.split('\\.')
		val m = WMethodContainer.find(fqn.get(0)).methods.findFirst[name == fqn.get(1)]
		if (m === null)
			throw new RuntimeException("Could NOT find method " + methodFQN)
		m
	}

	def findInstanceVar(String instVarFQN) {
		val fqn = instVarFQN.split('\\.')
		WClass.find(fqn.get(0)).variableDeclarations.map[variable].findFirst[name == fqn.get(1)]
	}

	def <T extends EObject> find(Class<T> resourceType, String resourceName) {
		val resources = resourceSet.allContents.filter(resourceType).toList
		resources.findFirst[it.name == resourceName] => [
			if (it === null)
				throw new RuntimeException(
					'''Could NOT find «resourceType.simpleName» [«resourceName»] in: «resources.map[it.name].toList»''')
		]
	}
}
