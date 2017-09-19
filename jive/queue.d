/**
License: public domain
Authors: Simon Bürger
*/

module jive.queue;

import core.exception : RangeError;
import core.stdc.string : memmove, memcpy, memset;
import std.algorithm;
import std.conv : emplace;
import std.range;
import std.traits;
import jive.internal;


/**
 *  Array structure that allows addition/deletion at both ends.
 *
 *  Intended to be used as a FIFO-queue or as a stack by combining
 *  `pushFront`/`pushBack` and `popFront`/`popBack` appropriately. Implemented
 *  as a circular buffer inside a continuous block of memory that is
 *  automatically expanded as necessary, similar to jive.Array.
 */
struct Queue(V)
{
	private V* _ptr = null;			// unused elements are undefined
	private size_t _capacity = 0;	// size of buf
	private size_t _length = 0;		// used size
	private size_t _left = 0;		// offset into buffer

	/** constructor that gets content from arbitrary range */
	this(Stuff)(Stuff stuff)
		if(isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(_length + stuff.length);

		foreach(ref x; stuff)
			pushBack(x);
	}

	/** post-blit that does a full copy */
	this(this)
	{
		auto newPtr = jiveMalloc!V(_length);

		static if(hasElaborateCopyConstructor!V)
		{
			for(size_t i = 0; i < _length; ++i)
				emplace(newPtr + i, this[i]);
		}
		else
		{
			if(_left + _length <=  _capacity)
			{
				memcpy(newPtr, _ptr + _left, V.sizeof * _length);
			}
			else
			{
				memcpy(newPtr, _ptr + _left, V.sizeof * (_capacity - _left));
				memcpy(newPtr + _capacity - _left, _ptr, V.sizeof * (_length - _capacity + _left));
			}
		}
		_ptr = newPtr;
		_capacity = _length;
		_left = 0;
	}

