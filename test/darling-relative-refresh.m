#import <objc/NSObject.h>
#include <objc/message.h>
#include <dlfcn.h>
#include <assert.h>
#include <stdio.h>

static unsigned long value(id self, SEL sel) { return 22; }

int main(void)
{
    unsigned (*refresh)(Class, SEL, IMP) = dlsym(RTLD_DEFAULT,
                                                  "darling_test_refresh_method");
    assert(refresh);
    Class cls = objc_allocateClassPair(objc_getClass("NSObject"),
                                       "RelativeRefreshFixture", 0);
    assert(cls);
    objc_registerClassPair(cls);
    SEL selector = sel_registerName("relativeRefreshValue");
    id object = [[cls alloc] init];
    unsigned long (*send)(id, SEL) = (void *)objc_msgSend;
    assert(send(object, selector) != 22);

    // The validation hook runs the production refresh path three times:
    // unloaded (no attach), loaded (one attach), then already attached.
    assert(refresh(cls, selector, (IMP)value) == 2);
    assert(send(object, selector) == 22);
    [object release];
    puts("PASS relative refresh ignores unloaded lists, attaches once, and is idempotent");
    return 0;
}
