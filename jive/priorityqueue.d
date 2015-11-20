module jive.priorityqueue;

private import jive.array;
private import std.algorithm;
private import std.range;
private import std.functional;

/**
 * Priority queue which allows fast access to the smallest element.
 * Implemented as binary heap embedded into a jive.Array.
 * If mutable is true:
 *    - order of values inside queue may be changed (need to call increase/decrease/push accordingly)
 *    - V must be castable to (small, positive) int
 *    - values inside the queue are unique w.r.t. their int representation
 */
struct PriorityQueue(V, alias _pred = "a < b", bool mutable = false)
{
	//////////////////////////////////////////////////////////////////////
	// predicate
	//////////////////////////////////////////////////////////////////////

	static if(__traits(compiles, binaryFun!_pred(V.init, V.init)))
		enum dynamicPred = false;
	else static if(__traits(compiles, _pred.init(1,1)))
		enum dynamicPred = true;
	else
		static assert(false, "invalid predicate in PriorityQueue");

	static if(dynamicPred)
		_pred pred;
	else
		alias pred = binaryFun!_pred;


	//////////////////////////////////////////////////////////////////////
	// constructors
	//////////////////////////////////////////////////////////////////////

	static if(dynamicPred)
	{
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

	// Note: postblit/destructor is automatically generated


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
		arr.resize(0);
		static if(mutable)
			location.resize(0);
	}


	//////////////////////////////////////////////////////////////////////
	// actual functionality
	//////////////////////////////////////////////////////////////////////

	/** returns: first element (i.e. the smallest) */
	ref inout(V) front() inout @property
	{
		return arr.front;
	}

	/** ditto */
	alias front top;

	/**
	 * Remove the first element (i.e. the smallest) from the queue.
	 * returns: the removed element
	 */
	V popFront()
	{
		assert(!empty);
		swap(arr[0], arr.back);
		V r = arr.popBack;
		static if(mutable)
			location[cast(int)r] = -1;
		if(!empty)
			percolateDown(0);
		return r;
	}

	/** ditto */
	alias popFront pop;

	/**
	 * Add an element to the queue.
	 * If modify is true and the element is already in, this is equivalent to update.
	 */
	void pushBack(V value)
	{
		static if(mutable)
		{
			if(location.length <= cast(size_t)value)
				location.resize(cast(size_t)value + 1, -1);
			else if(location[cast(int)value] != -1)
			{
				percolateUp(location[cast(int)value]);
				percolateDown(location[cast(int)value]);
				return;
			}
		}

		arr.pushBack(move(value));
		percolateUp(cast(int)length-1);
	}

	static if(mutable)
	{
		/** check wether a value is currently present in th heap */
		bool opIn_r(V value)
		{
			return cast(int)value < location.length && location[cast(int)value] != -1;
		}

		/** notify the heap that a value has increased in order */
		void increase(V value)
		{
			assert(value in this);
			percolateDown(location[cast(int)value]);
		}

		/** notify the heap that a value has decreased in order */
		void decrease(V value)
		{
			assert(value in this);
			percolateUp(location[cast(int)value]);
		}

		/** notify the heap that a value has changed in order */
		void update(V value)
		{
			assert(value in this);
			percolateUp(location[cast(int)value]);
			percolateDown(location[cast(int)value]);
		}
	}

	/** ditto */
	alias pushBack push;


	//////////////////////////////////////////////////////////////////////
	// internals
	//////////////////////////////////////////////////////////////////////

	private Array!V arr;
	static if(mutable)
		private Array!int location; // -1 for stuff that is not in the heap currently

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
		{
			arr[i] = move(arr[p]);
			static if(mutable)
				location[cast(int)arr[i]] = i;
		}

		arr[i] = move(x);
		static if(mutable)
			location[cast(int)x] = i;
	}

	private void percolateDown(int i)
	{
		auto x = move(arr[i]);

		for(int c = smallerChild(i); c < length && pred(arr[c], x); i = c, c = smallerChild(i))
		{
			arr[i] = move(arr[c]);
			static if(mutable)
				location[cast(int)arr[i]] = i;
		}

		arr[i] = move(x);
		static if(mutable)
			location[cast(int)x] = i;
	}
}
