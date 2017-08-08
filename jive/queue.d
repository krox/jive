/**
License: public domain
Authors: Simon Bürger
*/

module jive.queue;

import jive.internal;
import core.exception : RangeError;
import std.range;
import std.algorithm;


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
	private V[] buf;
	private size_t left;
	private size_t count;

	/** post-blit that does a full copy */
	this(this)
	{
		buf = buf.dup; // TODO: shrink it if possible?
	}

	/** check for emptiness */
	bool empty() const pure nothrow @property @safe
	{
		return count == 0;
	}

	/** number of elements */
	size_t length() const pure nothrow @property @safe
	{
		return count;
	}

	/** ditto */
	size_t opDollar() const pure nothrow @property @safe
	{
		return count;
	}

	/** number of elements this structure can hold without further allocations */
	size_t capacity() const pure nothrow @property @safe
	{
		return buf.length;
	}

	/** make sure this structure can contain given number of elements without further allocs */
	void reserve(size_t newCap, bool overEstimate = false)
	{
		if(newCap <= capacity)
			return;

		if(overEstimate)
			newCap = max(newCap, 2*capacity);

		auto newBuf = new V[newCap];
		if(left + count <= buf.length)
			moveAll(buf[left..left+count], newBuf[0..count]);
		else
		{
			moveAll(buf[left..$], newBuf[0..buf.length-left]);
			moveAll(buf[0..left+count-$], newBuf[buf.length-left..count]);
		}
		delete buf;
		buf = newBuf;
		left = 0;
	}

	/** removes all elements, but keeps the allocated memory */
	void clear() pure nothrow @safe
	{
		left = 0;
		count = 0;
	}

	/** default range */
	auto opSlice() nothrow pure @safe
	{
		if(left+count <= length)
			return chain(
					buf[left .. min($, left+count)],
					buf[0 .. 0]
					);
		else
			return chain(
					buf[left .. $],
					buf[0 .. left+count-$]
					);
	}

	/** ditto */
	auto opSlice() nothrow pure @safe const
	{
		if(left+count <= length)
			return chain(
					buf[left .. min($, left+count)],
					buf[0 .. 0]
					);
		else
			return chain(
					buf[left .. $],
					buf[0 .. left+count-$]
					);
	}

	/** ditto */
	auto opSlice() nothrow pure @safe immutable
	{
		if(left+count <= length)
			return chain(
					buf[left .. min($, left+count)],
					buf[0 .. 0]
					);
		else
			return chain(
					buf[left .. $],
					buf[0 .. left+count-$]
					);
	}

	/** indexing */
	ref inout(V) opIndex(string file = __FILE__, int line = __LINE__)(size_t i) inout pure
	{
		if(boundsChecks && i >= length)
			throw new RangeError(file, line);
		return buf[(left + i) % $];
	}

	/** first element, same as this[0] */
	ref inout(V) front(string file = __FILE__, int line = __LINE__)() inout pure nothrow
	{
		return this.opIndex!(file, line)(0);
	}

	/** last element, same as this[$-1] */
	ref inout(V) back(string file = __FILE__, int line = __LINE__)() inout pure nothrow
	{
		return this.opIndex!(file, line)(length-1);
	}

	/** add some new elements to the front */
	void pushFront(V val)
	{
		reserve(count + 1, true);
		++count;
		if(left == 0)
			left = buf.length-1;
		else
			--left;
		this.front = move(val);
	}

	/** ditto */
	void pushFront(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(count + data.length, true);

		foreach(ref x; data)
			pushFront(x);
	}

	/** add some new elements to the back */
	void pushBack(V val)
	{
		reserve(count + 1, true);
		++count;
		this.back = move(val);
	}

	/** ditto */
	void pushBack(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			reserve(count + data.length, true);

		foreach(ref x; data)
			pushBack(x);
	}

	/** removes and returns the first element */
	V popFront(string file = __FILE__, int line = __LINE__)()
	{
		if(boundsChecks && empty)
			throw new RangeError(file, line);

		auto r = move(this.front);
		left = (left + 1) & buf.length;
		--count;
		return r;
	}

	/** removes and returns the last element */
	V popBack(string file = __FILE__, int line = __LINE__)()
	{
		if(boundsChecks && empty)
			throw new RangeError(file, line);

		auto r = move(this.back);
		--count;
		return r;
	}

	hash_t toHash() const nothrow @trusted
	{
		hash_t h = length*17;
		foreach(ref x; this[])
			h = 19*h+23*typeid(V).getHash(&x);
		return h;
	}

	bool opEquals(const ref Queue other) const
	{
		return equal(this[], other[]);
	}

	int opCmp(const ref Queue other) const
	{
		return cmp(this[], other[]);
	}
}

///
unittest
{
	Queue!int a;
	a.pushBack([1,2,3]);
	a.pushFront([4,5,6]);

	assert(equal(a[], [6,5,4,1,2,3]));

	assert(a.popFront == 6);
	assert(a.popBack == 3);

	assert(a.length == 4);
}
