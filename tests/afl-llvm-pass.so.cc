/*
  Copyright 2015 Google LLC All rights reserved.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at:

	http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/*
   american fuzzy lop - LLVM-mode instrumentation pass
   ---------------------------------------------------

   Written by Laszlo Szekeres <lszekeres@google.com> and
			  Michal Zalewski <lcamtuf@google.com>

   LLVM integration design comes from Laszlo Szekeres. C bits copied-and-pasted
   from afl-as.c are Michal's fault.

   This library is plugged into LLVM when invoking clang through afl-clang-fast.
   It tells the compiler to add code roughly equivalent to the bits discussed
   in ../afl-as.h.
*/

#define AFL_LLVM_PASS

#include "../config.h"
#include "../debug.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "llvm/ADT/Statistic.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/Debug.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"

using namespace llvm;

namespace {

	class AFLCoverage : public ModulePass {

	public:

		static char ID;
		AFLCoverage() : ModulePass(ID) { }

		bool runOnModule(Module &M) override;

		StringRef getPassName() const override {
			return "American Fuzzy Lop Instrumentation";
		}

	};

}

/* TortoiseFuzz */
std::vector<std::string> syscall_routines = {
  // memory allocation
  "calloc",  "malloc",   "realloc",  "free",
  // memory operation
  "memcpy",  "memmove",  "memchr",   "memset",  
  "memcmp",
  // string operation
  "strcpy",  "strncpy",  "strerror", "strlen",
  "strcat",  "strncat",  "strcmp",   "strspn",
  "strcoll", "strncmp",  "strxfrm",  "strstr",
  "strchr",  "strcspn",  "strpbrk",  "strrchr", 
  "strtok",
  // TODO... add more interesting functions
};

bool is_syscall(std::string fn_name){
  for(std::vector<std::string>::size_type i = 0; i < syscall_routines.size(); i++){
    if(fn_name.compare(syscall_routines[i]) == 0)
      return true;
  }
  return false;
}


char AFLCoverage::ID = 0;

