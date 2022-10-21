use std
use runtime
use string

func map_create(){
    sentinel<RbtreeNode> = new RbtreeNode
	sentinel.black()

	return new Rbtree {
		root : sentinel,
		sentinel : sentinel,
		insert: map_insert_or_update,
	}
}

func map_insert_or_update(temp<RbtreeNode>, node<RbtreeNode>,sentinel<RbtreeNode>)
{
    // **p
    // FIXME: p<rebtree_node*> parser报错
    p<u64*> = null

    while True {
        if  node.key == temp.key {
            //compatible with mem type var
            // if  temp.v.type == node.v.type {
                temp.v = node.v
                return Update
            // }
        }
        if  node.key < temp.key {
            p = &temp.left 
        }else{
            p = &temp.right
        }
        if  *p == sentinel  {
            break
        }
        temp = *p
    }

    *p = node
    node.parent = temp
    node.left = sentinel
    node.right = sentinel

    // make red
    node.color = 1
}

func hash_key(data<u8*>,len<u64>){
    i<i64>   = 0
    key<i64> = 0
    for(i<u64> = 0 ; i < len ; i += 1){
        temp_key<u32> = key
        temp_data<u8*> = data + i
        key = temp_key * 31 + *temp_data
    }
    return key
}

func map_insert( m<runtime.Value> ,k<runtime.Value>,v<runtime.Value>)
{
    tree<Rbtree> = m.data
    node<RbtreeNode> = new RbtreeNode
    hk<u64> = 0
    if  k.type == runtime.Bool || k.type == runtime.Int {
        hk = k.data
    }
    if  k.type == runtime.String {
        str<string.Str> = k.data
        hk = hash_key(k.data,str.len())
    }
    node.key = hk
    node.k = k
    node.v = v
    tree.insert(node)
}

func map_find(m<runtime.Value>, key<runtime.Value>){
    hk<u64> = 0
    match key.type {
        runtime.Bool   : hk = key.data
        runtime.Int    : hk = key.data
        runtime.String : {
            str<string.Str> = key.data
            hk = hash_key(key.data,str.len())
        }
    }
    tree<Rbtree>  = m.data
    return tree.find(hk)
}