	/** destructor */
	~this()
	{
		static if (hasElaborateDestructor!V)
			foreach (ref x; this[])
				destroy(x);

		jiveFree(_ptr);
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

	/**
	 * Allocated heap memory in bytes.
	 * This is recursive if V has a `.memUsage` property. Otherwise it is equal
	 * to `V.sizeof * capacity`
	 */
	size_t memUsage() const pure nothrow @property @trusted
	{
		size_t r = V.sizeof*_capacity;
		static if(hasMember!(V, "memUsage"))
			for(size_t i = 0; i < _length; ++i)
				r += this[i].memUsage;
		return r;
	}

	/** make sure this structure can contain given number of elements without further allocs */
	void reserve(size_t newCap, bool overEstimate = false) nothrow @trusted
	{
		if(newCap <= _capacity)
			return;

		if(overEstimate)
			newCap = max(newCap, 2*_capacity);

		auto newPtr = jiveMalloc!V(newCap);
		if(_left + _length <=  _capacity)
		{
			memcpy(newPtr, _ptr + _left, V.sizeof * _length);
		}
		else
		{
			memcpy(newPtr, _ptr + _left, V.sizeof * (_capacity - _left));
			memcpy(newPtr + _capacity - _left, _ptr, V.sizeof * (_length - _capacity + _left));
		}

		static if(hasIndirections!V)
			memset(newPtr + _length, 0, V.sizeof * (newCap - _length)); // prevent false pointers

		jiveFree(_ptr);
		_ptr = newPtr;
		_capacity = newCap;
		_left = 0;
	}

	/** default range */
	auto opSlice() nothrow pure @trusted
	{
		if(_left + _length <= _capacity)
			return chain(
					_ptr[_left .. _left + _length],
					_ptr[0 .. 0]
					);
		else
			return chain(
					_ptr[_left .. _capacity],
					_ptr[0 .. _left + _length - _capacity]
					);
	}

	/** ditto */
	auto opSlice() const nothrow pure @trusted
	{
		if(_left + _length <= _capacity)
			return chain(
					_ptr[_left .. _left + _length],
					_ptr[0 .. 0]
					);
		else
			return chain(
					_ptr[_left .. _capacity],
					_ptr[0 .. _left + _length - _capacity]
					);
	}

	/** ditto */
	auto opSlice() immutable nothrow pure @trusted
	{
		if(_left + _length <= _capacity)
			return chain(
					_ptr[_left .. _left + _length],
					_ptr[0 .. 0]
					);
		else
			return chain(
					_ptr[_left .. _capacity],
					_ptr[0 .. _left + _length - _capacity]
					);
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(size_t i) inout pure nothrow @trusted
	{
		if(boundsChecks && i >= _length)
			assert(false, boundsCheckMsg!(file, line));
		return _ptr[(_left + i) % _capacity];
	}

	/** first element, same as this[0] */
	ref inout(V) front(string file = __FILE__, int line = __LINE__)() inout pure nothrow @property
	{
		if(boundsChecks && empty)
			assert(false, boundsCheckMsg!(file, line));
		return _ptr[_left];
	}

	/** last element, same as this[$-1] */
	ref inout(V) back(string file = __FILE__, int line = __LINE__)() inout pure nothrow @property
	{
		if(boundsChecks && empty)
			assert(false, boundsCheckMsg!(file, line));
		return _ptr[(_left + _length - 1) % _capacity];
	}

	/** add an element to the front of the queue */
	void pushFront(V val) @trusted
	{
		reserve(_length + 1, true);
		++_length;
		if(_left == 0)
			_left = _capacity-1;
		else
			--_left;
		moveEmplace(val, front);
	}

	/** add multiple elements to the front of the queue */
	void pushFront(Stuff)(Stuff stuff)
		if(isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(_length + stuff.length, true);

		foreach(ref x; stuff)
			pushFront(x);
	}

	/** add an element to the back of the queue */
	void pushBack(V val) @trusted
	{
		reserve(_length + 1, true);
		++_length;
		moveEmplace(val, back);
	}

	/** add multiple elements to the back of the queue */
	void pushBack(Stuff)(Stuff stuff)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(_length + stuff.length, true);

		foreach(ref x; stuff)
			pushBack(x);
	}

	/** removes first element of the queue and returns it */
	V popFront(string file = __FILE__, int line = __LINE__)() @trusted
	{
		if(boundsChecks && empty)
			assert(false, boundsCheckMsg!(file, line));

		V r = void;
		memcpy(&r, &front(), V.sizeof);
		static if(hasIndirections!V)
			memset(&front(), 0, V.sizeof);
		_left = (_left + 1) % _capacity;
		--_length;
		return r;
	}

	/** removes last element of the queue and returns it */
	V popBack(string file = __FILE__, int line = __LINE__)() @trusted
	{
		if(boundsChecks && empty)
			assert(false, boundsCheckMsg!(file, line));

		V r = void;
		memcpy(&r, &back(), V.sizeof);
		static if(hasIndirections!V)
			memset(&back(), 0, V.sizeof);
		--_length;
		return r;
	}

	/** remove all content but keep allocated memory */
	void clear() @trusted
	{
		// TODO: remove @trusted in case V's destructor is @system
		static if(hasElaborateDestructor!V)
			for(size_t i = 0; i < _length; ++i)
				destroy(this[i]);
		static if(hasIndirections!V)
			memset(_ptr, 0, V.sizeof * _capacity);
		_length = 0;
	}
}

///
/*@nogc*/ nothrow pure @safe unittest
{
	Queue!int a;
	a.pushBack([1,2,3]);
	a.pushFront([4,5,6]);

	assert(equal(a[], [6,5,4,1,2,3]));

	assert(a.popFront == 6);
	assert(a.popBack == 3);

	assert(a.length == 4);
}

// check actual 'circular' buffer
@nogc nothrow pure @safe unittest
{
	Queue!int q;
	q.reserve(3);
	assert(q.capacity == 3);
	assert(q.empty);

	// forward
	q.pushBack(1);
	q.pushBack(2);
	q.pushBack(3);
	assert(q.popFront == 1); q.pushBack(4);
	assert(q.popFront == 2); q.pushBack(5);
	assert(q.popFront == 3); q.pushBack(6);
	assert(q.popFront == 4); q.pushBack(7);
	assert(q[0] == 5);
	assert(q[1] == 6);
	assert(q[2] == 7);

	q.clear();
	assert(q.empty);
	assert(q.capacity == 3);

	// backward
	q.pushFront(1);
	q.pushFront(2);
	q.pushFront(3);
	assert(q.popBack == 1); q.pushFront(4);
	assert(q.popBack == 2); q.pushFront(5);
	assert(q.popBack == 3); q.pushFront(6);
	assert(q.popBack == 4); q.pushFront(7);
	assert(q[$-1] == 5);
	assert(q[$-2] == 6);
	assert(q[$-3] == 7);
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
		Queue!S a;
		assert(counter == 0);
		a.pushBack(S(true));
		assert(counter == 1);
		a.pushFront(a[0]);
		assert(counter == 2);
		a.reserve(5);
		a.pushBack(a[]);

		Queue!S b = a;
		assert(equal(a[], b[]));
		assert(counter == 8);
	}
	assert(counter == 0);
}

// check move-semantics
unittest
{
	struct S3
	{
		int x;
		alias x this;
		this(this) { assert(x == 0); }
	}

	Queue!S3 a;
	a.pushBack(S3(1));
	a.pushBack(S3(2));
	a.pushFront(S3(3));
	a.reserve(5);
	a.popBack();
	a.popFront();
	a[0] = S3(4);
	a.clear();
}

// type with no @safe/pure/etc-attributes
unittest
{
	struct S
	{
		int* x;
		this(this){ }
		~this(){ }
	}

	static assert(hasIndirections!S);
	static assert(hasElaborateDestructor!S);

	S s;
	Queue!S a;
	a.pushBack(s);
	a.pushBack([s,s]);
	a.pushFront(s);
	a.pushFront([s,s]);
	a.popBack();
	a.popFront();
	Queue!S b = a;
	a.clear();
	assert(equal(b[], [s,s,s,s]));
}
