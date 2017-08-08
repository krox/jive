/**
License: public domain
Authors: Simon Bürger
*/

module jive.unionfind;

import jive.array;
import std.algorithm;

/**
 *  "Disjoint-set data structure". See example for basic usage. This is
 *  beautifula very special purpose data structure. So if you don't know what
 *  this is, don't worry, you don't need it.
 */
struct UnionFind
{
	private Array!uint par;
	private Array!uint size;
	private size_t compCount;

	/** constructor that starts with n disjoint components, numbered 0 to n-1 */
	this(size_t n)
	{
		par.resize(n);
		foreach(i, ref x; par)
			x = cast(uint)i;
		size.resize(n, 1);
		compCount = n;
	}

	private int root(int a)
	{
		while(par[a] != a)
			a = par[a] = par[par[a]];
		return a;
	}

	private int root(int a) const
	{
		while(par[a] != a)
			a = par[a];
		return a;
	}

	size_t length() const pure nothrow @property
	{
		return par.length;
	}

	/**
	 * Returns: number of components
	 */
	size_t nComps() const pure nothrow @property
	{
		return compCount;
	}

	/**
	 * Join the components of elements a and b.
	 * Returns: true if newly joint, false if they already were joined.
	 */
	bool join(int a, int b)
	{
		a = root(a);
		b = root(b);
		if(a == b)
			return false;
		if(size[a] < size[b])
			swap(a, b);
		par[b] = a;
		size[a] += size[b];
		compCount--;
		return true;
	}

	/** Join components of a[0]..a[$-1] into one */
	void join(const int[] as)
	{
		if(as.length == 0)
			return;
		foreach(a; as[1..$])
			join(as[0], a);
	}

	/** Returns: true if a and b are currently joined, false if not */
	bool isJoined(int a, int b) const
	{
		return root(a) == root(b);
	}

	/** Returns: size of the component which a belongs to */
	uint compSize(uint a) const
	{
		return size[root(a)];
	}

	/**
	 * Returns: Array of size `.length` such that each connected component
	 *          has a unique number between 0 and .nComps+1
	 *
	 * If `minSize > 1`, all elements in components smaller than minSize
	 * are ignored and indicated as `-1` in the output.
	 */
	Array!int components(int minSize = 1) const
	{
		Array!int comp;
		comp.resize(par.length, -1);

		int count;
		for(int i = 0; i < par.length; ++i)
			if(par[i] == i && size[i] >= minSize)
				comp[i] = count++;

		for(int i = 0; i < par.length; ++i)
			comp[i] = comp[root(i)];

		return comp;
	}
}

///
unittest
{
	auto a = UnionFind(8);
	assert(a.nComps == 8); // everything is disconnected in the beginning

	a.join(0,1);
	a.join(2,3);
	a.join(3,5);

	assert(a.isJoined(2,5)); // joining is transitive
	assert(a.nComps == 5);
	assert(a.components[] == [0,0,1,1,2,1,3,4]);
}
