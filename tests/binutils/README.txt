----directories----------
  binutils-2.16		origin binutils file, used for recovery.
  BUILD				binutils file, used for compile all kind of version
  in				fuzz seed file
  obj				origin binutils obj without any CVE patch
  obj-1				first instrumentation obj file for each CVE, with sub-directory CVE number
  obj-2				second instrumentation obj file for each CVE, with sub-directory CVE number
  obj-fixed			fixed obj file for each CVE vunerability, with sub-directory CVE number,
  					Used to check whether the crash file can pass the fixed version.
  out 				fuzzing output, with sub-directory CVE-number
  temp				fuzzing temp, with sub-directory CVE-number
  
----files----------------
  binutils-2.26.patch	
  					Important patch fixing string buffer overflow in gnu_special(), which dosen't
  					belong to any CVE but has a big impact on the process of mangled string. 
  					Patch it to binutils-2.26 version before fuzzing,
  					otherwise cxxfile may crash before the CVE is exposed.
  
