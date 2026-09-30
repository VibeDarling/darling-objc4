#import <objc/NSObject.h>
#undef NDEBUG
#include <objc/runtime.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

extern id objc_initWeak(id *, id);
extern id objc_loadWeakRetained(id *);
extern void objc_destroyWeak(id *);
static unsigned destroyed;
@interface ClassLifecycleProbe : NSObject
- (uintptr_t)answer;
@end
@implementation ClassLifecycleProbe
- (uintptr_t)answer { return 0x12345678; }
- (void)dealloc { ++destroyed; [super dealloc]; }
@end

int main(void) {
    Class cls = objc_getClass("ClassLifecycleProbe");
    assert(cls && class_getSuperclass(cls) == objc_getClass("NSObject"));
    fprintf(stderr, "CHECK class=%p metaclass=%p\n", cls, object_getClass(cls));
    const char *minimum = getenv("OBJC_MIN_CLASS_ADDRESS");
    if (minimum) {
        uintptr_t lower = strtoull(minimum, NULL, 0);
        assert((uintptr_t)cls >= lower && (uintptr_t)cls < (UINT64_C(1)<<47));
        assert((uintptr_t)object_getClass(cls) >= lower);
    }
    for (unsigned i=0; i<100; ++i) {
        ClassLifecycleProbe *value = [[ClassLifecycleProbe alloc] init];
        assert(object_getClass(value) == cls);
        assert([value answer] == 0x12345678);
        id weak = nil;
        assert(objc_initWeak(&weak, value) == value);
        id held = objc_loadWeakRetained(&weak);
        assert(held == value);
        [value release];
        assert(destroyed == i);
        assert([held answer] == 0x12345678);
        [held release];
        assert(destroyed == i+1);
        assert(objc_loadWeakRetained(&weak) == nil);
        objc_destroyWeak(&weak);
    }
    puts("PASS objc class identity, dispatch, retained weak loads and zeroing");
    return 0;
}
