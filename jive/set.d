/**
License: public domain
Authors: Simon Bürger
*/

module jive.set;

import std.algorithm;
import std.range;

/*
 *  TODO:
 *    - statically check that V is indeed hashable (otherwise typeid(V).getHash(&v) will produce garbage)
 *    - do some hash-scrambling to avoid some trivial worst cases
 *    - dont store the hash explicitly for trivially hashable objects (such as int)
 *    - postblit should decrease table size when appropriate
 *    - using T != V in find/opIn_r/remove is possibly unsafe, because it relies on compatible hash functions
 *    - use something smarter than linked lists for the buckets to improve worst-case
 */

/**
 * An unordered set. Internally a hash table. Value-semantics.
 */
struct Set(V)
{
	/** element inside the hash-table */
	private static struct Node
	{
		Node* next;
		hash_t hash;
		V value;
	}

	private Node*[] table;        // the hash-table itself
	private size_t count;         // element count for O(1)-length


	///////////////////////////////////////////////////////////////////
	// constructors
	//////////////////////////////////////////////////////////////////////

	/** constructor that gets content from arbitrary range */
	this(Stuff)(Stuff data)
		if(isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		if(hasLength!Stuff)
			reserve(something);

		foreach(ref x; data)
			add(x);
	}

	/** post-blit that does a full copy */
	this(this)
	{
		static Node* dupNode(Node* node)
		{
			if(node is null)
				return null;
			return new Node(dupNode(node.next), node.hash, node.value);
		}

		table = table.dup; // TODO: use smaller table if sufficient
		foreach(ref bucket; table)
			bucket = dupNode(bucket);
	}


	////////////////////////////////////////////////////////////////
	// metrics
	//////////////////////////////////////////////////////////////////////

	/** returns: true if set is empty */
	bool empty() const @property nothrow @safe
	{
		return count == 0;
	}

	/** returns: number of elements in the set */
	size_t length() const @property nothrow @safe
	{
		return count;
	}

	/**
	 * Resize hashtable such that the set can contain minSize elements without
	 * further resizing. Note that allocation still occurs on addition, even
	 * after using reserve.
	 */
	void reserve(size_t size)
	{
		if(size <= table.length)
			return;

		foreach(prime; primeList)
			if(prime >= size)
			{
				size = prime;
				break;
			}

		auto old = table;
		table = new Node*[size];

		foreach(n; old)
			while(n !is null)
			{
				auto m = n;
				n = n.next;

				auto index = m.hash % table.length;
				m.next = table[index];
				table[index] = m;
			}

		delete old;
	}


	//////////////////////////////////////////////////////////////////////
	// finding, reading
	//////////////////////////////////////////////////////////////////////

	/** private helper, null if not found */
	package inout(Node)* findNode(T)(auto ref const(T) value) inout
		if(is(typeof(T.init == V.init)))
	{
		if(table.length == 0)	// the '%' breaks on zero length, so check for it
			return null;

		auto hash = typeid(T).getHash(&value);
		auto index = hash % table.length;

		for(inout(Node)* node = table[index]; node !is null; node = node.next)
			if(node.hash == hash)
				if(node.value == value)
					return node;
		return null;
	}

	/** returns: pointer to value inside set, null if not found */
	inout(V)* find(T)(auto ref const(T) value) inout
		if(is(typeof(T.init == V.init)))
	{
		auto node = findNode(value);
		if(node is null)
			return null;
		return &node.value;
	}

	/** returns: true if value is found in the set */
	bool opIn_r(T)(auto ref const(T) value) const
		if(is(typeof(T.init == V.init)))
	{
		return findNode(value) !is null;
	}


	//////////////////////////////////////////////////////////////////////
	// add, remove
	//////////////////////////////////////////////////////////////////////

	/**
	 * Add an element to the set.
	 * returns: true if new element was added, false if not (due to duplicate already present)
	 */
	bool add(V value)
	{
		reserve(count+1);

		auto hash = typeid(V).getHash(&value);
		auto index = hash % table.length;

		// check if element already exists
		for(auto node = table[index]; node !is null; node = node.next)
			if(node.hash == hash)
				if(node.value == value)
					return false;

		// add new element
		table[index] = new Node(table[index], hash, move(value));
		++count;
		return true;
	}

