package org.uqbar.project.wollok.tests.quickfix

import org.junit.Test
import org.uqbar.project.wollok.ui.Messages

class ConstructorsQuickFixTest extends AbstractWollokQuickFixTestCase {
	@Test
	def addOneConstructorsFromSuperclass(){
		val initial = #['''
			class MyClass{
				const y
				constructor(x){
					y = x
				}
				
				method someMethod(){
					return null
				}
			}
			
			object aWKO inherits MyClass {
			}
		''']

		val result = #['''
			class MyClass{
				const y
				constructor(x){
					y = x
				}
				
				method someMethod(){
					return null
				}
			}
			
			object aWKO inherits MyClass(x)  {
			}
		''']
		assertQuickfix(initial, result, Messages.WollokDslQuickFixProvider_add_constructors_superclass_name)
	}

	@Test
	def createConstructorInSuperclass(){
		val initial = #['''
			class MyClass{
			}
			
			class MySubclass inherits MyClass {
				const y
				
				constructor(x) = super(x) {
					y = x
				}
			}
		''']

		val result = #['''
			class MyClass{
				constructor(param1){
					//TODO: Autogenerated Code ! 
				}
			}
			
			class MySubclass inherits MyClass {
				const y
				
				constructor(x) = super(x) {
					y = x
				}
			}
		''']
		assertQuickfix(initial, result, Messages.WollokDslQuickFixProvider_create_constructor_superclass_name)
	}

	@Test
	def removeDuplicatedConstructor(){
		val initial = #['''
			class MyClass {
				const y
				
				constructor(x) {
					y = x
				}
				
				constructor(x) {
					y = x
				}
			}
		''']

		val result = #['''
			class MyClass {
				const y
				
				
				
				constructor(x) {
					y = x
				}
			}
		''']
		assertQuickfix(initial, result, Messages.WollokDslQuickFixProvider_remove_constructor_name, 2)
	}

}