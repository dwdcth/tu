use std
use ast
use parser.package
use parser
use utils

func registerFunc(fn){
    utils.debugf("compile.registerFunc() funcname:%s",fn.name)

    if std.len(fn.closures) {
        for(closure : fn.closures){
            funcname = "func_" + ast.incr_closureidx()
            closure.receiver.varname = fn.parser.getpkgname() + "_" + funcname
            closure.parser = fn.parser
            closure.name   = funcname
            registerFunc(closure)
        }
    }
    currentFunc = fn
    CreateFunction(fn)
    currentFunc = null
}
func registerFuncs(){
    utils.debug("compile.registerFunc()")
    for f : parser.funcs {
        registerFunc(f)
    }
}
func CreateFunction(fn) {
    if fn.isExtern return True
    if fn.block == null return True

    funcname = fn.fullname()
    utils.debug("compile.CreateFunction()  fullname:%s",funcname)
    
    writeln(".global %s", funcname)
    writeln("%s:", funcname)
    writeln("    push %%rbp")
    writeln("    mov %%rsp, %%rbp")
    writeln("    sub $%d, %%rsp", fn.stack_size)
    
    for i = 0; i < 6; i += 1
        Store_gp(i, -8 * ( i + 1 ), 8)
    
    if fn.block != null {
        funcCtxChain = []
        blockcreate(funcCtxChain)
        funcCtx = std.tail(funcCtxChain)
        funcCtx.cur_funcname = funcname

        for(arg : fn.params_order_var){
            funcCtx.createVar(arg.varname,arg)
        }
        
        for(stmt : fn.block.stmts){
            stmt.compile(funcCtxChain)
        }
        blockdestroy(funcCtxChain)
    }
    if fn.name == "main"
        writeln("    mov $0, %%rax")

    writeln("L.return.%s:", funcname)
    writeln("    mov %%rbp, %%rsp")
    writeln("    pop %%rbp")
    writeln("    ret")
}