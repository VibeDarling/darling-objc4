// imp_implementationWithBlock returns an IMP that runs the block, called through objc_msgSend. The trampolines live in
// libobjc-trampolines.dylib, which libobjc dlopen()s on first use. An arm64e process runs the cache's libobjc, which signs the
// block pointers it gives them, so a library without an arm64e slice faults here (pc is the signed block invoke pointer).
// Prints "result 42 141 calls 2" and exits 0 when both a global block and a capturing block work.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static long calls;

int main(void)
{
    @autoreleasepool
    {
        Class cls = objc_allocateClassPair([NSObject class], "BlockImpTrampolineTest", 0);
        objc_registerClassPair(cls);
        long bias = 100;
        IMP plain = imp_implementationWithBlock(^long(id self, long x) { calls++; return x + 1; });
        IMP capturing = imp_implementationWithBlock(^long(id self, long x) { calls++; return x + bias; });
        class_addMethod(cls, sel_registerName("addOne:"), plain, "q@:q");
        class_addMethod(cls, sel_registerName("addBias:"), capturing, "q@:q");
        id obj = class_createInstance(cls, 0);
        long a = ((long (*)(id, SEL, long))objc_msgSend)(obj, sel_registerName("addOne:"), 41);
        long b = ((long (*)(id, SEL, long))objc_msgSend)(obj, sel_registerName("addBias:"), 41);
        printf("result %ld %ld calls %ld\n", a, b, calls);
        return (a == 42 && b == 141 && calls == 2) ? 0 : 1;
    }
}
