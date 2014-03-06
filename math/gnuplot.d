module math.gnuplot;

private import std.stdio;
private import std.range;

class Gnuplot
{
	private File pipe;
	private int nplots = 0;

	/**
	 * Params:
	 *  persists = the plot window should stay open after program exits
	 */
	this(bool persist = true)
	{

		pipe.popen("gnuplot", "w");
		pipe.writef("set output\n");
		pipe.writef("set terminal x11\n");
		pipe.flush();
	}

	/** plot a function. Example: plot("sin(x)") */
	void plot(string fun, string title = null)
	{
		pipe.writef("%s %s title \"%s\"\n", nplots?"replot":"plot", fun, title?title:fun);
		++nplots;
		pipe.flush();
	}

	/** plot raw data points */
	void plot(RangeX, RangeY)(RangeX xs, RangeY ys, string title = null)
		if(isInputRange!RangeX && isInputRange!RangeY && is(ElementType!RangeX:double) && is(ElementType!RangeY:double))
	{
		auto filename = "gnuplot_"~std.conv.to!string(nplots)~".txt";
		auto f = File(filename, "w");

		while(!ys.empty)
		{
			f.writefln("%s %s", xs.front, ys.front);
			xs.popFront;
			ys.popFront;
		}
		f.close();

		pipe.writef("%s '%s' using 1:2 with lines title \"%s\"\n", nplots?"replot":"plot", filename, title?title:"data");
		++nplots;
		pipe.flush();
	}

	void setXRange(double min, double max)
	{
		pipe.writef("set xrange[%s : %s]\n", min, max);
		pipe.flush();
	}

	void setYRange(double min, double max)
	{
		pipe.writef("set yrange[%s : %s]\n", min, max);
		pipe.flush();
	}

	void setZRange(double min, double max)
	{
		pipe.writef("set zrange[%s : %s]\n", min, max);
		pipe.flush();
	}

	void clear()
	{
		pipe.writef("clear\n");
		pipe.flush();
		nplots = 0;
	}

	void cmd(string c)
	{
		pipe.writef("%s\n", c);
		pipe.flush();
	}
}
