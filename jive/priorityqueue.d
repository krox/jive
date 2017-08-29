/**
License: public domain
Authors: Simon Bürger
*/
module jive.priorityqueue;

import jive.internal;
import jive.array;
import std.algorithm;
import std.range;
import std.functional;

/**
 * Priority queue which allows fast access to the smallest element.
 * Implemented as binary heap embedded into a jive.Array.
 */
struct PriorityQueue(V, alias _pred = "a < b")
{
	// NOTE: attributes (pure/nothrow/...) depend on the predicate and will
	//       be inferred by the compiler. No need to state them explicitly

	private Array!V arr;

	mixin PredicateHelper!(_pred, V);

	static if(dynamicPred)
	{
		@disable this();

		this(_pred p)
		{
			this.pred = p;
		}

		/** constructor that gets content from arbitrary range */
		this(Stuff)(_pred p, Stuff data)
			if(isInputRange!Stuff && is(ElementType!Stuff:V))
		{
			this.pred = p;

			static if(hasLength!Stuff)
				arr.reserve(data.length);

			foreach(ref x; data)
				push(x);
		}
	}
	else
	{
		/** constructor that gets content from arbitrary range */
		this(Stuff)(Stuff data)
			if(isInputRange!Stuff && is(ElementType!Stuff:V))
		{
			static if(hasLength!Stuff)
				arr.reserve(data.length);

			foreach(ref x; data)
				push(x);
		}
	}

	/** returns: true if set is empty */
	bool empty() const @property
	{
		return arr.empty;
	}

	/** returns: number of elements in the set */
	size_t length() const @property
	{
		return arr.length;
	}

	/** Allocate memory for s elements. Does nothing if s < length. */
	void reserve(size_t s)
	{
		arr.reserve(s);
	}

	/** removes all elements but keeps allocated memory */
	void clear()
	{
		arr.clear();
	}

	/** clear the heap and return all elements (unordered!) */
	Array!V release()
	{
		return move(arr);
	}

	/** returns: first element (i.e. the smallest) */
	ref inout(V) front() inout @property
	{
		return arr.front;
	}

	/**
	 * Remove the first element (i.e. the smallest) from the queue.
	 * returns: the removed element
	 */
	V pop(string file = __FILE__, int line = __LINE__)()
	{
		if(boundsChecks && empty)
			assert(false, boundsCheckMsg!(file, line));
		swap(arr[0], arr.back);
		V r = arr.popBack;
		if(!empty)
			percolateDown(0);
		return r;
	}

	/** ditto */
	alias popFront = pop;

	/**
	 * Add an element to the queue.
	 */
	void push(V value)
	{
		arr.pushBack(move(value));
		percolateUp(cast(int)length-1);
	}

	/** Add multiple elements to the queue. */
	void push(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			arr.reserve(length + data.length, true);

		foreach(ref x; data)
			pushBack(x);
	}

	alias pushBack = push;

	/* internals (private) */

	private int parent(int i) { return (i-1)/2; }
	private int left(int i) { return 2*i+1; }
	private int right(int i) { return 2*i+2; }

	private int smallerChild(int i)
	{
		if(right(i) < length && pred(arr[right(i)], arr[left(i)]))
			return right(i);
		else
			return left(i);
	}

	private void percolateUp(int i)
	{
		auto x  = move(arr[i]);

		for(int p = parent(i); i != 0 && pred(x, arr[p]); i = p, p = parent(i))
			arr[i] = move(arr[p]);

		arr[i] = move(x);
	}

	private void percolateDown(int i)
	{
		auto x = move(arr[i]);

		for(int c = smallerChild(i); c < length && pred(arr[c], x); i = c, c = smallerChild(i))
			arr[i] = move(arr[c]);

		arr[i] = move(x);
	}
}

/// basic usage
@nogc nothrow pure @safe unittest
{
	// custom predicate turns a min-heap into a max-heap
	PriorityQueue!int q;
	q.push(7);
	q.push(3);
	q.push(5);
	q.push(3);

	assert(q.length == 4); // note that duplicates are kept

	assert(q.pop == 3);
	assert(q.pop == 3);
	assert(q.pop == 5);
	assert(q.pop == 7);

	assert(q.empty);
}

/// custom predicate (without state)
/*@nogc*/ nothrow pure @safe unittest
{
	// custom predicate turns a min-heap into a max-heap
	PriorityQueue!(int, "a > b") q;
	q.push(7);

	q.push([9,2,8,3,4,1,6,5,8,0]);

	assert(q.pop == 9);
	assert(q.pop == 8);
	assert(q.pop == 8);
	assert(q.pop == 7);
	q.push(18);
	assert(q.pop == 18);
	assert(q.pop == 6);
	assert(q.pop == 5);
	q.clear;
	assert(q.empty);
}

/// custom predicate (with state)
unittest
{
	// sometimes, you need a custom predicate/comparator that contains state.
	// For example this int-comparator puts one selected item first, followed
	// by all other integers in their usual order.
	struct Cmp
	{
		int priority;

		@disable this();

		this(int p)
		{
			this.priority = p;
		}

		// this is understood as a comparison 'a < b'.
		bool opCall(int a, int b)
		{
			if(b == priority)
				return false;
			if(a == priority)
				return true;
			return a < b;
		}
	}

	// the constructor now takes an instance of the comparator
	auto q = PriorityQueue!(int, Cmp)(Cmp(3));

	q.push([2,3,4,1,5,0]);
	assert(q.pop == 3);
	assert(q.pop == 0);
	assert(q.pop == 1);
	assert(q.pop == 2);
	assert(q.pop == 4);
	assert(q.pop == 5);
}

// check move-semantics
unittest
{
	struct S
	{
		int x = -1;
		alias x this;
		this(this)
		{
			// default-constructed objects might be copied, others may not.
			assert(x == -1);
		}
	}

	PriorityQueue!S q;
	q.push(S(2));
	q.push(S(4));
	q.push(S(3));
	q.push(S(1));
	q.push(S(0));
	assert(q.pop == S(0));
	assert(q.pop == S(1));
	assert(q.pop == S(2));
}
