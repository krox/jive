module math.integer;

private import std.string : toStringz;
private import std.conv : to;

/**
 * BigInteger type using the GMP library.
 * It is implemented with copy-on-write semantics.
 * Should be mostly compatible with int. Differences include:
 *   * There is a NaN value, to which all variables are initialized.
 *     Note that it is an error to use a NaN in computations.
 *   * Integer division rounds the quotient towards -infinity.
 *     In particular, (a % b) always has the same sign as b.
 */
struct Integer
{
	package const(mpz_t)* z;

	/** TODO: remove this class. It currently only exists to ensure destructor-calls on GC collections */
	private static final class mpz_class
	{
		mpz_t z;

		version(count_gmp)
		{
			static int destructCount = 0;

			static ~this()
			{
				import std.stdio;
				writefln("GMP integers destructed: %s", destructCount);
			}
		}

		/** destructor */
		~this()
		{
			__gmpz_clear(&z);

			version(count_gmp)
				destructCount++;
		}
	}

	private static mpz_t* create()
	{
		auto z = &(new mpz_class).z;
		__gmpz_init(z);
		return z;
	}

	private this(mpz_t* z)
	{
		this.z = z;
	}

	private enum cacheSize = 10;

	private static const mpz_t*[cacheSize] cache;

	static this()
	{
		for(int i = 0; i < cacheSize; ++i)
		{
			auto z = &(new mpz_class).z;
			__gmpz_init_set_si(z, i);
			cache[i] = z;
		}
	}

	/** constructor for given value */
	this(int v)
	{
		if(v < cacheSize)
		{
			z = cache[v];
			return;
		}
		auto r = &(new mpz_class).z;
		__gmpz_init_set_si(r, v);
		z = r;
	}

	/** ditto */
	this(double v)
	{
		auto r = &(new mpz_class).z;
		__gmpz_init_set_d(r, v);
		z = r;
	}

	/** ditto */
	this(string v)
	{
		// TODO: throw exception on bad strings
		auto r = &(new mpz_class).z;
		__gmpz_init_set_str(r, toStringz(v), 0);
		z = r;
	}

	static enum nan = Integer.init;

	bool isNan() const @property
	{
		return z is null;
	}

	string toString() const @property
	{
		auto buflen = __gmpz_sizeinbase(z, 10)+2;	// one for sign, one for \0
		auto buf = new char[buflen];
		return to!string(__gmpz_get_str(buf.ptr, 10, z));
	}

	/** returns -1 / 0 / +1, faster than actual compare */
	int sign() const
	{
		return z._mp_size < 0 ? -1 : z._mp_size > 0;
	}

	Integer opUnary(string op)() const
		if(op == "-")
	{
		auto r = create();
		__gmpz_neg(r, z);
		return Integer(r);
	}

	Integer inverseMod(const Integer mod) const
	{
		auto r = create();
		__gmpz_invert(r, z, mod.z);
		return Integer(r);
	}

	// TODO: Integer <-> int division and modulus (why are there so few *_si functions in gmp?)

	Integer opBinary(string op)(int b) const
	{
		auto r = create();

		static if(op == "+")
		     if(b >= 0) __gmpz_add_ui(r, z, b);
		     else       __gmpz_sub_ui(r, z, -b);
		else static if(op == "-")
			if(b >= 0) __gmpz_sub_ui(r, z, b);
			else       __gmpz_add_ui(r, z, -b);
		else static if(op == "*")
			__gmpz_mul_si(r, z, b);

		else static assert(false, "binary '"~op~"' is not defined");

		return Integer(r);
	}

	Integer opBinaryRight(string op)(int a) const
		if(op == "+" || op == "*")
	{
		return opBinary(a); // commutative operators can simply be forwarded
	}

	Integer opBinaryRight(string op)(int a) const
		if(op == "-")
	{

		auto r = create();
		if(a >= 0)
			__gmpz_ui_sub(r, a, z);
		else
		{
			__gmpz_add_ui(r, z, -a);
			__gmpz_neg(r, r);
		}

		return Integer(r);
	}

	Integer opBinary(string op)(Integer b) const
	{
		auto r = create();

		     static if(op == "+") __gmpz_add(r, z, b.z);
		else static if(op == "-") __gmpz_sub(r, z, b.z);
		else static if(op == "*") __gmpz_mul(r, z, b.z);
		else static if(op == "/") __gmpz_fdiv_q(r, z, b.z);
		else static if(op == "%") __gmpz_fdiv_r(r, z, b.z);
		else static assert(false, "binary '"~op~"' is not defined");

		return Integer(r);
	}

