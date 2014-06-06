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
		num = v;
		denom = 1;
	}

	/** ditto */
	this(int n, int d)
	{
		num = n;
		denom = d;
		normalize();
	}

	/** ditto */
	this(Integer n, Integer d)
	{
		num = move(n);
		denom = move(d);
		normalize();
	}

	/** ditto */
	this(Integer v)
	{
		num = move(v);
		denom = 1;
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

	/** cancel common factors, make denominator positive and replace * / 0 by nan */
	private void normalize()
	{
		if(denom.sign() == 0)
		{
			num = Integer.nan;
			denom = Integer.nan;
			return;
		}

		cancelCommonFactors(num, denom);

		if(denom.sign() == -1)
		{
			num.negate();
			denom.negate();
		}
	}

	/** return -1 / 0 / +1, faster than actual compare */
	int sign() const
	{
		return num.sign;
	}

	/** replace this with -this */
	void negate()
	{
		num.negate();
	}

	/** replace this with 1/this (nan if this==0) */
	void invert()
	{
		swap(num, denom);

		if(denom.sign() == 0)
		{
			num = Integer.init;
			denom = Integer.init;
		}
		else if(denom.sign() == -1)
		{
			num.negate();
			denom.negate();
		}
	}

	Rational opBinary(string op)(const Integer b) const
	{
		return opBinary!op(b);
	}

	Rational opBinary(string op)(ref const Integer b) const
	{
		     static if(op == "+") return Rational(num + denom*b, denom);
		else static if(op == "-") return Rational(num - denom*b, denom);
		else static if(op == "*") return Rational(num*b, denom);
		else static if(op == "/") return Rational(num, denom*b);
		else static assert(false, "binary '"~op~"' is not defined");
	}

	Rational opBinary(string op)(const Rational b) const
	{
		return opBinary!op(b);
	}

	Rational opBinary(string op)(ref const Rational b) const
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

	void opOpAssign(string op)(const Integer b)
	{
		opOpAssign!op(b);
	}

	void opOpAssign(string op)(ref const Integer b)
	{
		static if(op == "+")
		{
			num += b*denom;
			normalize();
		}
		else static if(op == "-")
		{
			num -= b*denom;
			normalize();
		}
		else static if(op == "*")
		{
			num *= b;
			normalize();
		}
		else static if(op == "/")
		{
			denom *= b;
			normalize();
		}
		else static assert(false, "binary assign '"~op~"' is not defined");
	}

	void opOpAssign(string op)(const Rational b)
	{
		opOpAssign!op(b);
	}

	void opOpAssign(string op)(ref const Rational b)
	{
		static if(op == "+")
		{
			num *= b.denom;
			num += b.num*denom;
			denom *= b.denom;
			normalize();
		}
		else static if(op == "-")
		{
			num *= b.denom;
			num -= b.num*denom;
			denom *= b.denom;
			normalize();
		}
		else static if(op == "*")
		{
			num *= b.num;
			denom *= b.denom;
			normalize();
		}
		else static if(op == "/")
		{
			num *= b.denom;
			denom *= b.num;
			normalize();
		}
		else static assert(false, "binary assign '"~op~"' is not defined");
	}

	bool opEquals(const Rational b) const
	{
		return opEquals(b);
	}

	bool opEquals(ref const Rational b) const
	{
		return num == b.num && denom == b.denom; // both numbers need to be normalized for this
	}

	int opCmp(const Rational b) const
	{
		return opCmp(b);
	}

	int opCmp(ref const Rational b) const
	{
		return (num*b.denom).opCmp(denom*b.num); // denominators need to be positive for this
	}

	/** substract and return the whole integer part (remaining fraction is non-negative) */
	Integer extractFloor()
	{
		if(num.isNan || denom.isNan)
			throw new NanException;

		Integer q;
		__gmpz_init(&q.z);
		__gmpz_fdiv_qr(&q.z, &num.z, &num.z, &denom.z);
		return q;
	}
}
