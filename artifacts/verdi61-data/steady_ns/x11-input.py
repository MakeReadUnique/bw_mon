import ctypes,time,sys
x=ctypes.CDLL('libX11.so.6');t=ctypes.CDLL('libXtst.so.6')
x.XOpenDisplay.argtypes=[ctypes.c_char_p];x.XOpenDisplay.restype=ctypes.c_void_p
x.XSync.argtypes=[ctypes.c_void_p,ctypes.c_int]
x.XKeysymToKeycode.argtypes=[ctypes.c_void_p,ctypes.c_ulong];x.XKeysymToKeycode.restype=ctypes.c_uint
x.XStringToKeysym.argtypes=[ctypes.c_char_p];x.XStringToKeysym.restype=ctypes.c_ulong
for name,args in [('XTestFakeMotionEvent',[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ulong]),('XTestFakeButtonEvent',[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]),('XTestFakeKeyEvent',[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong])]:
 getattr(t,name).argtypes=args
D=x.XOpenDisplay(b':87');assert D

def move(a,b):
 t.XTestFakeMotionEvent(D,0,int(a),int(b),0);x.XSync(D,0);time.sleep(.12)
def button(n,v):
 t.XTestFakeButtonEvent(D,n,v,0);x.XSync(D,0);time.sleep(.12)
def click(a,b):
 move(a,b);button(1,1);button(1,0)
def key(name):
 code=x.XKeysymToKeycode(D,x.XStringToKeysym(name.encode()))
 t.XTestFakeKeyEvent(D,code,1,0);t.XTestFakeKeyEvent(D,code,0,0);x.XSync(D,0);time.sleep(.1)
if sys.argv[1]=='click':click(*sys.argv[2:])
elif sys.argv[1]=='drag':
 a,b,c,d=map(int,sys.argv[2:]);move(a,b);button(1,1)
 for i in range(1,11):move(a+(c-a)*i/10,b+(d-b)*i/10)
 button(1,0)
elif sys.argv[1]=='key':key(sys.argv[2])
