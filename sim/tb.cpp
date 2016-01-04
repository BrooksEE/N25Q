/* Verilator implementation for sim using python-nitro bindings */

#include <Python.h>
#include "numpy/arrayobject.h"
#include "python_nitro.h"

#include "Vtb.h"
#include "Vtb_tb.h"
#include "Vtb_fx3.h"


#if VM_TRACE
#include "verilated_vcd_c.h"

VerilatedVcdC* tfp = NULL;
bool trace = true;

#else
bool trace = false;
#endif

Vtb *tb = NULL;

// By default main_time is 1ns in the vcd output. 
// if you need a clock that is not an even multiple of 1ns
// you might want to change main_time to be 1/2, 1/3 or 
// even 1/1000 (ps) of a ns.  You'd do this by setting
// timescale_div in init to the divider you want.
//
// example, setting timescale_div = 2 causes main_time to 
// represent 500ps
//
// The only caveat is that I haven't figured out a way to
// get the vcd output to reflect the timing right.
// So if you use timescale_div of 2, you have to divide
// the ns in the output by 2 also to understand the timing.
// But proportionaly it works well.
unsigned int main_time = 0;	// Current simulation time
unsigned int timescale_div = 1; // allow main time to be 

// the if clock toggles every halfdiv.  
// default is a 50mhz clock (note actual fx3 clock is
// 50.4 by default)
unsigned int clk_half_period=10;

#define CHECK_INIT   if(tb == NULL) { PyErr_SetString(PyExc_Exception, "You have not initialized this sim yet.  Run init() function"); return NULL; }


double sc_time_stamp () {	// Called by $time in Verilog
    return (double)main_time/timescale_div;
}

#ifdef USER_TB_EVAL
void USER_TB_EVAL();
#endif

void advance_clk(unsigned int cycles=1) {
  while (cycles) {
    // Toggle clock
    if ((main_time % clk_half_period) == 1) {
      if(tb->clk) {
	tb->clk = 0;
      } else {
	cycles--;
	tb->clk = 1; 
      }
    }
#ifdef USER_TB_EVAL
    USER_TB_EVAL();
#endif

    tb->eval();            // Evaluate model
#if VM_TRACE
    if(trace) tfp->dump (main_time); ///timescale_div);
#endif
    main_time++;            // Time passes...
  }
}

void open_trace(const char *filename) {
#if VM_TRACE
  tfp->open(filename);
  trace = true;
#endif
}

static PyObject *init(PyObject *self, PyObject *args, PyObject *kwds) {
  const char *filename=NULL;
  unsigned int maintime_div=1;
  unsigned int half_period=10;

  char *kwlist[] = { "vcdfile", "maintime_div", "half_period", NULL };

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|sii", kwlist, &filename, &maintime_div, &half_period)) {
    PyErr_SetString(PyExc_Exception, "usage init( vcdfile=None, maintime_div=1, half_period=10");
    return NULL;
  }
    
  tb   = new Vtb("tb");	// Create instance of module
  Verilated::debug(0);

#if VM_TRACE
  Verilated::traceEverOn(true);	// Verilator must compute traced signals
  tfp = new VerilatedVcdC;
  tb->trace (tfp, 99);	// Trace 99 levels of hierarchy
  trace = false;
  if(filename) {
    open_trace(filename);
  }
#endif

  timescale_div=maintime_div;
  clk_half_period=half_period;

  // pull fx3 out of reset
  advance_clk(50);

  Py_RETURN_NONE; 
}

static PyObject *start_tracing(PyObject *self, PyObject *args) {
#if VM_TRACE
  const char *filename=NULL;
  if (!PyArg_ParseTuple(args, "s", &filename)) {
    PyErr_SetString(PyExc_Exception, "Must provide vcd filename as argument");
    return NULL;
  }
  if(trace) {
    PyErr_SetString(PyExc_Exception, "Tracing is already enabled.");
    return NULL;
  }
  open_trace(filename);
#endif
  Py_RETURN_NONE;
}

static PyObject *time(PyObject *self, PyObject *args) {
  return PyInt_FromLong(main_time);
}

static PyObject *get_dev(PyObject *self, PyObject* args ) {
  if(!tb) {
    PyErr_SetString(PyExc_Exception, "You must call init() prior to this method");
    return NULL;
  }    
  return nitro_from_datatype ( *(tb->v->fx3->fx3_dev) );
}

static PyObject *adv(PyObject *self, PyObject *args) {
  int x;
  CHECK_INIT

  if (!PyArg_ParseTuple(args, "i", &x)) {
    PyErr_SetString(PyExc_Exception, "Argument is number of clock cycles to advance simulation");
    return NULL;
  }
  advance_clk(x);
  Py_RETURN_NONE;
}

static PyObject *end(PyObject *self, PyObject *args) {
  CHECK_INIT
  tb->final();
  delete tb;
#if VM_TRACE
  if(trace) {
    tfp->close();
    delete tfp;
  }
  tfp = NULL;
#endif
  tb = NULL;
  Py_RETURN_NONE; 
}



static PyObject *ndarrayFromPtr(PyObject *self, PyObject *args) {
    unsigned long addr;
    int size;
    if (PyArg_ParseTuple ( args, "ki", &addr, &size )) {

        void* paddr = (void*)addr; 
        printf( "void* addr %08x\n", addr );
        npy_intp dims[] = {size};
        PyObject *a = PyArray_SimpleNewFromData ( 1, dims, NPY_BYTE, paddr );
        // does this need a ref inc?
        return a;
    }
    return NULL;
}

#ifdef USER_TB
#include <user_tb.cpp>
#endif

/*************************************  Vtb extension module ****************/
static PyMethodDef Vtb_methods[] = {
  {"init", (PyCFunction)init, METH_VARARGS|METH_KEYWORDS,"Creates an instance of the simulation." },
  {"trace",start_tracing,METH_VARARGS,"Turns on tracing to specified file." },
  {"time", time, METH_NOARGS, "Gets the current time of the simulation." },
  {"adv",  adv,  METH_VARARGS, "Advances sim x number of clk cycles." },
  {"end",  end,  METH_NOARGS, "Ends simulation & deletes all sim objects." },
  {"get_dev", get_dev, METH_NOARGS, "Returns a dev handle." },
  {"ndarrayFromPtr", ndarrayFromPtr, METH_VARARGS, "Convert an int addr to void* and return as ndarray."}, 
#ifdef USER_PYTHON_METHODS
USER_PYTHON_METHODS
#endif
  {NULL}  /* Sentinel */
};

#ifndef PyMODINIT_FUNC	/* declarations for DLL import/export */
#define PyMODINIT_FUNC void
#endif
PyMODINIT_FUNC initVtb(void) {
    PyObject* m;

    import_nitro();
    m = Py_InitModule3("Vtb", Vtb_methods,
                       "Starter Project Testbench");

    import_array(); // necessary to use numpy arrays
}

//// This is a hack to use the same .cpp file with verilator and have it
//// generate a different python module for gate level sims.
//PyMODINIT_FUNC initVtb_gates(void) {
//    PyObject* m;
//
//    m = Py_InitModule3("Vtb_gates", Vtb_methods,
//                       "Hydrogen Project Testbench For Gate Sims");
//
//    import_array(); // necessary to use numpy arrays
//}
