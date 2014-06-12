module math.polynomial;

private import std.algorithm : map, min, max;
private import std.conv : to;
private import std.array : join;
private import std.exception : assumeUnique;

struct Polynomial(T, string _x = "x")
{
	immutable(T)[] coeffs; // highest one is always != 0

	this(immutable(T)[] coeffs)
	{
		while(coeffs.length && coeffs[$-1] == 0)
			coeffs = coeffs[0..$-1];
		this.coeffs = coeffs;
	}

	static if (is(T : Coset!Base, Base))
	{
		// special case constructor for coefficients living in a factor ring
		this(const(int)[] arr, int _mod)
		{
			auto mod = Base(_mod);
			auto r = new T[arr.length];
			for(size_t i = 0; i < r.length; ++i)
				r[i] = T(arr[i],mod);
			this(assumeUnique(r));
		}
	}

	/** power of highest non-zero term. -1 for the 0-polynomial */
	int degree() const @property
	{
		return cast(int)coeffs.length-1;
	}

	string toString() const @property
	{
		if(coeffs.length == 0)
			return "0";

		string s;
		foreach_reverse(i, c; coeffs)
			if(c != 0)
			{
				if(s)
					s ~= " + ";
				if(i == 0 || c != 1)
					s ~= to!string(c);
				if(i >= 1)
					s ~= _x;
				if(i >= 2)
					s ~= "^" ~ to!string(i);
			}
		return s;
	}

	Polynomial opBinary(string op)(Polynomial b) const
		if(op == "+" || op == "-")
	{
		auto r = new T[max(coeffs.length, b.coeffs.length)];
		for(size_t i = 0; i < r.length; ++i)
		{
			if(i < coeffs.length && i < b.coeffs.length)
				r[i] = mixin("this.coeffs[i]"~op~"b.coeffs[i]");
			else if(i < coeffs.length)
				r[i] = this.coeffs[i];
			else
				static if(op == "+")
					r[i] = b.coeffs[i];
				else
					r[i] = -b.coeffs[i];
		}
		return Polynomial(assumeUnique(r));
	}

	Polynomial opBinary(string op)(Polynomial b) const
		if(op == "*")
	{
		if(degree < 0 || b.degree < 0)
			return Polynomial(null);

		auto r = new T[degree + b.degree + 1];

		for(int k = 0; k < r.length; ++k)
		{
			r[k] = coeffs[max(0, k-b.degree)] * b.coeffs[k-max(0, k-b.degree)];
			for(int i = max(0, k-b.degree)+1; i <= min(degree, k); ++i)
				r[k] = r[k] + coeffs[i] * b.coeffs[k-i];
		}

		return Polynomial(assumeUnique(r));
	}

	bool opEquals(Polynomial r) const
	{
		return coeffs[] == r.coeffs[];
	}
}
