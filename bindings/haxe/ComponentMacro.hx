package hxcore.flecs.flecs_wrapper.bindings.haxe;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

class ComponentMacro {
	public static macro function ofType(typeExpr:Expr):Expr {
		// Resolve the class type from the expression (e.g. `Position` used as a type name)
		var typePath = switch (typeExpr.expr) {
			case EConst(CIdent(name)): name;
			case EField(_, name): name;
			default: null;
		};
		if (typePath == null) {
			Context.error("Component.ofType() requires a class type name", Context.currentPos());
		}

		// Look up the class type by name
		var classType = switch (Context.getType(typePath)) {
			case TInst(r, _): r.get();
			default: null;
		};
		if (classType == null) {
			Context.error('Component.ofType() requires a class type, got: ${typePath}', Context.currentPos());
		}

		var nativeName:String = null;
		for (meta in classType.meta.get()) {
			if (meta.name == ":component" && meta.params != null && meta.params.length > 0) {
				switch (meta.params[0].expr) {
					case EConst(CString(s)): nativeName = s;
					default:
				}
				break;
			}
		}
		if (nativeName == null) {
			Context.error('Component.ofType() requires a class annotated with @:component (got: ${typePath})', Context.currentPos());
		}
		var structCt = Context.toComplexType(Context.getType(typePath));
		return macro new hxcore.flecs.flecs_wrapper.bindings.haxe.ComponentRef<$structCt>(
			hxcore.flecs.flecs_wrapper.bindings.haxe.Component.create($v{nativeName}, cpp.Native.sizeof($typeExpr))
		);
	}

	public static macro function register():Void {
		haxe.macro.Compiler.addGlobalMetadata(
			"",
			"@:build(hxcore.flecs.flecs_wrapper.bindings.haxe.ComponentMacro.build())",
			true, true, false
		);
	}

	public static macro function build():Array<Field> {
		var localClass = Context.getLocalClass();
		if (localClass == null) return Context.getBuildFields();
		var cls = localClass.get();

		var nativeName:String = null;
		for (meta in cls.meta.get()) {
			if (meta.name == ":component") {
				if (meta.params != null && meta.params.length > 0) {
					switch (meta.params[0].expr) {
						case EConst(CString(s)):
							nativeName = s;
						default:
					}
				}
				break;
			}
		}

		// Not a @:component class — skip silently
		if (nativeName == null) {
			return Context.getBuildFields();
		}

		// Don't process classes in the flecs_wrapper bindings package itself
		var pkg = cls.pack.join(".");
		if (StringTools.startsWith(pkg, "hxcore.flecs")) {
			return Context.getBuildFields();
		}

		cls.meta.add(":structAccess", [], cls.pos);
		cls.meta.add(":structInit", [], cls.pos);
		cls.meta.add(":nativeGen", [], cls.pos);
		cls.meta.add(":keep", [], cls.pos);
		cls.meta.add(":native", [macro $v{nativeName}], cls.pos);
		// Emit a no-arg default constructor in the C++ header so that cpp::Struct<T>
		// and cpp::Pointer<T> (which call T()) can be instantiated.
		cls.meta.add(":headerClassCode", [macro $v{'${nativeName}() {}\n'}], cls.pos);

		return Context.getBuildFields();
	}
}
