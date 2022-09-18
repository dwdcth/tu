use runtime
use fmt
use std

func new(init<i8*>){
	r<i8*> = stringnew(init)
	if r == null fmt.println("stringnew failed")
	return runtime.newobject(runtime.STRING,r)
}
func newlen(init<i8*>,l<i32>){
	r<i8*> = stringnewlen(init,l)
	if r == null fmt.println("stringnewlen failed")
	return runtime.newobject(runtime.STRING,r)
}
func sub(v<runtime.Value>,lo){
	str<i8*> = v.data
	l<i32> = *lo
	if l > stringlen(str) {
		return ""
	}

	str += l
	return new(str)
}
func split(s<runtime.Value> , se<runtime.Value>) {
	tokens = []
	sp<i8*> = s.data
	sep<i8*> = se.data

	elements<i32> = 0
	start<i64> = 0
	j<i64> = 0

	seplen<i32> = stringlen(sep)
	len<i32>    = stringlen(sp)
    if seplen < 1 || len <= 0 return tokens

    for (j = 0; j < len - seplen + 1 ; j += 1) {
        //search the separator 
		ssp<i8*> = sp + j
		if seplen == 1 && *ssp == *sep {
			tokens[] = newlen(sp + start,j - start)
            start = j + seplen
            j = j + seplen - 1 // skip the separator
		}else if std.memcmp(sp + j,sep , seplen) == runtime.Null {
			tokens[] = newlen(sp + start,j - start)
            start = j + seplen
            j = j + seplen - 1 // skip the separator
		}
    }
    // Add the final element. We are sure there is room in the tokens array.
	tokens[] = newlen(sp + start, len - start)
	return tokens
}
func index_get(v<runtime.Value>,index<runtime.Value>){
	if  v.type != runtime.String {
        fmt.println("warn: string index not string type")
        os.exit(-1)
    }

    if  v == null || v.data == null || index == null {
        fmt.println("warn: string index is null ,probably something wrong\n")
        os.exit(-1)
    }

	str<i8*> = v.data
	l<i32> = index.data
	if l >= stringlen(str) {
		fmt.println("warn: string index out of bound ")
		return 0
	}

	str += l
	cn<i8> = *str
	return runtime.newobject(runtime.Char,cn)
}
func tostring(num<runtime.Value>){
	match num.type {
		runtime.Char :{
			str = stringputc(stringempty(),num.data)
			return string.new(str)
		}
		_ :{
    		buf<i8*> = new 10
    		ilen<i32> = 10
    		std.itoa(num.data,buf,ilen) 
    		return string.new(buf)
		}
	}
}
func tonumber(str<runtime.Value>){
	base<i8> = 10
	ret<i64> = std.strtol(str.data,runtime.Null,base)
	return int(ret) 
}