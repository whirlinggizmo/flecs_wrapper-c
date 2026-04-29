package hxcore.flecs.flecs_wrapper.bindings.haxe;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class ComponentMacro {
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

		cls.meta.add(":structAccess", [], cls.pos);
		cls.meta.add(":structInit", [], cls.pos);
		cls.meta.add(":nativeGen", [], cls.pos);
		cls.meta.add(":keep", [], cls.pos);
		cls.meta.add(":native", [macro $v{nativeName}], cls.pos);

		var fields = Context.getBuildFields();

		// Inject positional constructor if none exists
		// NOTE:  this works, but the haxe linter doesn't see it, so it complains about 
		// missing consructor (even though this will inject one).  So we require a constructor
		// to be defined in the class.  FWIW, it gives the component the ability to set a default value
		// for each field.
		/*
		var hasNew = Lambda.exists(fields, f -> f.name == "new");
		if (!hasNew) {
			var varFields = fields.filter(f -> switch (f.kind) {
				case FVar(_, _): true;
				default: false;
			});

			var args:Array<FunctionArg> = varFields.map(f -> {
				var type = switch (f.kind) {
					case FVar(t, _): t;
					default: null;
				};
				({
					name: f.name,
					opt: true,
					type: type,
					value: macro 0
				} : FunctionArg);
			});

			var body:Array<Expr> = varFields.map(f -> {
				var name = f.name;
				macro this.$name = $i{name};
			});

			fields.push({
				name: "new",
				pos: cls.pos,
				access: [APublic],
				kind: FFun({
					args: args,
					ret: null,
					expr: macro $b{body}
				})
			});
		}
*/
		return fields;
	}
}
