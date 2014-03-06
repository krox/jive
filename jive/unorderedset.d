module jive.unorderedset;

private import std.algorithm;
private import std.range;

// TODO: statically check that V is indeed hashable (otherwise typeid(V).getHash(&v) will produce garbage)

/**
 * An unordered set. Internally a hash table. Value-semantics.
 */
struct UnorderedSet(V)
{
	//////////////////////////////////////////////////////////////////////
	// internals / debugging
	//////////////////////////////////////////////////////////////////////

	/** primes taken from some phobos assoc-array implementation */
	private static immutable size_t[] primeList = [
		           97U,           389U,          1_543U,         6_151U,
		       24_593U,        98_317U,        393_241U,     1_572_869U,
		    6_291_469U,    25_165_843U,    100_663_319U,   402_653_189U,
		1_610_612_741U, 4_294_967_291U,//8_589_934_513U, 17_179_869_143U
	];

	/** element inside the hash-table */
	private static struct Node
	{
		Node* next;
		hash_t hash; // TODO: dont explicitly store the hash if V has a trivial hash function
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
	 * further resizing.
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

	// TODO: using T != V in find/opIn_r/remove is quite unsafe, because it relies on toHash functions to be compatible
	/** private helper, null if not found */
	package inout(Node)* find(T)(const ref T value) inout
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

	/** returns: true if value is found in the set */
	bool opIn_r(T)(const T value) const
		if(is(typeof(T.init == V.init)))
	{
		return opIn_r(value);
	}

	/** ditto */
	bool opIn_r(T)(const ref T value) const
		if(is(typeof(T.init == V.init)))
	{
		return find(value) !is null;
	}


	//////////////////////////////////////////////////////////////////////
	// add, remove
	//////////////////////////////////////////////////////////////////////

	/**
	 * Add an element to the set.
	 * returns: true if added, false if not (due to duplicate already present)
	 */
	bool add(V value)
	{
		reserve(count+1);

		auto hash = typeid(V).getHash(&value);
		auto index = hash % table.length;

		for(auto node = table[index]; node !is null; node = node.next)
			if(node.hash == hash)
				if(node.value == value)
				{
					node.value = value; // useless for most types V, but important for implementing a map
					return false;
				}

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
	bool remove(T)(const(T) v)
		if(is(typeof(T.init == V.init)))
	{
		return remove(v);
	}

	/** ditto */
	bool remove(T)(ref const(T) value)
		if(is(typeof(T.init == V.init)))
	{
		static bool removeRec(ref const(T) v, hash_t h, ref Node* n)
		{
			if(n is null)
				return false;
			if(n.hash == h)
				if(n.value == v)
				{
					auto m = n;
					n = n.next;
					delete m;
					return true;
				}
			return removeRec(v, h, n.next);
		}

		if(table.length == 0)	// the '%' breaks on zero length, so check for it
			return false;

		auto hash = typeid(T).getHash(&value);
		auto index = hash % table.length;

		if(!removeRec(value, hash, table[index]))
			return false;
		--count;
		return true;
	}


	//////////////////////////////////////////////////////////////////////
	// Traversal
	//////////////////////////////////////////////////////////////////////

	/**
	 * Range type for iterating over elements of the set.
	 * Might be invalidated by add/remove.
	 * Implements std.range.isForwardRange
	 */
	static struct Range
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

		bool empty() const @property
		{
			return curr is null;
		}

		ref inout(V) front() inout @property
		{
			return curr.value;
		}

		void popFront() @property
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

		Range save() @property
		{
			return this;
		}
	}

	/** default range, iterates over everything in arbitrary order */
	Range opSlice()
	{
		return Range(table);
	}
}
