use std
use fmt
use os
use compiler.utils
use compiler.ast
use compiler.gen
use compiler.parser.package
use string

Parser::parseEnumDef(){
    utils.debug("parser.Parser::parseEnumDef()")
    reader<scanner.ScannerStatic> = this.scanner
    reader.scan()
    
    this.expect( ast.LBRACE)
    
    reader.scan()
    defaulte = 0
    while reader.curToken != ast.RBRACE {
        gv = new gen.VarExpr(reader.curLex.dyn(),this.line,this.column)
        gv.structtype = true
        //TODO: gv.ivalue = defaulte ++
        gv.ivalue = string.tostring(defaulte)        
        this.gvars[gv.varname] = gv
        gv.is_local = false
        gv.package  = this.pkg.package
        gv.type = ast.I32
        gv.size = 4

        reader.scan()
        if reader.curToken == ast.COMMA
            reader.scan()

        defaulte += 1
    }
    reader.scan()
}
Parser::parseStructVar(varname)
{
    utils.debug("parser.Parsr::parseStructVar()")
    reader<scanner.ScannerStatic> = this.scanner
    this.expect( ast.LT )
    var = this.parseVarExpr(varname)
    varexpr = var
    this.check(varexpr.structtype)
    
    if reader.curToken == ast.ASSIGN {
        
        reader.scan()
        this.expect( ast.INT)
        varexpr.ivalue = reader.curLex.dyn()
        
        reader.scan()
    }
    this.gvars[varname] = varexpr
    varexpr.is_local = false
    varexpr.package  = this.pkg.package
}
Parser::parseFlatVar(var){
    utils.debugf("parser.Parser::parseFlatVar() varname:%s",var)
    varexpr = new gen.VarExpr(var,this.line,this.column)
    
    this.gvars[var] = varexpr
    varexpr.is_local = false
    varexpr.package  = this.pkg.package
}

Parser::parseClassFunc(var){
    utils.debugf("parser.Parser::parseClassFunc() varname:%s",var)
    reader<scanner.ScannerStatic> = this.scanner
    this.expect(  ast.COLON)
    
    reader.scan()
    this.expect( ast.COLON )
    
    reader.curToken  = ast.FUNC
    
    f = this.parseFuncDef(true,false)
    this.check(f != null)
    
    f.clsname = var
    this.pkg.addClassFunc(var,f,this)
    
    this.addFunc(var + f.name,f)
    return
}
Parser::parseExternClassFunc(pkgname){
    utils.debugf("parser.Parser::parseExternClassFunc() name:%s",pkgname)
    reader<scanner.ScannerStatic> = this.scanner
    this.expect( ast.DOT)
    reader.scan()
    this.expect( ast.VAR)
    clsname = reader.curLex.dyn()
    reader.scan()
    if this.getImport(pkgname) == "" {
        this.check(false,fmt.sprintf("consider import package: use %s",this.package))
    }
    this.expect(  ast.COLON )
    
    reader.scan()
    this.expect( ast.COLON )
    
    reader.curToken  = ast.FUNC
    
    f = this.parseFuncDef(true,false)
    this.check(f != null)
    
    f.clsname = clsname
    pkg = this.pkg.getPackage(pkgname)
    pkg.addClassFunc(clsname,f,this)
    f.package = pkg
    
    this.addFunc(clsname + f.name,f)
    return
}
Parser::parseGlobalDef()
{
    reader<scanner.ScannerStatic> = this.scanner
    utils.debugf("parser.Parser::parseGlobalDef() %s line:%d\n",reader.curLex.dyn(),this.line)
    if reader.curToken != ast.VAR
        this.check(false,"SyntaxError: global var define invalid token:" + ast.getTokenString(reader.curToken))
    var = reader.curLex.dyn()
    tx = reader.transaction() 
    reader.scan()
    match reader.curToken{
        ast.COLON: return this.parseClassFunc(var)
        ast.DOT:   return this.parseExternClassFunc(var)
        // ast.LT   : return parseStructVar(var)
        // _        : return parseFlatVar(var)
        _ : {
            reader.rollback(tx)
            return this.parseGlobalAssign()
        }
    }
}

Parser::parseGlobalAssign()
{
    utils.debug("parser.Parser::parseGlobalAssign()")
    needinit = true
    expr = this.parseExpression(1)
    if expr == null this.panic("parseGlobalAssign wrong")

    var = null
    assign = null
    match type(expr) {
        type(gen.AssignExpr) : {
            ae = expr
            if type(ae.lhs) != type(gen.VarExpr)
                this.panic("unsupport global synatix: " + expr.toString(""))
            var = ae.lhs
            assign = ae
            match type(ae.rhs) {
                type(gen.IntExpr) : {
                    var.ivalue = ae.rhs.lit
                    if var.structtype needinit = false 
                }
                type(gen.CharExpr) : {
                    var.ivalue = ae.rhs.lit
                    if var.structtype needinit = false 
                }
                type(gen.NullExpr) : {
                    if(var.structtype) needinit = false
                }
                type(gen.ArrayExpr) : {
                    if var.structtype && var.stack {
                        arr = ae.rhs.lit
                        if std.len(arr) != var.stacksize {
                            this.check(false,
                                fmt.sprintf("arr.size:%d != stacksize:%d",
                                    std.len(arr),var.stacksize
                                )
                            )
                        }
                        for i : arr {
                            if(type(i) == type(gen.IntExpr)){
                                ie = i
                                var.elements[] = ie.lit
                            }else if(type(i) == type(gen.MapExpr)){
                                me = i
                                for(ii : me.lit){
                                    ii.check(type(ii) == type(gen.IntExpr),"must be int expr in k expr")
                                    var.elements[] = ii.lit
                                }
                            }else{                            
                                i.check(false,"all arr elments should be intexpr")
                            }
                        }
                        needinit = false
                    }
                }
                type(gen.NewStructExpr) : {
                    nse = ae.rhs
                    if(var.stack){
                        var.sinit = nse
                        needinit = false
                    }
                }
        
            }
        }
        type(gen.VarExpr) : {
            var   = expr
            assign     = new gen.AssignExpr(this.line,this.column)
            assign.opt = ast.ASSIGN
            assign.lhs = var
            assign.rhs = new gen.NullExpr(this.line,this.column)
            if var.structtype needinit = false     
        }
        _ : this.panic("unsupport global synatix: " + expr.toString(""))
    }
    this.gvars[var.varname] = var
    var.is_local = false 
    var.package  = this.pkg.package
    if !needinit return false

    this.pkg.InsertInitVarExpression(assign)
} 
