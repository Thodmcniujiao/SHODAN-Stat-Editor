// Steam %command% bridge; based on 127MU/SHODAN-Stat-Editor's GPL-3.0 bridge.
// No injection, system proxy, game flags, or Steam configuration writes.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <winsock2.h>
#include <windows.h>
#include <shellapi.h>
#include <wincrypt.h>
#include <string>
#include <vector>

static unsigned long long created(HANDLE h){FILETIME a{},b{},c{},d{};return GetProcessTimes(h,&a,&b,&c,&d)?(static_cast<unsigned long long>(a.dwHighDateTime)<<32)|a.dwLowDateTime:0;}
static bool trusted(const wchar_t* hash){
 if(wcslen(hash)!=40)return false;BYTE bytes[20]{};
 for(int n=0;n<20;n++){wchar_t pair[3]{hash[n*2],hash[n*2+1],0};wchar_t* end=nullptr;unsigned long value=wcstoul(pair,&end,16);if(!end||*end)return false;bytes[n]=static_cast<BYTE>(value);}
 HCERTSTORE store=CertOpenStore(CERT_STORE_PROV_SYSTEM_W,0,0,CERT_SYSTEM_STORE_CURRENT_USER|CERT_STORE_OPEN_EXISTING_FLAG,L"ROOT");
 if(!store)return false;CRYPT_HASH_BLOB blob{20,bytes};auto cert=CertFindCertificateInStore(store,X509_ASN_ENCODING,0,CERT_FIND_SHA1_HASH,&blob,nullptr);
 bool found=cert!=nullptr;if(cert)CertFreeCertificateContext(cert);CertCloseStore(store,0);return found;
}
static std::wstring env(const wchar_t* name){DWORD n=GetEnvironmentVariableW(name,nullptr,0);if(!n)return{};std::vector<wchar_t> b(n);GetEnvironmentVariableW(name,b.data(),n);return b.data();}
int WINAPI wWinMain(HINSTANCE,HINSTANCE,PWSTR,int){
 int argc=0;auto argv=CommandLineToArgvW(GetCommandLineW(),&argc);
 if(!argv||argc<2){if(argv)LocalFree(argv);MessageBoxW(nullptr,L"请将编辑器生成的桥接启动选项填入 Steam 游戏属性。",L"SHODAN Steam Bridge",MB_OK);return 2;}
 std::wstring game=argv[1];LocalFree(argv);
 const wchar_t* tail=GetCommandLineW();while(*tail==L' '||*tail==L'\t')++tail;
 if(*tail==L'"'){++tail;while(*tail&&*tail!=L'"')++tail;if(*tail)++tail;}else while(*tail&&*tail!=L' '&&*tail!=L'\t')++tail;
 while(*tail==L' '||*tail==L'\t')++tail;std::wstring command=tail;
 wchar_t own[32768]{};GetModuleFileNameW(nullptr,own,32768);std::wstring root=own;
 for(int n=0;n<3;n++)root.resize(root.find_last_of(L"\\/"));
 std::wstring ini=root+L"\\Data\\WarProxy\\steam-proxy.ini";
 int ready=GetPrivateProfileIntW(L"proxy",L"ready",0,ini.c_str()),port=GetPrivateProfileIntW(L"proxy",L"port",0,ini.c_str());
 DWORD pid=GetPrivateProfileIntW(L"proxy",L"pid",0,ini.c_str());
 wchar_t start[32]{},updated[32]{},thumb[64]{};
 GetPrivateProfileStringW(L"proxy",L"started",L"0",start,32,ini.c_str());
 GetPrivateProfileStringW(L"proxy",L"updated",L"0",updated,32,ini.c_str());
 GetPrivateProfileStringW(L"proxy",L"certificate_sha1",L"",thumb,64,ini.c_str());
 FILETIME ft{};GetSystemTimeAsFileTime(&ft);auto ticks=(static_cast<unsigned long long>(ft.dwHighDateTime)<<32)|ft.dwLowDateTime;
 double now=static_cast<double>(ticks-116444736000000000ULL)/10000000.0,stamp=_wtof(updated);
 HANDLE proxy=pid?OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION|SYNCHRONIZE,FALSE,pid):nullptr;
 bool active=ready&&port>1023&&port<65536&&proxy&&WaitForSingleObject(proxy,0)==WAIT_TIMEOUT&&created(proxy)==_wcstoui64(start,nullptr,10)&&now-stamp<8&&stamp<=now+5&&trusted(thumb);
 if(active){wchar_t image[32768]{};DWORD size=32768;auto expected=root+L"\\app\\network\\mitmdump.exe";active=QueryFullProcessImageNameW(proxy,0,image,&size)&&_wcsicmp(image,expected.c_str())==0;}
 if(proxy)CloseHandle(proxy);
 if(active){
  std::wstring address=L"http://127.0.0.1:"+std::to_wstring(port);
  for(auto key:{L"HTTP_PROXY",L"HTTPS_PROXY",L"http_proxy",L"https_proxy"})SetEnvironmentVariableW(key,address.c_str());
  auto bypass=env(L"NO_PROXY");if(!bypass.empty())bypass+=L",";
  bypass+=L"localhost,127.0.0.1,::1,playfabapi.com,.playfabapi.com,playfab.com,.playfab.com,easyanticheat.net,.easyanticheat.net,easyanticheat.com,.easyanticheat.com,epicgames.com,.epicgames.com,epicgames.dev,.epicgames.dev";
  SetEnvironmentVariableW(L"NO_PROXY",bypass.c_str());SetEnvironmentVariableW(L"no_proxy",bypass.c_str());
 }
 std::vector<wchar_t> text(command.begin(),command.end());text.push_back(0);STARTUPINFOW si{};si.cb=sizeof(si);PROCESS_INFORMATION pi{};
 if(!CreateProcessW(game.c_str(),text.data(),nullptr,nullptr,FALSE,0,nullptr,nullptr,&si,&pi))return static_cast<int>(GetLastError());
 CloseHandle(pi.hThread);WaitForSingleObject(pi.hProcess,INFINITE);DWORD code=1;GetExitCodeProcess(pi.hProcess,&code);CloseHandle(pi.hProcess);return static_cast<int>(code);
}
