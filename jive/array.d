/**
License: public domain
Authors: Simon Bürger
*/

module jive.array;

import jive.internal;
import core.exception : RangeError;
import core.memory : GC;
import core.stdc.string : memmove, memcpy, memset;
import std.algorithm;
import std.conv : emplace;
import std.format;
import std.range;
import std.traits;


private extern(C)
{
	// TODO: switch to core.memory.pureMalloc/pureFree when https://github.com/dlang/druntime/pull/1836 is resolved
	void* malloc(size_t) @system pure @nogc nothrow;
	void free(void*) @system pure @nogc nothrow;
}

private
{
	void* trustedMalloc(size_t s) @trusted pure @nogc nothrow
		{ return malloc(s); }
	void trustedFree(void* p) @trusted pure @nogc nothrow
		{ return free(p); }
}

/**
 *  Workaround to make somewhat nice out-of-bounds errors in @nogc code.
 *  TODO: remove when DIP1008 is implemented which should make a simple
 *        'throw new RangeError(file, line)' work even in @nogc code.
 */
private template boundsCheckMsg(string file, int line)
{
	static immutable string boundsCheckMsg = format("Array out-of-bounds at %s(%s)", file, line);
}

/**
 *  Array of dynamic size.
 *
 *  If you add elements, new memory will be allocated automatically as needed.
 *  Typically there is more memory allocated than is currently in use. There is
 *  a tradeoff between wasted space and frequency of reallocations. The default
 *  behaviour is to double the capacity every time the allocated memory is
 *  filled up. This ensures that pushBack takes O(1) in amortized time. If you
 *  know the number of elements in advance, you can use reserve to avoid
 *  reallocations, but this is just an optimization and never necessary.
 */
struct Array(V)
{
	private V* _ptr = null;			// unused elements are undefined
	private size_t _capacity = 0;	// size of buf
	private size_t _length = 0;		// used size

	/** constructor for given length */
	this(size_t size)
	{
		resize(size);
	}

	/** constructor for given length and init */
	this(size_t size, V val)
	{
		resize(size, val);
	}

	/** constructor that gets content from arbitrary range */
	this(Stuff)(Stuff data)
		if(isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(_length + data.length);

		foreach(ref x; data)
			pushBack(x);
	}

	/** post-blit that does a full copy */
	this(this)
	{
		auto newPtr = cast(V*)trustedMalloc(V.sizeof * _length);
		if(newPtr is null)
			assert(false, "jive.array failed to allocate memory");
		static if(hasElaborateCopyConstructor!V)
		{
			for(size_t i = 0; i < _length; ++i)
				emplace(newPtr + i, *(_ptr + i));
		}
		else
			memcpy(newPtr, _ptr, V.sizeof * _length);
		_ptr = newPtr;
		_capacity = _length;
	}

	/** destructor */
	~this()
	{
		static if (hasElaborateDestructor!V)
			foreach (ref x; this[])
				destroy(x);
		static if (hasIndirections!V)
			GC.removeRange(_ptr);

		trustedFree(_ptr);
		_ptr = null; // probably not necessary, just a precaution
	}

	/** check for emptiness */
	bool empty() const pure nothrow @property @safe
	{
		return _length == 0;
	}

	/** number of elements */
	size_t length() const pure nothrow @property @safe
	{
		return _length;
	}

	/** ditto */
	size_t opDollar() const pure nothrow @property @safe
	{
		return _length;
	}

	/** number of elements this structure can hold without further allocations */
	size_t capacity() const pure nothrow @property @safe
	{
		return _capacity;
	}