	/** returns this/b. Faster, but only works if the division is exact (i.e. no rounding) */
	Integer divExact(Integer b) const
	{
		auto r = create();
		__gmpz_divexact(r, z, b.z);
		return Integer(r);
	}

	bool opEquals(int b) const
	{
		return __gmpz_cmp_si(z, b) == 0;
	}

	bool opEquals(Integer b) const
	{
		return __gmpz_cmp(z, b.z) == 0;
	}

	int opCmp(int b) const
	{
		return __gmpz_cmp_si(z, b);
	}

	int opCmp(Integer b) const
	{
		return __gmpz_cmp(z, b.z) == 0;
	}

	bool isPerfectSquare() const @property
	{
		return __gmpz_perfect_square_p(z) != 0;
	}
}

/** returns floor(sqrt(a)) */
Integer isqrt(Integer a)
{
	auto r = Integer.create();
	__gmpz_sqrt(r, a.z);
	return Integer(r);
}

Integer gcd(Integer a, Integer b)
{
	auto r = Integer.create();
	__gmpz_gcd(r, a.z, b.z);
	return Integer(r);
}

Integer gcd(Integer a, Integer b, Integer c)
{
	auto r = Integer.create();
	__gmpz_gcd(r, a.z, b.z);
	__gmpz_gcd(r, r, c.z);
	return Integer(r);
}


package extern(C):

version(Windows)
{
	alias int c_long;
	alias uint c_ulong;
}
else
{
	static if((void*).sizeof > int.sizeof)
	{
		alias long c_long;
		alias ulong c_ulong;
	}
	else
	{
		alias int c_long;
		alias uint c_ulong;
	}
}

alias c_ulong mp_bitcnt_t;

extern immutable int __gmp_bits_per_limb;
extern immutable int __gmp_errno;
extern immutable char* __gmp_version;

private alias size_t limb;

static this()
{
	assert(limb.sizeof*8 == __gmp_bits_per_limb, "wrong gmp limb size");
}

struct mpz_t
{
	int _mp_alloc;
	int _mp_size;
	/*limb * */ size_t _mp_d;
	// having this pointer in a non-pointer variable is fine because it is never actually used in D code.
	// In particular it does never point to GC-memory.
}

size_t __gmpz_sizeinbase (const mpz_t* op , int base );

void __gmpz_init(mpz_t* x );
void __gmpz_init2(mpz_t* x ,size_t n);
void __gmpz_clear(mpz_t* x);
void __gmpz_realloc2(mpz_t* x, mp_bitcnt_t n);	// set to 0 if it does not fit

void __gmpz_set    (mpz_t* rop, const mpz_t* op);
void __gmpz_set_ui (mpz_t* rop, c_ulong op);
void __gmpz_set_si (mpz_t* rop, c_long op);
void __gmpz_set_d  (mpz_t* rop, double op);
int  __gmpz_set_str(mpz_t* rop , const char * str , int base );	// white space allowed/ignored, if base=0, 0x/0b&/0 are recognized. returns 0 if entire string is valid number

void __gmpz_swap   (mpz_t* rop1 , mpz_t* rop2 );

void __gmpz_init_set    (mpz_t* rop, const mpz_t* op );
void __gmpz_init_set_ui (mpz_t* rop, c_ulong op);
void __gmpz_init_set_si (mpz_t* rop, c_long op);
void __gmpz_init_set_d  (mpz_t* rop, double op);
int  __gmpz_init_set_str(mpz_t* rop, const char * str, int base);

c_ulong __gmpz_get_ui (const mpz_t* op);
c_long  __gmpz_get_si (const mpz_t* op);
double  __gmpz_get_d  (const mpz_t* op);
double  __gmpz_get_d_2exp (c_long * exp, const mpz_t* op);
char*   __gmpz_get_str(char* str, int base, const mpz_t* op);	// str==null or buffer of size __gmpz_sizeinbase (op, base ) + 2

