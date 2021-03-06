package org.uqbar.project.wollok.ui.quickfix

import com.google.inject.Inject
import java.util.List
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.ui.editor.model.IXtextDocument
import org.eclipse.xtext.ui.editor.model.edit.IModificationContext
import org.eclipse.xtext.ui.editor.quickfix.DefaultQuickfixProvider
import org.eclipse.xtext.ui.editor.quickfix.Fix
import org.eclipse.xtext.ui.editor.quickfix.IssueResolutionAcceptor
import org.eclipse.xtext.util.concurrent.IUnitOfWork
import org.eclipse.xtext.validation.Issue
import org.uqbar.project.wollok.interpreter.WollokClassFinder
import org.uqbar.project.wollok.ui.Messages
import org.uqbar.project.wollok.validation.WollokDslValidator
import org.uqbar.project.wollok.wollokDsl.WAssignment
import org.uqbar.project.wollok.wollokDsl.WBlockExpression
import org.uqbar.project.wollok.wollokDsl.WClass
import org.uqbar.project.wollok.wollokDsl.WConstructor
import org.uqbar.project.wollok.wollokDsl.WExpression
import org.uqbar.project.wollok.wollokDsl.WIfExpression
import org.uqbar.project.wollok.wollokDsl.WMemberFeatureCall
import org.uqbar.project.wollok.wollokDsl.WMethodContainer
import org.uqbar.project.wollok.wollokDsl.WMethodDeclaration
import org.uqbar.project.wollok.wollokDsl.WNamedObject
import org.uqbar.project.wollok.wollokDsl.WVariableDeclaration
import org.uqbar.project.wollok.wollokDsl.WVariableReference
import org.uqbar.project.wollok.wollokDsl.WollokDslFactory
import org.uqbar.project.wollok.wollokDsl.WollokDslPackage

import static org.uqbar.project.wollok.WollokConstants.*
import static org.uqbar.project.wollok.validation.WollokDslValidator.*

import static extension org.uqbar.project.wollok.model.WMethodContainerExtensions.*
import static extension org.uqbar.project.wollok.model.WollokModelExtensions.*
import static extension org.uqbar.project.wollok.ui.quickfix.QuickFixUtils.*
import static extension org.uqbar.project.wollok.utils.XTextExtensions.*

/**
 * Custom quickfixes.
 * see https://eclipse.org/Xtext/documentation/310_eclipse_support.html#quick-fixes
 * 
 * @author jfernandes
 * @author tesonep
 * @author dodain
 */
class WollokDslQuickfixProvider extends DefaultQuickfixProvider {
	val tabChar = "\t"
	val blankSpace = " "

	@Inject
	WollokClassFinder classFinder

