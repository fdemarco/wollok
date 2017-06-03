package org.uqbar.project.wollok.typesystem.constraints

import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.uqbar.project.wollok.typesystem.WollokType
import static extension org.uqbar.project.wollok.typesystem.constraints.WollokModelPrintForDebug.debugInfo

class TypeVariablesRegistry {
	val Map<EObject, TypeVariable> typeVariables = newHashMap

	ConstraintBasedTypeSystem typeSystem

	new(ConstraintBasedTypeSystem typeSystem) {
		this.typeSystem = typeSystem
	}

	// ************************************************************************
	// ** Creating type variables.
	// ************************************************************************
	def newTypeVariable(EObject obj) {
		new TypeVariable(obj) => [typeVariables.put(obj, it)]
	}

	def newWithSubtype(EObject it, EObject... subtypes) {
		newTypeVariable => [subtypes.forEach[subtype|it.beSupertypeOf(subtype.tvar)]]
	}

	def newWithSupertype(EObject it, EObject... supertypes) {
		newTypeVariable => [supertypes.forEach[supertype|it.beSubtypeOf(supertype.tvar)]]
	}

	def newSealed(EObject it, WollokType type) {
		newTypeVariable
		beSealed(type)
	}

	def beSealed(EObject it, WollokType type) {
		tvar => [
			addMinimalType(type)
			beSealed
		]
	}

	def newVoid(EObject it) {
		newSealed(WollokType.WVoid)
	}

	// ************************************************************************
	// ** Retrieve type variables
	// ************************************************************************
	def allVariables() {
		typeVariables.values
	}

	def TypeVariable tvar(EObject obj) {
		typeVariables.get(obj) => [ typeVar |
			if (typeVar == null)
				throw new RuntimeException("I don't have type information for " + obj.debugInfo)
		]
	}

	// ************************************************************************
	// ** Debugging
	// ************************************************************************
	def fullReport() {
		typeVariables.values.forEach[println(fullDescription)]
	}
}
