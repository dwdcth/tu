use ast
use parser
use compile
use std
use utils


ChainExpr::indexgen(ctx)
{
	this.first.compile(ctx)
	s = this.first
	member = s.getMember()
	this.check(member.isstruct,"field must be mem at chain expression")
	if member.pointer {
		compile.Load()
	}
	for(i = 0 ; i < std.len(this.fields) ; i += 1 ){
		field = this.fields[i]
		this.check(type(field) == type(MemberExpr),"field must be member expression at mem chain expression")
		me = field
		this.check(member.structref != null,"must be memref in chain expr")
		s = member.structref
		member = s.getMember(me.membername)
		this.check(member != null,"mem not exist field:" + me.membername)
		if i != std.len(this.fields) - 1 {
			this.check(member.isstruct,"middle field must be mem type in chain expression")
		}else{
			if !member.pointer && !member.isarr {
				this.check(false,"last second field should be pointer in array index")
			}
		}
		compile.writeln("	add $%d, %rax",member.offset)
		if member.pointer {
			compile.Load()
		}
	}
	this.check(this.last != null,"miss last field in chain expression")
	if type(this.last) != type(IndexExpr) {
		this.check(false,"last field should be index")
	}

	index = this.last
	index.compile_chain_static(ctx,member.type)
	this.ret = member
	return this
}