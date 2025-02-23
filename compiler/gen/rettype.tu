use compiler.ast
use compiler.utils 
use std

ArgsPosExpr::getType(ctx){
	this.panic("getType: unsupport argsposexpr")
}
NullExpr::getType(ctx){
	return ast.U8
}
BoolExpr::getType(ctx){
	return ast.U8
}
CharExpr::getType(ctx){
	return ast.I8
}
IntExpr::getType(ctx){
	return ast.I64
}
DoubleExpr::getType(ctx){
	this.panic("getType: unsupport double\n")
}
StringExpr::getType(ctx){
	return ast.U64
}
ArrayExpr::getType(ctx){
	this.panic("getType: unsupport array\n")
}
MapExpr::getType(ctx){
	this.panic("getType: unsupport map\n")
}
KVExpr::getType(ctx){
	this.panic("getType: unsupport kv\n")
}
ChainExpr::getType(ctx){
	if !this.ismem(ctx) return ast.U8

	member = null
	if type(this.first) == type(StructMemberExpr) {
		member = this.first.getMember()
	}else if type(this.first) == type(MemberExpr) {
		s = this.first
		member = s.getMember(ctx)
		if s.tyassert != null {
			member.isstruct = true
			member.structref = s.tyassert.getStruct()
		}
	}

	for(j = 0 ; j < std.len(this.fields) ; j += 1){
		i = this.fields[j]
		this.check(type(i) == type(MemberExpr),"field must be member expression at mem chain expression")
		me = i
		if me.tyassert != null {
			member.isstruct = true
			member.structref = me.tyassert.getStruct()
		}
		this.check(member.isstruct,"must be memtype in chain expr")
		this.check(member.structref != null,"must be memref in chain expr")
		
		s = member.structref # Struct
		member = s.getMember(me.membername)
		this.check(member != null,"mem not exist field:" + me.membername)

		if j != (std.len(this.fields) - 1) {
			this.check(member.isstruct,"middle field must be mem type in chain expression:" + me.member)
		}else{
			if !member.pointer && !member.isarr {
				this.check(false,"last second field should be pointer in array index")
			}
		}
		// this.check(member.isstruct,"chainexpr::getType middle field must be mem type in chain expression field:" + me.membername)
	}
		
	this.check(this.last != null,"miss last field in chain expression")
	if type(this.last) == type(MemberCallExpr) {
		return ast.U64
	}
	if type(this.last) == type(IndexExpr) {
		return member.type
	}
	me = this.last
	if me.tyassert != null {
		member.isstruct = true
		member.structref = me.tyassert.getStruct()
	}
	this.check(member.structref != null,"must be memref in chain expr")
	ss = member.structref
	member = ss.getMember(me.membername)
	this.check(member != null,"mem not exist field:" + me.membername)
	if member.pointer return ast.U64
	if member.type >= ast.I8 && member.type <= ast.U64{
		return member.type
	}
	return ast.U64
}
VarExpr::getType(ctx){
	this.getVarType(ctx,this)
	if this.ret.pointer return ast.U64

	return this.ret.type
}
ClosureExpr::getType(ctx){
	this.panic("getType: unsupport closure\n")
}
StructMemberExpr::getType(ctx){
	m = this.getMember()
	if m.pointer || m.isstruct return ast.U64
	return m.type
}
AddrExpr::getType(ctx){
	return ast.U64
}
DelRefExpr::getType(ctx){
	if type(this.expr) == type(VarExpr) 
	{
		var = this.expr
		var = var.getVar(ctx,this)
		if var.pointer 
			return ast.U64
		
		else if var.structtype
			return var.type
		else 
			return ast.I64

	}else if type(this.expr) == type(StructMemberExpr) {
		e = this.expr
		m = e.getMember()
		if m.pointer return ast.U64
		return m.type
	}
	return this.expr.getType(ctx)
}
IndexExpr::getType(ctx){
	var = new VarExpr(this.varname,this.line,this.column)
    var.package = this.package
	match var.getVarType(ctx,this) {
		ast.Var_Global_Local_Static_Field | ast.Var_Local_Static_Field: {
			sm = new StructMemberExpr(var.package,this.line,this.column)
			sm.member = var.varname
			sm.var    = var.ret
			return sm.getMember().type
		}
	}
	return var.getType(ctx)
}
NewStructExpr::getType(ctx){
	return ast.U64
}
StructInitExpr::getType(ctx){
	this.panic("getType: unsupport struct init \n")
	return ast.U64
}
BinaryExpr::getType(ctx){
	
	if !this.rhs return this.lhs.getType(ctx)
	l = this.lhs.getType(ctx)
	r = this.rhs.getType(ctx)
	return utils.max(l,r)
}
FunCallExpr::getType(ctx){
	return ast.U64
}
AssignExpr::getType(ctx){
	return this.lhs.getType(ctx)
}
NewClassExpr::getType(ctx){
	this.panic("getType: unsupport new class\n")
}
BuiltinFuncExpr::getType(ctx){
	return ast.U64
	this.panic("getType: unsupport builtin\n")
}
NewExpr::getType(ctx){
	return ast.U64
}
MemberExpr::getType(ctx){
	var = GP().getGlobalVar("",this.varname)
	if var == null
		var = ast.getVar(ctx,this.varname)
	return var.getType(ctx)
}
MemberCallExpr::getType(ctx){
	this.panic("getType: unsupport MemberCall\n")
}
MatchCaseExpr::getType(ctx){
	this.panic("getType: unsupport MatchCaseExpr\n")
}
IfCaseExpr::getType(ctx){
	this.panic("getType: unsupport IfCaseExpr\n")
}
LabelExpr::getType(ctx){
	this.panic("getType: unsupport LabelExpr\n")
}
TypeAssertExpr::getType(ctx){
	this.panic("getType: unsupport TypeAssertExpr\n")
}