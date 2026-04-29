package hxcore.flecs.flecs_wrapper.bindings.haxe;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Type;
#end

class EntityMacros {
#if macro
  public static function buildSet(selfExpr:Expr, compExpr:Expr, valueExpr:Expr, notifyExpr:Expr):Expr {
    var notifyExprFinal = notifyExpr != null ? notifyExpr : macro true;

    var compType = Context.typeof(compExpr);
    var structType = resolveComponentStructType(compExpr.pos, compType);
    if (structType == null) {
      switch (valueExpr.expr) {
        case EObjectDecl(_):
          Context.error(
            "Cannot infer component struct type for `{ ... }` assignment.\n"
              + "Use `var v = Component.of(MyComp)` (not `: Component`), "
              + "or assign through `get(comp)` / use `setValue(comp, new MyComp(...))`.",
            valueExpr.pos
          );
        default:
      }

      return macro $selfExpr.setValue($compExpr, $valueExpr);
    }

    switch (valueExpr.expr) {
      case EObjectDecl(fields):
        var assigns:Array<Expr> = [];
        var ct:ComplexType = Context.toComplexType(structType);
        var ptrCt:ComplexType = TPath({
          pack: ["cpp"],
          name: "Pointer",
          params: [TPType(ct)],
          sub: null
        });

        var clsFields = switch structType {
          case TInst(r, _):
            r.get().fields.get();
          default:
            Context.error("Unsupported component struct type", valueExpr.pos);
            null;
        };

        var fieldMap = new Map<String, Bool>();
        for (cf in clsFields) {
          switch cf.kind {
            case FVar(_, _):
              fieldMap.set(cf.name, true);
            default:
          }
        }

        for (f in fields) {
          if (!fieldMap.exists(f.field)) {
            Context.error('Unknown field "${f.field}" for this component struct', f.expr.pos);
          }
          // `untyped` member writes compile to direct field stores on the cpp struct reference.
          assigns.push(macro untyped $p{["existing", f.field]} = ${f.expr});
        }

        var declarePtr:Expr = {
          expr: EVars([
            {
              name: "__typedPtr",
              type: ptrCt,
              expr: macro self.tryGet(comp),
              isFinal: false,
            }
          ]),
          pos: valueExpr.pos,
        };
        var declareExisting:Expr = {
          expr: EVars([
            {
              name: "existing",
              type: null,
              expr: macro __typedPtr.ref,
              isFinal: false,
            }
          ]),
          pos: valueExpr.pos,
        };

        return macro {
          var self = $selfExpr;
          var comp = $compExpr;
          if (!self.has(comp) && !self.add(comp)) {
            false;
          } else {
            $e{declarePtr};
            if (__typedPtr == null) {
              false;
            } else {
              $e{declareExisting};
              $b{assigns};
              if ($notifyExprFinal) {
                self.mark(comp);
              }
              true;
            }
          }
        };

      default:
        return macro $selfExpr.setValue($compExpr, $valueExpr);
    }
  }

  static function resolveComponentStructType(pos:Position, t:haxe.macro.Type):Null<haxe.macro.Type> {
    return switch Context.follow(t) {
      case TAbstract(_.get() => a, params)
        if (a.pack.concat([a.name]).join(".") == "hxcore.flecs.flecs_wrapper.bindings.haxe.ComponentRef"):
        params.length == 1 ? params[0] : null;
      default:
        null;
    }
  }
#end
}
