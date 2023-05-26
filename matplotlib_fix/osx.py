"""
Calls NSApp / CoreFoundation APIs via ctypes.
"""

# obj-c boilerplate from appnope, used under BSD 2-clause
import ctypes
import ctypes.util

objc = ctypes.cdll.LoadLibrary(ctypes.util.find_library("objc"))  # type: ignore

void_p = ctypes.c_void_p

objc.objc_getClass.restype = void_p
objc.sel_registerName.restype = void_p
objc.objc_msgSend.restype = void_p
objc.objc_msgSend.argtypes = [void_p, void_p]

msg = objc.objc_msgSend

def _utf8(s):
    """ensure utf8 bytes"""
    if not isinstance(s, bytes):
        s = s.encode('utf8')
    return s

def n(name):
    """create a selector name (for ObjC methods)"""
    return objc.sel_registerName(_utf8(name))

def C(classname):
    """get an ObjC Class by name"""
    return objc.objc_getClass(_utf8(classname))

# end obj-c boilerplate from appnope


# CoreFoundation C-API calls we will use:
CoreFoundation = ctypes.cdll.LoadLibrary(ctypes.util.find_library("CoreFoundation"))  # type: ignore

CFFileDescriptorCreate = CoreFoundation.CFFileDescriptorCreate
CFFileDescriptorCreate.restype = void_p
CFFileDescriptorCreate.argtypes = [void_p, ctypes.c_int, ctypes.c_bool, void_p, void_p]

CFFileDescriptorGetNativeDescriptor = CoreFoundation.CFFileDescriptorGetNativeDescriptor
CFFileDescriptorGetNativeDescriptor.restype = ctypes.c_int
CFFileDescriptorGetNativeDescriptor.argtypes = [void_p]

CFFileDescriptorEnableCallBacks = CoreFoundation.CFFileDescriptorEnableCallBacks
CFFileDescriptorEnableCallBacks.restype = None
CFFileDescriptorEnableCallBacks.argtypes = [void_p, ctypes.c_ulong]

CFFileDescriptorCreateRunLoopSource = CoreFoundation.CFFileDescriptorCreateRunLoopSource
CFFileDescriptorCreateRunLoopSource.restype = void_p
CFFileDescriptorCreateRunLoopSource.argtypes = [void_p, void_p, void_p]

CFRunLoopGetCurrent = CoreFoundation.CFRunLoopGetCurrent
CFRunLoopGetCurrent.restype = void_p

CFRunLoopAddSource = CoreFoundation.CFRunLoopAddSource
CFRunLoopAddSource.restype = None
CFRunLoopAddSource.argtypes = [void_p, void_p, void_p]

CFRelease = CoreFoundation.CFRelease
CFRelease.restype = None
CFRelease.argtypes = [void_p]

CFFileDescriptorInvalidate = CoreFoundation.CFFileDescriptorInvalidate
CFFileDescriptorInvalidate.restype = None
CFFileDescriptorInvalidate.argtypes = [void_p]

# From CFFileDescriptor.h
kCFFileDescriptorReadCallBack = 1
kCFRunLoopCommonModes = void_p.in_dll(CoreFoundation, 'kCFRunLoopCommonModes')

def _NSApp():
    """Return the unique NSApplication instance, creating it if necessary."""
    objc.objc_msgSend.argtypes = [void_p, void_p]
    return msg(C('NSApplication'), n('sharedApplication'))

def _wake(NSApp):
    """Send an ApplicationDefined event.

    This is needed because NSApplication.stop just sets a flag.  The loop does
    not stup until an event is processed."""
    objc.objc_msgSend.argtypes = [
        void_p,
        void_p,
        void_p,
        void_p,
        void_p,
        void_p,
        void_p,
        void_p,
        void_p,
        void_p,
        void_p,
    ]
    event = msg(
        C("NSEvent"),
        n(
            "otherEventWithType:location:modifierFlags:"
            "timestamp:windowNumber:context:subtype:data1:data2:"
        ),
        15, # Type (NSEventTypeApplicationDefined)
        0,  # location
        0,  # flags
        0,  # timestamp
        0,  # window
        None,  # context
        0,  # subtype
        0,  # data1
        0,  # data2
    )
    objc.objc_msgSend.argtypes = [void_p, void_p, void_p, void_p]
    msg(NSApp, n('postEvent:atStart:'), void_p(event), True)

def _input_callback(fdref, flags, info):
    """One-shot callback which fires when there is input to be read"""
    # Actually this fires every second, no matter what unless the gui
    # is stealing all key events.
    CFFileDescriptorInvalidate(fdref)
    CFRelease(fdref)
    objc.objc_msgSend.argtypes = [void_p, void_p, void_p]
    NSApp = _NSApp()
    # Set the stop flag in the NSApplication
    msg(NSApp, n('stop:'), NSApp)
    # Send a dummy event to actually stop the runloop.
    _wake(NSApp)

def _stop_on_read(fd):
    """Register _input_callback to stop eventloop when fd has data."""
    # Calling the next two lines here instead of at the module level allows
    # this module to be loaded in SageMath.
    _c_callback_func_type = ctypes.CFUNCTYPE(None, void_p, void_p, void_p)
    _c_input_callback = _c_callback_func_type(_input_callback)
    fdref = CFFileDescriptorCreate(None, fd, False, _c_input_callback, None)
    source = CFFileDescriptorCreateRunLoopSource(None, fdref, 0)
    loop = CFRunLoopGetCurrent()
    CFRunLoopAddSource(loop, source, kCFRunLoopCommonModes)
    CFRelease(source)
    CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack)

counter = 0
def inputhook(context):
    """Inputhook for Cocoa (NSApp)"""
    # This inputhook can be called before the NSApplication is ready to run.
    # The hack below waits for a while before actually trying to use it.
    global counter
    NSApp = _NSApp()
    if counter < 50:
        return
    # This call would register the callback on stdin.
    # _stop_on_read(0)
    # But instead we register the callback on a pipe in the InputHookContext
    # object that we were passed.  Using the pipe allows the inputhook
    # to be called by other threads, such as an asynchronous autocompleter.
    # See prompt_toolkit/eventloop/inputhook.py
    _stop_on_read(context.fileno())
    objc.objc_msgSend.argtypes = [void_p, void_p]
    msg(NSApp, n('run'))
    # A previous version of this eventloop would call
    # CoreFoundation.CFRunLoopRun() if the callback had not been run
    # since the last call to this inputhook, assuming that meant
    # that the last window in the gui had been closed.  In fact, this
    # input hook gets called every second when the gui has no windows,
    # and the callback does not get run in between.  The result is
    # a hang when %gui osx is run.
