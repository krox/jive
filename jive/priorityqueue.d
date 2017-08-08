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
	mixin PredicateHelper!(_pred, V);

	//////////////////////////////////////////////////////////////////////
	// constructors
	//////////////////////////////////////////////////////////////////////

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


	//////////////////////////////////////////////////////////////////////
	// metrics
	//////////////////////////////////////////////////////////////////////

	/** returns: true if set is empty */
	bool empty() const @property @safe
	{
		return arr.empty;
	}

	/** returns: number of elements in the set */
	size_t length() const @property @safe
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


	//////////////////////////////////////////////////////////////////////
	// actual functionality
	//////////////////////////////////////////////////////////////////////

	/** returns: first element (i.e. the smallest) */
	ref inout(V) front() inout @property
	{
		return arr.front;
	}

	/**
	 * Remove the first element (i.e. the smallest) from the queue.
	 * returns: the removed element
	 */
	V pop()
	{
		assert(!empty);
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


	//////////////////////////////////////////////////////////////////////
	// internals
	//////////////////////////////////////////////////////////////////////

	private Array!V arr;

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


unittest
{
	// custom predicate turns a min-heap into a max-heap
	PriorityQueue!(int, "a > b") q;
	q.push([7,9,2,3,4,1,6,5,8,0]);

	int i = 9;
	while(!q.empty)
		assert(q.pop == i--);
}

unittest
{
	// custom comparator that can contain state
	struct Compare
	{
		bool opCall(int a, int b)
		{ return a < b; }
	}

	Compare cmp;
	auto q = PriorityQueue!(int, Compare)(cmp);
	q.push([7,9,2,3,4,1,6,5,8,0]);
	int i = 0;
	while(!q.empty)
		assert(q.pop == i++);
}