	/** make sure this structure can contain given number of elements without further allocs */
	void reserve(size_t newCap, bool overEstimate = false) nothrow @trusted
	{
		if(newCap <= _capacity)
			return;

		if(overEstimate)
			newCap = max(newCap, 2*_capacity);

		auto newPtr = cast(V*)malloc(V.sizeof * newCap);
		if(newPtr is null)
			assert(false, "jive.array failed to allocate memory");
		memcpy(newPtr, _ptr, V.sizeof * _length);

		static if(hasIndirections!V)
		{
			memset(newPtr + length, 0, V.sizeof * (newCap - _length)); // prevent false pointers
			GC.addRange(newPtr, V.sizeof * newCap);
			GC.removeRange(_ptr);
		}

		free(_ptr);
		_ptr = newPtr;
		_capacity = newCap;
	}

	/** pointer to the first element */
	inout(V)* ptr() inout pure nothrow @property @safe
	{
		return _ptr;
	}

	/** default range */
	inout(V)[] opSlice() inout nothrow pure @trusted
	{
		return _ptr[0 .. _length];
	}

	/** subrange */
	inout(V)[] opSlice(string file = __FILE__, int line = __LINE__)(size_t a, size_t b) inout pure nothrow @trusted
	{
		if(boundsChecks && (a > b || b > _length))
			assert(false, boundsCheckMsg!(file, line));
		return _ptr[a .. b];
	}

	/** assign all elements to the same value */
	void opSliceAssign(V v)
	{
		this.opSlice()[] = v;
	}

