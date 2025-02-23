
use os
use fmt
use std
use std.map

func for_first(data<Value>){
	match data.type 
	{
		Map : {
			tree<map.Rbtree> = data.data
			if tree.root == tree.sentinel { return Null}
			return tree.root.min(tree.sentinel)
		}
		Array : {
			arr<std.Array> = data.data
			if  arr.used <= 0 { return Null}
			iter<std.Array_iter> = new std.Array_iter
			iter.addr = arr.addr
			init_index = 0
			iter.cur  = init_index
			return iter
		}
		_     : os.dief("[for range]: first unsupport type:%s" , type_string(data))
	}
}
func for_get_key(node,data<Value>){
	match data.type {
		Map : {
			map_node<map.RbtreeNode> = node
			if node == Null {
				fmt.println("for get key null")
			}
			return map_node.k
		}
		Array : {
			iter<std.Array_iter> = node
			return iter.cur
		}
		_  : os.dief("[for range]: get key unsupport type:%s" ,type_string(data))
	}
}
func for_get_value(node,data<Value>){
	match data.type  {
		Map : {
			map_node<map.RbtreeNode> = node
			return map_node.v
		}
		Array : {
			iter<std.Array_iter> = node
			rv<u64*> = iter.addr
			return *rv
		}
		_ : os.dief("[for range]: get value unsupport type:%s" , type_string(data))
	}
}
func for_get_next(node,data<Value>){
	match data.type {
		Map : {
			m<map.Rbtree> = data.data
			if m == null {
				fmt.println("empty")
			}
			return m.next(node)
		}
		Array : {
			arr<std.Array> = data.data
			arr_node<std.Array_iter> = node
			// ++i
			index<Value> = arr_node.cur
			index.data += 1
			if index.data >= arr.used { 
				return Null
			}
			// ++pointer
			arr_node.addr += 8
			return arr_node
		}
		_ : os.dief("[for range]: next unsupport type:%s" , type_string(data))
	}
}