	/** 
	 * ***********************************************************************
	 * 					     Capitalization & Lowercase
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.CLASS_NAME_MUST_START_UPPERCASE)
	def capitalizeName(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_capitalize_name,
			Messages.WollokDslQuickfixProvider_capitalize_description, null) [ e, it |
			val firstLetter = xtextDocument.get(issue.offset, 1)
			applyRefactor(e, it.xtextDocument, issue, firstLetter.toUpperCase)
		]
	}
	
	@Fix(WollokDslValidator.PARAMETER_NAME_MUST_START_LOWERCASE)
	def toLowerCaseParameterName(Issue issue, IssueResolutionAcceptor acceptor) {
		toLowerCaseReferenciableName(issue, acceptor)
	}

	@Fix(WollokDslValidator.OBJECT_NAME_MUST_START_LOWERCASE)
	def toLowerCaseObjectName(Issue issue, IssueResolutionAcceptor acceptor) {
		toLowerCaseReferenciableName(issue, acceptor)
	}

	@Fix(WollokDslValidator.VARIABLE_NAME_MUST_START_LOWERCASE)
	def toLowerCaseVariableName(Issue issue, IssueResolutionAcceptor acceptor) {
		toLowerCaseReferenciableName(issue, acceptor)
	}

	@Fix(WollokDslValidator.REFERENCIABLE_NAME_MUST_START_LOWERCASE)
	def toLowerCaseReferenciableName(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_lowercase_name,
			Messages.WollokDslQuickfixProvider_lowercase_description, null) [ e, it |
			val firstLetter = xtextDocument.get(issue.offset, 1)
			applyRefactor(e, it.xtextDocument, issue, firstLetter.toLowerCase)
		]
	}

	/** 
	 * ***********************************************************************
	 * 							Constructors
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.REQUIRED_SUPERCLASS_CONSTRUCTOR)
	def addConstructorsFromSuperclass(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_constructors_superclass_name,
			Messages.WollokDslQuickFixProvider_add_constructors_superclass_description, null) [ e, it |
			val _object = e as WNamedObject
			val firstConstructor = _object.parent.constructors.map['''(«parameters.map[name].join(',')») '''].head
			xtextDocument.replace(issue.offset + issue.length, 0, firstConstructor)
		]
	}

	@Fix(CONSTRUCTOR_IN_SUPER_DOESNT_EXIST)
	def createConstructorInSuperClass(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_create_constructor_superclass_name,
			Messages.WollokDslQuickFixProvider_create_constructor_superclass_description, null) [ e, it |
			val delegatingConstructor = (e as WConstructor).delegatingConstructorCall
			val parent = e.wollokClass.parent

			val constructor = '''
				«tabChar»constructor(«(1..delegatingConstructor.arguments.size).map["param" + it].join(",")»){
				«tabChar»«tabChar»//TODO: «Messages.WollokDslQuickfixProvider_createMethod_stub»
				«tabChar»}
			'''

			addMethod(parent, constructor)
		]
	}

	@Fix(DUPLICATED_CONSTRUCTOR)
	def deleteDuplicatedConstructor(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_constructor_name,
			Messages.WollokDslQuickFixProvider_remove_constructor_description, null) [ e, it |
			xtextDocument.delete(e)
		]
	}

	@Fix(UNNECESARY_OVERRIDE)
	def deleteUnnecesaryOverride(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_method_name,
			Messages.WollokDslQuickFixProvider_remove_method_description, null) [ e, it |
			xtextDocument.delete(e)
		]
	}

	@Fix(MUST_CALL_SUPER)
	def addCallToSuperInConstructor(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_call_super_name,
			Messages.WollokDslQuickFixProvider_add_call_super_description, null) [ e, it |
			val const = e as WConstructor
			val call = " = super()" // this could be more involved here and useful for the user :P
			val paramCloseOffset = const.node.text.indexOf(")")
			xtextDocument.replace(e.before + paramCloseOffset - 1, 0, call)
		]
	}

	/** 
	 * ***********************************************************************
	 * 							Getters
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.GETTER_METHOD_SHOULD_RETURN_VALUE)
	def addReturnVariable(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_return_variable_name,
			Messages.WollokDslQuickfixProvider_return_variable_description, null) [ e, context |
			val method = e as WMethodDeclaration
			if (!method.expressionReturns) {
				val body = method.expression as WBlockExpression
				if (body.expressions.empty) {
					context.xtextDocument.replaceWith(body,
						"{" + System.lineSeparator + "\t\t" + RETURN + " " + method.name + System.lineSeparator + "\t}")
				} else
					context.insertAfter(body.expressions.last, RETURN + " " + method.name)
			}
		]
	}

	@Fix(GETTER_METHOD_SHOULD_RETURN_VALUE)
	def prependReturnForGetter(Issue issue, IssueResolutionAcceptor acceptor) {
		prependReturn(issue, acceptor)
	}

	@Fix(RETURN_FORGOTTEN)
	def prependReturn(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_return_last_expression_name,
			Messages.WollokDslQuickfixProvider_return_last_expression_description, null) [ e, it |
			val method = e as WMethodDeclaration
			val body = (method.expression as WBlockExpression)
			if (!body.expressions.empty)
				insertJustBefore(body.expressions.last, RETURN + " ")
		]
	}

	/** 
	 * ***********************************************************************
	 * 							Unexistent methods
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.METHOD_ON_WKO_DOESNT_EXIST)
	def createNonExistingMethodOnWKO(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_createMethod_name,
			Messages.WollokDslQuickfixProvider_createMethod_description, null) [ e, context |
			val call = e as WMemberFeatureCall
			val container = call.resolveWKO(classFinder)
			createMethodInContainer(context, call, container)
		]
	}
	
	@Fix(WollokDslValidator.METHOD_ON_THIS_DOESNT_EXIST)
	def createNonExistingMethodOnSelf(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_createMethod_name,
			Messages.WollokDslQuickfixProvider_createMethod_description, null) [ e, context |
			val call = e as WMemberFeatureCall
			val container = call.method.eContainer as WMethodContainer
			createMethodInContainer(context, call, container)
		]
	}
	
	/** 
	 * ***********************************************************************
	 * 						  	Common Quick Fix tests
	 * ***********************************************************************
	 */