	/* assign a subset of elements to the same value */
	void opSliceAssign(string file = __FILE__, int line = __LINE__)(V v, size_t a, size_t b)
	{
		this.opSlice!(file, line)(a, b)[] = v;
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(size_t i) inout pure nothrow @trusted
	{
		if(boundsChecks && i >= _length)
			assert(false, boundsCheckMsg!(file, line));
		return _ptr[i];
	}

	/** first element, same as this[0] */
	ref inout(V) front(string file = __FILE__, int line = __LINE__)() inout pure nothrow
	{
		return this.opIndex!(file, line)(0);
	}

	/** last element, same as this[$-1] */
	ref inout(V) back(string file = __FILE__, int line = __LINE__)() inout pure nothrow
	{
		return this.opIndex!(file, line)(_length-1);
	}

	/** add some new element to the back */
	void pushBack(V val) @trusted
	{
		reserve(_length + 1, true);
		emplace(_ptr + _length, move(val));
		++_length;
	}

	/** add multiple new elements to the back */
	void pushBack(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(_length + data.length, true);

		foreach(ref x; data)
			pushBack(x);
	}

	/** convenience alias for pushBack */
	alias pushBack opCatAssign;

	/** returns removed element */
	V popBack(string file = __FILE__, int line = __LINE__)() @trusted
	{
		if(boundsChecks && empty)
			assert(false, boundsCheckMsg!(file, line));

		--_length;
		V r = void;
		memcpy(&r, _ptr + _length, V.sizeof);
		static if(hasIndirections!V)
			memset(_ptr + _length, 0, V.sizeof);
		return r;
	}

	/** insert new element at given location. moves all elements behind */
	void insert(string file = __FILE__, int line = __LINE__)(size_t i, V data) @trusted
	{
		if(boundsChecks && i > _length)
			assert(false, boundsCheckMsg!(file, line));

		reserve(_length + 1, true);
		memmove(_ptr + i + 1, _ptr + i, V.sizeof * (_length - i));
		++_length;
		emplace(_ptr + i, move(data));
	}

	/** remove i'th element. moves all elements behind */
	V remove(string file = __FILE__, int line = __LINE__)(size_t i) @trusted
	{
		if(boundsChecks && i >= _length)
			assert(false, boundsCheckMsg!(file, line));

		V r = void;
		memcpy(&r, _ptr + i, V.sizeof);
		--_length;
		memmove(_ptr + i, _ptr + i + 1, V.sizeof * (_length - i));
		static if(hasIndirections!V)
			memset(_ptr + _length, 0, V.sizeof);
		return r;
	}

	/** sets the size to some value. Either cuts of some values (but does not free memory), or fills new ones with V.init */
	void resize(size_t size, V v) @trusted
	{
		// TODO: remove @trusted in case V's destructor is @system

		if(size <= _length) // shrink
		{
			static if(hasElaborateDestructor!V)
				for(size_t i = size; i < _length; ++i)
					destroy(*(_ptr + i));
			static if(hasIndirections!V)
				memset(_ptr + size, 0, V.sizeof * (_length - size));
			_length = size;
		}
		else // expand
		{
			reserve(size, false);
			for(size_t i = _length; i < size; ++i)
				emplace(_ptr + i, v);
			_length = size;
		}
	}

	/** ditto */
	void resize(size_t size)
	{
		resize(size, V.init);
	}

	/** sets the size and fills everything with one value */
	void assign(size_t newsize, V v)
	{
		resize(newsize);
		this[] = v;
	}

	/** remove all content but keep allocated memory (same as resize(0)) */
	void clear()
	{
		resize(0);
	}

	/** convert to string */
	void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
	{
		formatValue(sink, this[], fmt);
	}

	/** ditto */
	string toString() const
	{
		return format("%s", this[]);
	}

	hash_t toHash() const nothrow @trusted
	{
		return this[].hashOf;
	}

	bool opEquals(const ref Array other) const
	{
		return equal(this[], other[]);
	}

	static if(__traits(compiles, V.init < V.init))
	int opCmp(const ref Array other) const
	{
		return cmp(this[], other[]);
	}
}

///
/+@nogc+/ nothrow pure @safe unittest
{
	Array!int a;

	a.pushBack(1);
	a.pushBack([2,3,4,5]);
	assert(a.popBack() == 5);
	assert(equal(a[], [1,2,3,4]));

	a[] = 0;
	a[1..3] = 1;
	a.resize(6, 2);
	assert(equal(a[], [0,1,1,0,2,2]));
}

// check for all nice attributes in case the type is nice as well
@nogc nothrow pure @safe unittest
{
	struct S1
	{
		int x;
		//int* p; // FIXME: when GC.addRange/removeRange become pure
		this(this) @nogc nothrow pure @safe {}
		~this() @nogc nothrow pure @safe {}
	}

	static assert(hasElaborateDestructor!S1);
	static assert(hasElaborateCopyConstructor!S1);
	//static assert(hasIndirections!S);

	Array!S1 a;
	S1 s;
	a.pushBack(s);
	a.popBack();
	a.resize(5);
	a.insert(3, s);
	a.remove(3);
	a.reserve(10);
	a[] = s;
	a[0..1] = s;
	a.pushBack(a[0]);
	a.pushBack(a[0..1]); // only valid with the previous reserve!
}

// check correct invocation of postblit/destructor
unittest
{
	int counter = 0;

	struct S
	{
		bool active;
		this(bool active) { this.active = active; if(active) ++counter; }
		this(this) { if(active) ++counter; }
		~this() { if(active) --counter; }
	}

	{
		Array!S a;
		assert(counter == 0);
		a.pushBack(S(true));
		assert(counter == 1);
		a.pushBack(a[0]);
		assert(counter == 2);
		a.reserve(5);
		a.pushBack(a[]);

		assert(counter == 4);
		a.insert(1, a[1]);
		assert(counter == 5);
		a.remove(3);
		assert(counter == 4);
		Array!S b = a;
		assert(a[] == b[]);
		assert(counter == 8);
	}
	assert(counter == 0);
}

// type with no @safe/pure/etc-attributes at all and also no opCmp
unittest
{
	struct S
	{
		int* x;
		this(this){ }
		~this(){ }
		bool opEquals(const S b) const { return x is b.x; }
	}

	static assert(hasIndirections!S);
	static assert(hasElaborateDestructor!S);

	S s;
	Array!S a;
	a.pushBack(s);
	a.pushBack([s,s]);
	a.popBack();
	a.reserve(5);
	a.insert(1, s);
	a.remove(2);
	a.resize(3);
	assert(a[] == [s,s,s]);
	Array!S b = a;
}
