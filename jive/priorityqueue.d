module jive.priorityqueue;

private import jive.array;
private import std.algorithm;
private import std.range;

/**
 * Priority queue which allows fast access to the smallest element.
 * Implemented as binary heap embedded into a jive.Array.
 */
struct PriorityQueue(V)
{
	//////////////////////////////////////////////////////////////////////
	// constructors
	//////////////////////////////////////////////////////////////////////

	/** constructor that gets content from arbitrary range */
	this(Stuff)(Stuff data)
		if(isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		static if(hasLength!Stuff)
			arr.reserve(data.length);

		foreach(ref x; data)
			push(x);
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
		swap(arr[0], arr.back);
		V r = arr.popBack;

		size_t pos = 0;
		while(2*pos+2 < length)	// while there are two children
		{
			size_t child = 2*pos+1;
			if(arr[child] > arr[child+1])
				++child;

			if(arr[pos] <= arr[child])
				break;

			swap(arr[pos], arr[child]);
			pos = child;
		}

		if(pos*2+1 < length)	// if there is one more single child
			if(arr[pos*2+1] < arr[pos])
				swap(arr[pos], arr[pos*2+1]);

		return r;
	}

	/** ditto */
	alias popFront pop;

	/**
	 * Add an element to the queue.
	 */
	void pushBack(V value)
	{
		ptrdiff_t pos = length;	// initial index of new element
		arr.pushBack(move(value));

		while(pos > 0)
		{
			ptrdiff_t parent = (pos-1)/2;
			if(arr[parent] <= arr[pos])
				break;

			swap(arr[parent], arr[pos]);
			pos = parent;
		}
	}

	/** ditto */
	alias pushBack push;


	//////////////////////////////////////////////////////////////////////
	// internals
	//////////////////////////////////////////////////////////////////////

	private Array!V arr;
}