	@Fix(WollokDslValidator.CANNOT_ASSIGN_TO_VAL)
	def changeDeclarationToVar(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_changeToVar_name,
			Messages.WollokDslQuickfixProvider_changeToVar_description, null) [ e, context |
			val f = (e as WAssignment).feature.ref.eContainer
			if (f instanceof WVariableDeclaration) {
				val feature = f as WVariableDeclaration
				context.xtextDocument.replace(feature.before, feature.node.length,
					VAR + " " + feature.variable.name + " =" + feature.right.node.text)
			}
		]
	}

	@Fix(BAD_USAGE_OF_IF_AS_BOOLEAN_EXPRESSION)
	def wrongUsageOfIfForBooleanExpressions(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_replace_if_condition_name,
			Messages.WollokDslQuickFixProvider_replace_if_condition_description, null) [ e, it |
			val ifE = e as WIfExpression
			var inlineResult = if (ifE.then.isReturnTrue)
					ifE.condition.sourceCode
				else
					("!(" + ifE.condition.sourceCode + ")")
			if (ifE.then.hasReturnWithValue) {
				inlineResult = RETURN + " " + inlineResult
			}
			xtextDocument.replaceWith(e, inlineResult)
		]
	}

	/** 
	 * ***********************************************************************
	 * 						  	Overriding methods
	 * ***********************************************************************
	 */

	@Fix(WollokDslValidator.METHOD_MUST_HAVE_OVERRIDE_KEYWORD)
	def changeDefToOverride(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_add_override_name,
			Messages.WollokDslQuickfixProvider_add_override_description, null) [ e, it |
			xtextDocument.prepend(e, OVERRIDE + ' ')
		]
	}

	@Fix(CANT_OVERRIDE_FROM_BASE_CLASS)
	def removeOverrideKeywordFromBaseClass(Issue issue, IssueResolutionAcceptor acceptor) {
		removeOverrideKeyword(issue, acceptor)
	}

	@Fix(METHOD_DOESNT_OVERRIDE_ANYTHING)
	def addMethodToSuperClass(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_create_method_superclass_name,
			Messages.WollokDslQuickfixProvider_create_method_superclass_description, null) [ e, it |
			val method = e as WMethodDeclaration
			val container = method.eContainer as WMethodContainer
			addMethod(container.parent, defaultStubMethod(container.parent, method))
		]
	}

	@Fix(METHOD_DOESNT_OVERRIDE_ANYTHING)
	def removeOverrideKeyword(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_override_keyword_name,
			Messages.WollokDslQuickFixProvider_remove_override_keyword_description, null) [ e, it |
			xtextDocument.deleteToken(e, OVERRIDE + blankSpace)
		]
	}

	@Fix(NATIVE_METHOD_CANNOT_OVERRIDES)
	def removeOverrideFromNativeMethod(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_override_keyword_name,
			Messages.WollokDslQuickFixProvider_remove_override_keyword_description, null) [ e, it |
			xtextDocument.deleteToken(e, OVERRIDE)
		]
	}

	/** 
	 * ***********************************************************************
	 * 							Unused or duplicated abstractions
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.WARNING_UNUSED_VARIABLE)
	def removeUnusedVariable(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_unused_variable_name,
			Messages.WollokDslQuickFixProvider_remove_unused_variable_description, null) [ e, it |
			xtextDocument.delete(e)
		]
	}

	@Fix(WollokDslValidator.WARNING_UNUSED_PARAMETER)
	def removeUnusedParameter(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_unused_parameter_name,
			Messages.WollokDslQuickFixProvider_remove_unused_parameter_description, null) [ e, it |
			xtextDocument.delete(e)
		]
	}
	
	@Fix(DUPLICATED_METHOD)
	def removeDuplicatedMethod(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_method_name,
			Messages.WollokDslQuickFixProvider_remove_method_description, null) [ e, it |
			xtextDocument.delete(e)
		]
	}

	@Fix(VARIABLE_NEVER_ASSIGNED)
	def initializeNonAssignedVariable(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_initialize_value_name,
			Messages.WollokDslQuickFixProvider_initialize_value_description, null) [ e, it |
			xtextDocument.append(e, " = value")
		]
	}

	/** 
	 * ***********************************************************************
	 * 							Try / catch block
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.ERROR_TRY_WITHOUT_CATCH_OR_ALWAYS)
	def addCatchOrAlwaysToTry(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_catch_name,
			Messages.WollokDslQuickFixProvider_add_catch_description, null) [ e, context |
			context.insertAfter(
				e,
				'''
				catch e : wollok.lang.Exception {
					// TODO: «Messages.WollokDslQuickfixProvider_createMethod_stub»
					throw e
				}'''
			)
		]

		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_always_name,
			Messages.WollokDslQuickFixProvider_add_always_name, null) [ e, context |
			context.insertAfter(
				e,
				'''
				then always {
					//TODO: «Messages.WollokDslQuickfixProvider_createMethod_stub»
				}'''
			)
		]
	}

	// ************************************************
	// ** unresolved ref to "elements" quick fixes
	// ************************************************
	protected def quickFixForUnresolvedRefToVariable(IssueResolutionAcceptor issueResolutionAcceptor, Issue issue,
		IXtextDocument xtextDocument, EObject target) {
		// issue #452 - contextual menu based on different targets
		val targetContext = target.declaringContext // target.getSelfContext
		val hasMethodContainer = targetContext !== null
		val hasParameters = target.declaringMethod !== null && target.declaringMethod.parameters !== null
		val canCreateLocalVariable = target.canCreateLocalVariable

		// create local var
		if (canCreateLocalVariable) {
			issueResolutionAcceptor.accept(issue, Messages.WollokDslQuickFixProvider_create_local_variable_name,
				Messages.WollokDslQuickFixProvider_create_local_variable_description, "variable.gif") [ e, context |
				val newVarName = xtextDocument.get(issue.offset, issue.length)
				val firstExpressionInContext = e.firstExpressionInContext
				context.insertBefore(firstExpressionInContext, VAR + " " + newVarName)
			]
		}

		// create instance var
		if (hasMethodContainer) {
			issueResolutionAcceptor.accept(issue, Messages.WollokDslQuickFixProvider_create_instance_variable_name,
				Messages.WollokDslQuickFixProvider_create_instance_variable_description, "variable.gif") [ e, context |
				val newVarName = xtextDocument.get(issue.offset, issue.length)
				val declaringContext = e.declaringContext
				val firstClassChild = declaringContext.eContents.head
				context.insertBefore(firstClassChild, VAR + " " + newVarName)
			]
		}

		// create parameter
		if (hasParameters) {
			issueResolutionAcceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_parameter_method_name,
				Messages.WollokDslQuickFixProvider_add_parameter_method_description, "variable.gif") [ e, context |
				val newVarName = xtextDocument.get(issue.offset, issue.length)
				val method = (e as WExpression).method
				method.parameters += (WollokDslFactory.eINSTANCE.createWParameter => [name = newVarName])
			]
		}
	}

	protected def quickFixForUnresolvedRefToClass(IssueResolutionAcceptor issueResolutionAcceptor, Issue issue,
		IXtextDocument xtextDocument) {
		issueResolutionAcceptor.accept(issue, Messages.WollokDslQuickFixProvider_create_new_class_name,
			Messages.WollokDslQuickFixProvider_create_new_class_description, "class.png") [ e, context |
			val newClassName = xtextDocument.get(issue.offset, issue.length)
			val container = e.container
			context.xtextDocument.replace(container.before, 0,
				CLASS + blankSpace + newClassName + " {" + System.lineSeparator + System.lineSeparator + "}" + System.lineSeparator + System.lineSeparator)
		]

	}

	// *********************************************
	// ** Unresolved references code (should be generalized into something using reflection as xtext's declarative quickfixes)
	// **   this needs some overriding since xtext doesn't have an extension point or declarative way
	// **   to get in between (they already provide a quick fix to change the reference to some other similar variable name)
	// *********************************************
	override createLinkingIssueResolutions(Issue issue, IssueResolutionAcceptor issueResolutionAcceptor) {
		super.createLinkingIssueResolutions(issue, issueResolutionAcceptor)

		// adding "create for unresolved references"		
		val modificationContext = modificationContextFactory.createModificationContext(issue)
		val xtextDocument = modificationContext.xtextDocument
		if (xtextDocument === null)
			return;
		xtextDocument.readOnly(new IUnitOfWork.Void<XtextResource>() {
			override process(XtextResource state) throws Exception {
				val target = state.getEObject(issue.uriToProblem.fragment)
				val reference = getUnresolvedEReference(issue, target)
				if (reference === null)
					return;
				quickFixUnresolvedRef(target, reference, issueResolutionAcceptor, issue, xtextDocument)
			}
		})
	}

	protected def quickFixUnresolvedRef(EObject target, EReference reference,
		IssueResolutionAcceptor issueResolutionAcceptor, Issue issue, IXtextDocument xtextDocument) {
		if (target instanceof WVariableReference && reference.EType == WollokDslPackage.Literals.WREFERENCIABLE &&
			reference.name == "ref") {
			quickFixForUnresolvedRefToVariable(issueResolutionAcceptor, issue, xtextDocument, target)
		} else if (reference.EType == WollokDslPackage.Literals.WCLASS) {
			quickFixForUnresolvedRefToClass(issueResolutionAcceptor, issue, xtextDocument)
		}
	}

	/**
	 * **************************************************************************************
	 *                         Internal common methods
	 * **************************************************************************************
	 */
	def defaultStubMethod(WMemberFeatureCall call, int numberOfTabsMargin) {
		val callText = call.node.text
		val margin = (1..numberOfTabsMargin).map [ tabChar ].reduce [ acum, tab | acum + tab ] 
		System.lineSeparator + margin + METHOD + " " + call.feature +
					callText.substring(callText.indexOf('('), callText.lastIndexOf(')') + 1) + " {" +
					System.lineSeparator + margin + tabChar + "//TODO: " + Messages.WollokDslQuickfixProvider_createMethod_stub +
					System.lineSeparator + margin + "}"
	}
	
	def defaultStubMethod(WClass clazz, WMethodDeclaration method) {
		val margin = adjustMargin(clazz)
		'''
		«margin»«METHOD» «method.name»(«method.parameters.map[name].join(",")») {
		«margin»	//TODO: «Messages.WollokDslQuickfixProvider_createMethod_stub»
		«margin»}''' + System.lineSeparator
	}

	def adjustMargin(WClass clazz) {
		if(clazz.methods.empty) tabChar else ""
	}

	def resolveXtextDocumentFor(Issue issue) {
		modificationContextFactory.createModificationContext(issue).xtextDocument
	}

	protected def addMethod(IModificationContext it, WClass parent, String code) {
		val newContext = getContainerContext(it, parent)

		val lastConstructor = parent.members.findLast[it instanceof WConstructor]
		if (lastConstructor !== null)
			newContext.insertAfter(lastConstructor, code)
		else {
			val lastVar = parent.members.findLast[it instanceof WVariableDeclaration]
			if (lastVar !== null)
				newContext.insertAfter(lastVar, code)
			else {
				val firstMethod = parent.members.findFirst[it instanceof WMethodDeclaration]
				if (firstMethod !== null) {
					newContext.insertBefore(firstMethod, code)
				} else {
					newContext.xtextDocument.replace(parent.after - 1, 0, code)
				}
			}
		}
	}

	def getContainerContext(IModificationContext it, WClass parent) {
		new IModificationContext() {

			override getXtextDocument() {
				it.getXtextDocument(parent.fileURI)
			}

			override getXtextDocument(URI uri) {
				it.getXtextDocument(uri)
			}

		}
	}

	def int findPlaceToAddMethod(WMethodContainer it) {
		val lastMethod = members.lastOf(WMethodDeclaration)
		if (lastMethod !== null) 
			return lastMethod.after
		val lastConstructor = members.lastOf(WConstructor)
		if (lastConstructor !== null)
			return lastConstructor.after
		val lastInstVar = members.lastOf(WVariableDeclaration)
		if (lastInstVar !== null)
			return lastInstVar.after

		return it.node.offset + it.node.text.indexOf("{") + 1
	}

	def <T> T lastOf(List<?> l, Class<T> type) { l.findLast[type.isInstance(it)] as T }

	def lowerCaseName(String name) {
		name.substring(0, 1).toLowerCase + name.substring(1, name.length)
	}

	def upperCaseName(String name) {
		name.substring(0, 1).toUpperCase + name.substring(1, name.length)
	}

	/**
	 * author dodain
	 * 
	 * Originally, only changed eObject name, but not its references
	 * 
	 * Then, I found we could fire a refactor rename like in UI mode
	 * val rename = renameSupportFactory.create(xtextDocument.renameElementContext(e), e.name.lowerCaseName)
	 * rename.startDirectRefactoring
	 * 	def renameElementContext(IXtextDocument xtextDocument, EObject e) {
	 * 		xtextDocument.modify(new IUnitOfWork<IRenameElementContext, XtextResource>() {
	 * 			override def IRenameElementContext exec(XtextResource state) {
	 * 				renameContextFactory.createRenameElementContext(e, EditorUtils.activeXtextEditor, null, state)
	 * 			}
	 * 		})
	 * 	}
	 * 
	 * but I could not test it.
	 * 
	 * So, finally I implemented my own refactor thing, knowing that name is correct and I don't have
	 * to reconcile xtext document. So I search the main document for nodes named like eObject, 
	 * filtering only certain definitions (eg: if you rename a variable Energia from energia,
	 * method declarations and calls remain the same.
	 * 
	 * @See https://www.eclipse.org/forums/index.php/t/485483/ 	 
	 */
	protected def void applyRefactor(EObject eObject, IXtextDocument xtextDocument, Issue issue, String newText) {
		val rootNode = eObject.node.rootNode
		xtextDocument.replace(issue.offset.intValue, 1, newText)
		for (INode node : rootNode.leafNodes) {
			if (eObject.applyRenameTo(node)) {
				xtextDocument => [
					replace(node.offset, 1, newText)
				]
			}
		}
		
		/** Extending to related files of project
		 * @See https://kthoms.wordpress.com/2011/07/12/xtend-generating-from-multiple-input-models/
		 */
		// TODO: import static extension WEclipseUtils
		// eObject.getFile.refreshProject but also do a full refresh of this rename in whole project
	}

	/**
	 * Common method for wko, objects, mixins and classes to create a non-existent method based on a call
	 */
	def createMethodInContainer(IModificationContext context, WMemberFeatureCall call, WMethodContainer container) {
		val placeToAdd = container.findPlaceToAddMethod
		val xtextDocument = context.getXtextDocument(container.fileURI)
		xtextDocument.replace(
			placeToAdd,
			0,
			defaultStubMethod(call, xtextDocument.computeMarginFor(placeToAdd, container))
		)
	}

	/**
	 * Common method - compute margin that should by applied to a new method
	 * If method container has no methods nor variable declarations, placeToAdd should not be considered
	 * Otherwise we use default margin based on line we are calling
	 */
	def int computeMarginFor(IXtextDocument document, int placeToAdd, WMethodContainer container) {
		if (container.methods.empty) {
			return 1
		}
		val lineInformation = document.getLineInformationOfOffset(placeToAdd)
		var textLine = document.get(lineInformation.offset, lineInformation.length)
		var margin = 0
		while (textLine.startsWith("\t")) {
			margin++
			textLine = textLine.substring(1)
		}
		margin
	}

}
