
use compiler.ast 
use compiler.compile
use compiler.internal
use compiler.parser
use compiler.parser.package
use std
use compiler.utils

class ClosureExpr : ast.Ast { 
	varname = varname
	func init(varname,line,column){
		super.init(line,column)
	}
	func toString() { return "ClosureExpr(" + this.varname + ")" }
}

ClosureExpr::compile(ctx){
	compile.writeln("    lea %s(%%rip), %%rax", this.varname)
	return null
}

class FunCallExpr : ast.Ast {
    funcname = ""
    package  = ""
    args = [] # [Ast]
	cls       # Class
    is_pkgcall
    is_extern
    is_delref

	tyassert
	func init(line,column){
		super.init(line,column)
	}
}
FunCallExpr::checkFirstThis(ctx,var){
    if(std.len(this.args) == 0){
		this.args[] = var
        return null
    }
    first = this.args[0]
	argsv = [var]

    if(type(first) == type(VarExpr)){
		fe = first
        if(fe.varname != var.varname){
			std.merge(argsv,this.args)
            this.args  = argsv
        }
    }else{
		std.merge(argsv,this.args)
        this.args  = argsv
    }

    return null
}
FunCallExpr::compile(ctx)
{
	this.record()
	utils.debugf("FunCallExpr:  package:%s func:%s",this.package,this.funcname)
	cfunc = compile.currentFunc
	packagename = this.package
	fc = null
	var = null
	if !this.is_pkgcall || this.is_extern {
		packagename      = cfunc.parser.getpkgname()
	}
	if  std.empty(this.funcname) {
		fc = new ast.Function()
		fc.isExtern    = false
		fc.isObj       = true
		fc.is_variadic = false
		// funcexec(ctx,fc,this)
		this.call(ctx,fc)
		compile.writeln("	add $8 , %%rsp")

		return null
	}else if this.cls != null {
        fc = this.cls.getFunc(this.funcname)
        if fc == null
            this.check(false,
                "can not find class func definition of " + this.funcname
			)
        fc.isObj       = false
    }else if this.package != "" && GP().getGlobalVar("",this.package) != null {
        var = GP().getGlobalVar("",this.package)
        goto OBJECT_MEMBER_CALL
    }else if ast.getVar(ctx,this.package) != null {
		var = ast.getVar(ctx,this.package)
		OBJECT_MEMBER_CALL:
		if var.structname != "" && var.structname != null {
			s = compile.currentParser.pkg.getPackage(var.structpkg)
				.getClass(var.structname)
			if s == null this.panic("static class not exist:" + var.structpkg + "." +  var.structname)
			fn = s.getFunc(this.funcname)
			if(fn == null) this.panic("func not exist")
			this.checkFirstThis(ctx,var)
			this.call(ctx,fn)
			return null
		}else if this.tyassert != null {
			s = compile.currentParser.pkg
					.getPackage(this.tyassert.pkgname)
					.getClass(this.tyassert.name)
			fn = s.getFunc(this.funcname)
			this.call(ctx,fn)
			return null
		}
		this.checkobjcall(var)
		compile.GenAddr(var)
		compile.Load()
		compile.Push()
		internal.object_func_addr(this,this.funcname)
		compile.Push()
		fc = new ast.Function()
		fc.isExtern    = false
		fc.isObj       = true
		fc.is_variadic = false
		this.call(ctx,fc)

		compile.writeln("	add $8, %%rsp")
		return null
	}else if this.package == "" && ast.getVar(ctx,this.funcname) != null {
		var = ast.getVar(ctx,this.funcname)
		compile.GenAddr(var)
		compile.Load()
		compile.Push()
		fc = new ast.Function()
		fc.isExtern    = false
		fc.isObj       = true
		fc.is_variadic = false
		this.call(ctx,fc)
		compile.writeln("   add $8,%%rsp")
		return null
	}else{
		pkg  = package.packages[packagename]
		if !pkg {
			this.check(false,
				"can not find package definition of" +
				this.package
			)
		}
		fc = pkg.getFunc(this.funcname,this.is_extern)
		if !fc {
			this.check(false,
				fmt.sprintf(
					"can not find func definition of %s : pkgname:%s  this.pkgname:%s ",
					this.funcname,
					packagename,
					this.package
				)
			)
		}
		fc.isObj       = false
	}
	this.call(ctx,fc)
	return null
}

FunCallExpr::toString() {
    str = "FunCallExpr[func = "
    str += this.package + "." + this.funcname
    str += ",args = ("
    for arg : this.args {
        str += arg.toString()
        str += ","
    }
    str += ")]"
    return str
}
FunCallExpr::checkobjcall(var){
    if !this.is_pkgcall {
        if std.len(this.args) == 0 {
            this.panic("funcall expr invalid: should be obj call,but first this arg is null")
        }
        if type(this.args[0]) != type(VarExpr) {
            this.panic("funcall expr invalid: should be obj call,but first this arg should be var")
        }
		This = this.args[0]
        if This.varname != var.varname {
            this.panic("funcall expr invalid: should be obj call,but first this arg should be this")
        }
        return true
    }
    if std.len(this.args) == 0 {
        this.args[] = var
    }else if type(this.args[0]) != type(VarExpr) {
		params = this.args
		this.args = []
        this.args[] = var
		std.merge(this.args,params)
    }else{
		This = this.args[0]
        if This.varname != var.varname {
			params = this.args
			this.args = []
        	this.args[] = var
			std.merge(this.args,params)
        }
    }

}