void __gmpz_add       (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_add_ui    (mpz_t* rop, const mpz_t* op1,      c_ulong op2);
void __gmpz_sub       (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_sub_ui    (mpz_t* rop, const mpz_t* op1,      c_ulong op2);
void __gmpz_ui_sub    (mpz_t* rop,      c_ulong op1, const mpz_t* op2);
void __gmpz_mul       (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_mul_si    (mpz_t* rop, const mpz_t* op1,       c_long op2);
void __gmpz_mul_ui    (mpz_t* rop, const mpz_t* op1,      c_ulong op2);
void __gmpz_addmul    (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_addmul_ui (mpz_t* rop, const mpz_t* op1,      c_ulong op2);
void __gmpz_submul    (mpz_t* rop, const mpz_t* op1, const mpz_t* op2);
void __gmpz_submul_ui (mpz_t* rop, const mpz_t* op1,      c_ulong op2);

void __gmpz_mul_2exp (mpz_t* rop , const mpz_t* op1 , size_t op2 );	// rop = op1*2^op2
void __gmpz_neg (mpz_t* rop , const mpz_t* op );
void __gmpz_abs (mpz_t* rop , const mpz_t* op );

void __gmpz_cdiv_q (mpz_t* q , const mpz_t* n , const mpz_t* d );
void __gmpz_cdiv_r (mpz_t* r , const mpz_t* n , const mpz_t* d );
void __gmpz_cdiv_qr (mpz_t* q , mpz_t* r , const mpz_t* n , const mpz_t* d );

c_ulong __gmpz_cdiv_q_ui (mpz_t* q , const mpz_t* n, c_ulong d );
c_ulong __gmpz_cdiv_r_ui (mpz_t* r , const mpz_t* n, c_ulong d );
c_ulong __gmpz_cdiv_qr_ui (mpz_t* q , mpz_t* r , const mpz_t* n, c_ulong d );
c_ulong __gmpz_cdiv_ui (const mpz_t* n , c_ulong d );
void __gmpz_cdiv_q_2exp (mpz_t* q , const mpz_t* n , size_t b );
void __gmpz_cdiv_r_2exp (mpz_t* r , const mpz_t* n , size_t b );
void __gmpz_fdiv_q (mpz_t* q , const mpz_t* n , const mpz_t* d );
void __gmpz_fdiv_r (mpz_t* r , const mpz_t* n , const mpz_t* d );
void __gmpz_fdiv_qr (mpz_t* q , mpz_t* r , const mpz_t* n , const mpz_t* d );
c_ulong __gmpz_fdiv_q_ui (mpz_t* q , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_fdiv_r_ui (mpz_t* r , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_fdiv_qr_ui (mpz_t* q , mpz_t* r , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_fdiv_ui (const mpz_t* n , c_ulong d );
void __gmpz_fdiv_q_2exp (mpz_t* q , const mpz_t* n , size_t b );
void __gmpz_fdiv_r_2exp (mpz_t* r , const mpz_t* n , size_t b );
void __gmpz_tdiv_q (mpz_t* q , const mpz_t* n , const mpz_t* d );
void __gmpz_tdiv_r (mpz_t* r , const mpz_t* n , const mpz_t* d );
void __gmpz_tdiv_qr (mpz_t* q , mpz_t* r , const mpz_t* n , const mpz_t* d );
c_ulong __gmpz_tdiv_q_ui (mpz_t* q , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_tdiv_r_ui (mpz_t* r , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_tdiv_qr_ui (mpz_t* q , mpz_t* r , const mpz_t* n ,c_ulong d );
c_ulong __gmpz_tdiv_ui (const mpz_t* n , c_ulong d );
void __gmpz_tdiv_q_2exp (mpz_t* q , const mpz_t* n , size_t b );
void __gmpz_tdiv_r_2exp (mpz_t* r , const mpz_t* n , size_t b );

void __gmpz_mod (mpz_t* r , const mpz_t* n , const mpz_t* d );
c_ulong __gmpz_mod_ui (mpz_t* r , const mpz_t* n , c_ulong d );

void __gmpz_divexact (mpz_t* q , const mpz_t* n , const mpz_t* d );
void __gmpz_divexact_ui (mpz_t* q , const mpz_t* n , c_ulong d );

int __gmpz_divisible_p (const mpz_t* n , const mpz_t* d );
int __gmpz_divisible_ui_p (const mpz_t* n , c_ulong d );
int __gmpz_divisible_2exp_p (const mpz_t* n , size_t b );

int __gmpz_congruent_p (const mpz_t* n , const mpz_t* c , const mpz_t* d );
int __gmpz_congruent_ui_p (const mpz_t* n , c_ulong c , c_ulong d );
int __gmpz_congruent_2exp_p (const mpz_t* n , const mpz_t* c , size_t b );

void __gmpz_powm (mpz_t* rop , const mpz_t* base , const mpz_t* exp , const mpz_t* mod );
void __gmpz_powm_ui (mpz_t* rop , const mpz_t* base , c_ulong exp , const mpz_t* mod );
void __gmpz_powm_sec (mpz_t* rop , const mpz_t* base , const mpz_t* exp , const mpz_t* mod );
void __gmpz_pow_ui (mpz_t* rop , const mpz_t* base , c_ulong exp );
void __gmpz_ui_pow_ui (mpz_t* rop , c_ulong base , c_ulong exp);

int __gmpz_root (mpz_t* rop , const mpz_t* op , c_ulong n );	// returns nonzero if exact

void __gmpz_rootrem (mpz_t* root , mpz_t* rem , const mpz_t* u , c_ulong n );
void __gmpz_sqrt (mpz_t* rop , const mpz_t* op );

void __gmpz_sqrtrem (mpz_t* rop1 , mpz_t* rop2 , const mpz_t* op );

int __gmpz_perfect_power_p (const mpz_t* op );	// nonzero if perfect power
int __gmpz_perfect_square_p (const mpz_t* op );

int __gmpz_probab_prime_p (const mpz_t* n , int reps );	// 2=prime, 1=prob.prime, 0=composite, reps~25

void __gmpz_nextprime (mpz_t* rop , const mpz_t* op );
void __gmpz_gcd (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
c_ulong __gmpz_gcd_ui (mpz_t* rop , const mpz_t* op1 , c_ulong op2 );
void __gmpz_gcdext (mpz_t* g , mpz_t* s , mpz_t* t , const mpz_t* a , const mpz_t* b );
void __gmpz_lcm (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
void __gmpz_lcm_ui (mpz_t* rop , const mpz_t* op1 , c_ulong op2 );
int __gmpz_invert (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
int __gmpz_jacobi (const mpz_t* a , const mpz_t* b );
int __gmpz_legendre (const mpz_t* a , const mpz_t* p );

int __gmpz_kronecker (const mpz_t* a , const mpz_t* b );
int __gmpz_kronecker_si (const mpz_t* a , c_long b );
int __gmpz_kronecker_ui (const mpz_t* a , c_ulong b );
int __gmpz_si_kronecker (c_long a , const mpz_t* b );
int __gmpz_ui_kronecker (c_ulong a , const mpz_t* b );

mp_bitcnt_t __gmpz_remove (mpz_t* rop , const mpz_t* op , const mpz_t* f );

void __gmpz_fac_ui (mpz_t* rop , c_ulong n );
void __gmpz_2fac_ui (mpz_t* rop , c_ulong n );
void __gmpz_mfac_uiui (mpz_t* rop , c_ulong n , c_ulong m );
void __gmpz_primorial_ui (mpz_t* rop , c_ulong n );
void __gmpz_bin_ui (mpz_t* rop , const mpz_t* n , c_ulong k );
void __gmpz_bin_uiui (mpz_t* rop , c_ulong n , c_ulong k );
void __gmpz_fib_ui (mpz_t* fn , c_ulong n );
void __gmpz_fib2_ui (mpz_t* fn , mpz_t* fnsub1 , c_ulong n );
void __gmpz_lucnum_ui (mpz_t* ln , c_ulong n );
void __gmpz_lucnum2_ui (mpz_t* ln , mpz_t* lnsub1 , c_ulong n );

int __gmpz_cmp (const mpz_t* op1 , const mpz_t* op2 );
int __gmpz_cmp_d (const mpz_t* op1 , double op2 );
int __gmpz_cmp_si (const mpz_t* op1 , c_long op2 );
int __gmpz_cmp_ui (const mpz_t* op1 , c_ulong op2 );

int __gmpz_cmpabs (const mpz_t* op1 , const mpz_t* op2 );
int __gmpz_cmpabs_d (const mpz_t* op1 , double op2 );
int __gmpz_cmpabs_ui (const mpz_t* op1 , c_ulong op2 );

int __gmpz_sgn (const mpz_t* op );

void __gmpz_and (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
void __gmpz_ior (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
void __gmpz_xor (mpz_t* rop , const mpz_t* op1 , const mpz_t* op2 );
void __gmpz_com (mpz_t* rop , const mpz_t* op );

mp_bitcnt_t __gmpz_popcount (const mpz_t* op ); // returns bitcnt.max on negative
mp_bitcnt_t __gmpz_hamdist (const mpz_t* op1 , const mpz_t* op2 ); //returns bitcnt.max if different signs
mp_bitcnt_t __gmpz_scan0 (const mpz_t* op , size_t starting_bit );
mp_bitcnt_t __gmpz_scan1 (const mpz_t* op , size_t starting_bit );
void __gmpz_setbit (mpz_t* rop , size_t bit_index );
void __gmpz_clrbit (mpz_t* rop , size_t bit_index );
void __gmpz_combit (mpz_t* rop , size_t bit_index );
int __gmpz_tstbit (const mpz_t* op , size_t bit_index );
