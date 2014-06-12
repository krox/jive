module math.rational;

private import std.string : toStringz;
private import std.algorithm : move, swap;

import math.integer;


/**
 * Rational numbers. Based on math.integer.
 */
struct Rational
{
	public Integer num, denom;
	// invariants:
	// denom > 0
	// gcd(num, denom) == 1

	/** constructor for given value */
	this(int v)
	{
		num = Integer(v);
		denom = Integer(1);
	}

	/** ditto */
	this(int n, int d)
	{
		this(Integer(n), Integer(d));
		// TODO: cancel factors before creating Integer
	}

	/** ditto */
	this(Integer n, Integer d)
	{
		if(d == 0)
			throw new Exception("rational with denominator = 0");
		auto g = gcd(n,d);
		if(g != 1)
		{
			n = n / g;
			d = d / g;
		}
		if(d < 0)
		{
			n = -n;
			d = -d;
		}
		num = n;
		denom = d;
	}

	/** ditto */
	this(Integer v)
	{
		num = v;
		denom = Integer(1);
	}

	/** ditto */
	this(string v)
	{
		assert(false, "FIXME");
	}

	// NOTE: copy constructor and destructor is implicit

	string toString() const @property
	{
		return num.toString ~ "/" ~ denom.toString;
	}

	/** return -1 / 0 / +1, faster than actual compare */
	int sign() const
	{
		return num.sign;
	}

	Rational opUnary(string op)() const
		if(op == "-")
	{
		return Rational(-num, denom);
	}

	/** replace this with 1/this (nan if this==0) */
	Rational inverse() const
	{
		if(num == 0)
			throw new Exception("tried to invert rational 0");

		if(num < 0)
			return Rational(-denom, -num);
		else
			return Rational(denom, num);
	}

	Rational opBinary(string op)(Integer b) const
	{
		     static if(op == "+") return Rational(num + denom*b, denom);
		else static if(op == "-") return Rational(num - denom*b, denom);
		else static if(op == "*") return Rational(num*b, denom);
		else static if(op == "/") return Rational(num, denom*b);
		else static assert(false, "binary '"~op~"' is not defined");
	}

	Rational opBinary(string op)(Rational b) const
	{
		static if(op == "+")
			return Rational(num*b.denom + b.num*denom, denom*b.denom);
		else static if(op == "-")
			return Rational(num*b.denom - b.num*denom, denom*b.denom);
		else static if(op == "*")
			return Rational(num*b.num, denom*b.denom);
		else static if(op == "/")
			return Rational(num*b.denom, denom*b.num);
		else static assert(false, "binary '"~op~"' is not defined");
	}

	/** round to integer towards -infinity */
	Integer floor() const
	{
		return num / denom;
	}

	bool opEquals(int b) const
	{
		return denom == 1 && num == b;
	}

	bool opEquals(Integer b) const
	{
		return denom == 1 && num == b;
	}

	bool opEquals(Rational b) const
	{
		return num == b.num && denom == b.denom; // both numbers need to be normalized for this
	}

	int opCmp(Rational b) const
	{
		return (num*b.denom).opCmp(denom*b.num); // denominators need to be positive for this
	}
}
