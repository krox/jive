module jive.prime;

import jive.array;
import jive.bitarray;
private import std.math : log;

Array!ulong primesBelow(ulong n)
{
	auto b = BitArray(n/2);
	Array!ulong primes;
	if(n <= 10)
		primes.reserve(4);
	else
		primes.reserve(cast(size_t)(n/log(n)*(1+1/log(n)+2.51/log(n)/log(n))));

	if(n <= 2)
		return primes;
	primes.pushBack(2);
	if(n <= 3)
		return primes;

	ulong k = 1;
	for( ; /*k < n/2*/; ++k)
		if(!b[k])
		{
			ulong p = 2*k+1;

			if(p*p > n)
				break;

			primes.pushBack(p);

			for(ulong s = p*p/2; s < n/2; s += p)
				b[s] = true;
		}


	for( ; k < n/2; ++k)
		if(!b[k])
			primes.pushBack(2*k+1);

	return primes;
}

ulong powmod(ulong base, ulong exp, ulong mod) pure
{
	ulong r = 1;
	while(exp)
	{
		if(exp&1)
			r = (r*base) % mod;
		exp >>= 1;
		base = (base*base) % mod;
	}
	return r;
}

ulong modinv(ulong x, ulong mod)
{
	return powmod(x,mod-2,mod);	// only works for mod prime
}

long gcd(long a, long b)
{
	if(b == 0)
		return a;
	else
		return gcd(b, a%b);
}
