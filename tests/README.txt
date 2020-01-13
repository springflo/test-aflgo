----directories------
  binutils		binutils CVEs test directory
  CVE-out 		the crash file expose certain CVE, with sub-directory CVE number,
  				copied from binutils/out/$CVE/ using CVE-check-crash.sh
  CVEpatch 		the patch file of certain CVE, named with CVE number
  CVEtarget		the target line of certain CVE, named with CVE number
  
----files------------
  CVEtest.sh	Reproduce certain CVE, usage: ./CVEtest.sh 2016-4487
  				Will run CVE-analyze-target.sh to generate target lines.
  CVE-check-crash.sh	
  				check whether the fuzzer exposed certain CVE, if exposed, kill the fuzzer
  				and archive the crash file, then do some analyze. 
  				Usage: ./CVE-check-crash.sh 2016-4487
  CVE-analyze-target.sh 
  				Analyze the call stack of given reproduction, and generate target lines.
  				Print gdb call stack to logging, run Generate_target_lines.py to analyze the 
  				call stack.
  				usage: ./CVE-analyze-target.sh 2016-4487
  Generate_target_lines.py
  				A small python script to analyze the call stack. Write the most frequent calls
  				to BBtarget.txt.
  gdbcmd.txt	GDB cmds for CVE-analyze-target.sh gbd analyze.