bool AFLCoverage::runOnModule(Module &M) {

	LLVMContext &C = M.getContext();

	IntegerType *Int8Ty = IntegerType::getInt8Ty(C);
	IntegerType *Int32Ty = IntegerType::getInt32Ty(C);

	/* Show a banner */
	char be_quiet = 0;

	if (isatty(2) && !getenv("AFL_QUIET")) {

		SAYF(cCYA "afl-llvm-pass " cBRI VERSION cRST " by <chunfang>\n");

	}
	else be_quiet = 1;

	/* Decide instrumentation ratio */
	char* inst_ratio_str = getenv("AFL_INST_RATIO");
	unsigned int inst_ratio = 100;

	if (inst_ratio_str) {

		if (sscanf(inst_ratio_str, "%u", &inst_ratio) != 1 || !inst_ratio ||
			inst_ratio > 100)
			FATAL("Bad value of AFL_INST_RATIO (must be between 1 and 100)");

	}

	/* Get globals for the SHM region and the previous location. Note that
	   __afl_prev_loc is thread-local. */

	GlobalVariable *AFLMapPtr =
		new GlobalVariable(M, PointerType::get(Int8Ty, 0), false,
			GlobalValue::ExternalLinkage, 0, "__afl_area_ptr");
			
	GlobalVariable *AFLMapPtrVul =
		new GlobalVariable(M, PointerType::get(Int8Ty, 0), false,
			GlobalValue::ExternalLinkage, 0, "__afl_area_ptr_vul");

	GlobalVariable *AFLPrevLoc = new GlobalVariable(
		M, Int32Ty, false, GlobalValue::ExternalLinkage, 0, "__afl_prev_loc",
		0, GlobalVariable::GeneralDynamicTLSModel, 0, false);


    /*add by chunfang: Get globals for the previous function. Note that
	   __afl_prev_func is thread-local. */
	GlobalVariable *AFLPrevFunc = new GlobalVariable(
		M, Int32Ty, false, GlobalValue::ExternalLinkage, 0, "__afl_prev_func",
		0, GlobalVariable::GeneralDynamicTLSModel, 0, false);

	GlobalVariable *AFLFuncPtr =
		new GlobalVariable(M, PointerType::get(Int8Ty, 0), false,
			GlobalValue::ExternalLinkage, 0, "__afl_Func_ptr");		

	GlobalVariable *AFLInstPtr =
		new GlobalVariable(M, PointerType::get(Int64Ty, 0), false,
			GlobalValue::ExternalLinkage, 0, "__afl_Inst_ptr");	

	/* Analyze the CG to generate the recursive function chain */
	//to do 	
	
	/* Instrument all the things! */

	int inst_blocks = 0; // num of instrumented blocks
	int inst_blocks_vul = 0;    // num of instrumented vulnerable blocks
    int func_recursion = 0;   //FEIFUZZ num of instrumented recursive function
	int banned_func_cnt = 0;  //FEIFUZZ num of instrumented banned_function
	int mem_read_cnt = 0; //FEIFUZZ num of instrumented mem_read instructions
	int mem_write_cnt = 0; //FEIFUZZ num of instrumented mem_write instructions


	for (auto &F : M) {

		unsigned int cur_func = AFL_R(FUNC_SIZE); 
		bool isRecurse = false;

		AttributeSet funcAttrs = F.getAttributes();
		if (!funcAttrs.hasAttribute(Attribute::NoRecurse)) {
			isRecurse = true;
		}

		int FuncBBcounts = 0;  // numbers of basicblocks in a function

		for (auto &BB : F) {	

			BasicBlock::iterator IP = BB.getFirstInsertionPt();
			IRBuilder<> IRB(&(*IP));

			if (AFL_R(100) >= inst_ratio) continue;

			/* Make up cur_loc */
			unsigned int cur_loc = AFL_R(MAP_SIZE);
			bool is_vul_BB = false;

            //FEIFUZZ: instrument the recursive function
			//afl_func_ptr[cur_func|prev_func]++, prev_func = cur_func >> 1
			ConstantInt *CurFunc = ConstantInt::get(Int32Ty, cur_func);
			
			if (!FuncBBcounts && isRecurse) { 
				is_vul_BB = true;

                /* load prev_func */
                LoadInst *PrevFunc = IRB.CreateLoad(AFLPrevFunc);
                PrevFunc->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
                Value *PrevFuncCasted = IRB.CreateZExt(PrevFunc, IRB.getInt32Ty());

                /* Load SHM pointer */ 
                LoadInst *FuncPtr = IRB.CreateLoad(AFLFuncPtr);
                FuncPtr->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
                Value *FuncPtrIdx =
                    IRB.CreateGEP(FuncPtr, IRB.CreateXor(PrevFuncCasted, CurFunc));

				/* Update bitmap */
				LoadInst *CounterFunc = IRB.CreateLoad(FuncPtrIdx);
				Counter->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
				Value *IncrFunc = IRB.CreateAdd(CounterFunc, ConstantInt::get(Int8Ty, 1));
				IRB.CreateStore(IncrFunc, FuncPtrIdx)
					->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));

                func_recursion++;
            }
			/* Set prev_func to cur_func >> 1 */
            StoreInst *StoreFunc =
                    IRB.CreateStore(ConstantInt::get(Int32Ty, cur_func >> 1), AFLPrevFunc);
            StoreFunc->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));


			for(auto &Inst : BB){
				if(CallInst* call_inst = dyn_cast<CallInst>(&inst)) {
					Function* fn = call_inst->getCalledFunction();				
					if(fn == NULL){
						Value *v = call_inst->getCalledValue();
						fn = dyn_cast<Function>(v->stripPointerCasts());
						if(fn == NULL)
							continue;
					}
					std::string fn_name = fn->getName(); 
					if(fn_name.compare(0, 5, "llvm.") == 0)
						continue;					
					if(is_syscall(fn_name)){
						is_vul_BB = true;
						banned_func_cnt++;
						// outs() << fn_name << "\n";
						//todo argvs 
					}
				}
				else if(inst.mayReadFromMemory()){ // memory read
					is_vul_BB = true;
					mem_read_cnt++;
					//todo operand
				}
				else if(inst.mayWriteToMemory()){
					is_vul_BB = true;
					mem_write_cnt++;
					//todo operand
				}
				// todo Type Confusion, Divide By Zero, Integer Overflow or Wraparound, etc

			}

			ConstantInt *CurLoc = ConstantInt::get(Int32Ty, cur_loc);
			/* Load prev_loc */
			LoadInst *PrevLoc = IRB.CreateLoad(AFLPrevLoc);
			PrevLoc->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
			Value *PrevLocCasted = IRB.CreateZExt(PrevLoc, IRB.getInt32Ty());

			if(is_vul_BB){
				/* Load vulnerable SHM pointer */
				LoadInst *MapPtrVul = IRB.CreateLoad(AFLMapPtrVul);
				MapPtr->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
				Value *MapPtrIdxVul =
					IRB.CreateGEP(MapPtrVul, IRB.CreateXor(PrevLocCasted, CurLoc));

				/* Update bitmap */
				LoadInst *CounterVul = IRB.CreateLoad(MapPtrIdxVul);
				Counter->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
				Value *IncrVul = IRB.CreateAdd(CounterVul, ConstantInt::get(Int8Ty, 1));
				IRB.CreateStore(IncrVul, MapPtrIdxVul)
					->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
 
				inst_blocks_vul++;
			}

			/* Load SHM pointer */
			LoadInst *MapPtr = IRB.CreateLoad(AFLMapPtr);
			MapPtr->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
			Value *MapPtrIdx =
				IRB.CreateGEP(MapPtr, IRB.CreateXor(PrevLocCasted, CurLoc));

			/* Update bitmap */
			LoadInst *Counter = IRB.CreateLoad(MapPtrIdx);
			Counter->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
			Value *Incr = IRB.CreateAdd(Counter, ConstantInt::get(Int8Ty, 1));
			IRB.CreateStore(Incr, MapPtrIdx)
				->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
			
			/* Set prev_loc to cur_loc >> 1 */
			StoreInst *Store =
				IRB.CreateStore(ConstantInt::get(Int32Ty, cur_loc >> 1), AFLPrevLoc);
			Store->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));

			inst_blocks++; 
			FuncBBcounts++;
		}

	}

	/* Say something nice. */

	if (!be_quiet) {

		if (!inst_blocks) WARNF("No instrumentation targets found.");
		else{
			OKF("Instrumented %u blocks in total (%s mode, ratio %u%%), %u vulnerable blocks.",
				inst_blocks, getenv("AFL_HARDEN") ? "hardened" :((getenv("AFL_USE_ASAN") || getenv("AFL_USE_MSAN")) ?
				"ASAN/MSAN" : "non-hardened"), inst_ratio, inst_blocks_vul);
			OKF("Instrumented %u recursive function.", func_recursion);
			OKF("Instrumented %u banned function, %u mem_read instruction, %u mem_write instructions.", 
				banned_func_cnt, mem_read_cnt, mem_write_cnt);			
		} 

	}

	return true;

}


static void registerAFLPass(const PassManagerBuilder &,
	legacy::PassManagerBase &PM) {

	PM.add(new AFLCoverage());

}


static RegisterStandardPasses RegisterAFLPass(
	PassManagerBuilder::EP_ModuleOptimizerEarly, registerAFLPass);

static RegisterStandardPasses RegisterAFLPass0(
	PassManagerBuilder::EP_EnabledOnOptLevel0, registerAFLPass);
