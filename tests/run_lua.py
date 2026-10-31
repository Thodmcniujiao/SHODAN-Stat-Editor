"""Run the project's LuaJIT tests using its own runtime DLL, without opening the editor."""
import argparse
import ctypes
import os
from pathlib import Path

def quote(s):
    return '"' + str(s).replace('\\', '/').replace('"', '\\"') + '"'

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('script',type=Path)
    ap.add_argument('--fixtures',type=Path)
    ap.add_argument('--game',type=Path)
    ap.add_argument('--work',type=Path)
    ap.add_argument('--isolated-profile',action='store_true')
    args=ap.parse_args()
    root=Path(__file__).resolve().parents[1]
    if args.isolated_profile:
        if not args.work:raise SystemExit('--isolated-profile requires --work')
        os.environ['LOCALAPPDATA']=str(args.work.resolve()/'profile-root')
        (args.work.resolve()/'program'/'Data').mkdir(parents=True, exist_ok=True)
    runtime=root/'offline/runtime'
    dll_path=runtime/'lua51.dll'
    if not dll_path.exists():
        raise SystemExit('Put the release LuaJIT runtime in offline/runtime first.')
    with os.add_dll_directory(str(runtime)):
        dll=ctypes.CDLL(str(dll_path))
        dll.luaL_newstate.restype=ctypes.c_void_p
        dll.luaL_openlibs.argtypes=[ctypes.c_void_p]
        dll.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
        dll.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
        dll.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
        dll.lua_tolstring.restype=ctypes.c_void_p
        dll.lua_close.argtypes=[ctypes.c_void_p]
        state=dll.luaL_newstate()
        try:
            dll.luaL_openlibs(state)
            source='package.path='+quote(root/'offline/?.lua')+'..";"..'+quote(root/'tests/?.lua')+'..";"..package.path\n'
            source+='TEST_PRESETS_HELPER=require("named_preset_helpers")\n'
            source+='TEST_ROOT='+quote(root)+'\n'
            if args.fixtures:source+='TEST_FIXTURES='+quote(args.fixtures)+'\n'
            if args.game:source+='TEST_GAME='+quote(args.game)+'\n'
            if args.work:source+='TEST_WORK='+quote(args.work.resolve())+'\n'
            if args.isolated_profile:
                source+='SHODAN_DATA_DIRECTORY='+quote(args.work.resolve()/'program'/'Data')+'\n'
                source+='SHODAN_PRESET_DIRECTORY='+quote(args.work.resolve()/'program'/'Presets')+'\n'
            source+='assert(loadfile('+quote(args.script.resolve())+'))()\n'
            status=dll.luaL_loadstring(state,source.encode('utf-8'))
            if status==0:status=dll.lua_pcall(state,0,0,0)
            if status:
                size=ctypes.c_size_t()
                p=dll.lua_tolstring(state,-1,ctypes.byref(size))
                raise SystemExit(ctypes.string_at(p,size.value).decode('utf-8',errors='replace'))
        finally:dll.lua_close(state)

if __name__=='__main__':main()