	/**
	 * Add elements from a range to the set.
	 * returns: number of elements added
	 */
	size_t add(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		if(hasLength!Stuff)
			reserve(count + data.length); // might be too much due to duplicates, but typically it should be a good idea

		size_t r = 0;
		foreach(x; data)
			if(add(x))
				++r;
		return r;
	}

	/**
	 * Remove an element from the set.
	 * returns: true if removed, false if not found
	 */
	bool remove(T)(auto ref const(T) value)
		if(is(typeof(T.init == V.init)))
	{
		if(table.length == 0)	// the '%' breaks on zero length, so check for it
			return false;

		auto hash = typeid(T).getHash(&value);
		auto index = hash % table.length;

		for(Node** node = &table[index]; *node !is null; node = &(*node).next)
			if((*node).hash == hash)
				if((*node).value == value)
				{
					Node* x = *node;
					*node = (*node).next;
					delete x;
					--count;
					return true;
				}

		return false;
	}

	/**
	 * Remove multiple elements from the set.
	 * returns: number of elements removed
	 */
	size_t remove(Stuff)(Stuff data)
		if(!is(Stuff:V) && isInputRange!Stuff && is(ElementType!Stuff:V))
	{
		size_t r = 0;
		foreach(x; data) // TODO: 'ref' ?
			if(remove(x))
				++r;
		return r;
	}


	//////////////////////////////////////////////////////////////////////
	// Traversal
	//////////////////////////////////////////////////////////////////////

	/**
	 * Range types for iterating over elements of the set.
	 * Implements std.range.isForwardRange
	 */
	alias Range = .Range!(V, Node);
	alias ConstRange = .Range!(const(V), const(Node));
	alias ImmutableRange = .Range!(immutable(V), immutable(Node));

	/** default range, iterates over everything in arbitrary order */
	Range opSlice()
	{
		return Range(table);
	}

	/** ditto */
	ConstRange opSlice() const
	{
		return ConstRange(table.dup); // TODO: remove the '.dup'
	}

	/** ditto */
	ImmutableRange opSlice() immutable
	{
		return ImmutableRange(table.dup); // TODO: remove the '.dup'
	}
}

/** basic usage */
unittest
{
	Set!int a;
	assert(a.add(1) == true);
	assert(a.add([4,2,3,1,5]) == 4);
	assert(a.remove(7) == false);
	assert(a.remove([1,1,8,2]) == 2);
	assert(a.remove(3) == true);
	assert(a.length == 2);
}

unittest
{
	Set!int a;
	a.add(iota(0,10));
	const Set!int b = cast(const)a;
	immutable Set!int c = cast(immutable)a;
	assert(equal(b[], a[]));
	assert(equal(c[], a[]));
	assert(isForwardRange!(Set!int.Range));
	assert(isForwardRange!(Set!int.ConstRange));
	assert(isForwardRange!(Set!int.ImmutableRange));
}

//////////////////////////////////////////////////////////////////////
/// internals of the hash-table
//////////////////////////////////////////////////////////////////////

private struct Range(V, Node)
{
	private Node* curr;
	private Node*[] table;

	private this(Node*[] _table)
	{
		table = _table;
		while(!table.empty && table[0] is null)
			table.popFront;
		if(!table.empty)
		{
			curr = table.front;
			table.popFront;
		}
	}

	bool empty() const
	{
		return curr is null;
	}

	ref V front()
	{
		return curr.value;
	}

	void popFront()
	{
		curr = curr.next;
		if(curr !is null)
			return;
		while(!table.empty && table[0] is null)
			table.popFront;
		if(!table.empty)
		{
			curr = table.front;
			table.popFront;
		}
	}

	Range save()
	{
		return this;
	}
}

/** prime numbers used as hash-table sizes */
static if(size_t.sizeof >= long.sizeof)
private static immutable size_t[] primeList = [
	7,13,31,61,
	127,251,509,1021,
	2039,4093,8191,16381,
	32749,65521,131071,262139,
	524287,1048573,2097143,4194301,
	8388593,16777213,33554393,67108859,
	134217689,268435399,536870909,1073741789,
	2147483647,4294967291,8589934583,17179869143,
	34359738337,68719476731,137438953447,274877906899,
	549755813881,1099511627689,2199023255531,4398046511093,
];

else
private static immutable size_t[] primeList = [
	7,13,31,61,
	127,251,509,1021,
	2039,4093,8191,16381,
	32749,65521,131071,262139,
	524287,1048573,2097143,4194301,
	8388593,16777213,33554393,67108859,
	134217689,268435399,536870909,1073741789,
];
