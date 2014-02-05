module jive.unionfind;

import jive.array;
import std.algorithm : swap, move;
import std.typecons : tuple;

struct UnionFind
{
	private Array!uint par;
	private Array!uint size;

	this(size_t n)
	{
		par.resize(n);
		foreach(i, ref x; par)
			x = cast(uint)i;
		size.resize(n, 1);
	}

	private int root(int a)
	{
		while(par[a] != a)
			a = par[a] = par[par[a]];
		return a;
	}

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
		return true;
	}

	void join(const int[] as)
	{
		if(as.length == 0)
			return;
		foreach(a; as[1..$])
			join(as[0], a);
	}

	bool isJoined(int a, int b)
	{
		return root(a) == root(b);
	}

	uint compSize(uint a)
	{
		return size[root(a)];
	}

	auto components()
	{
		Array!int comp;
		comp.resize(par.length);

		int count;
		for(int i = 0; i < par.length; ++i)
			if(par[i] == i)
				comp[i] = count++;

		for(int i = 0; i < par.length; ++i)
			comp[i] = comp[root(i)];

		return tuple(count, move(comp));
	}
}
