// skobee_aim.cpp : Implementation of DLL Exports.


#include "stdafx.h"
#include "resource.h"
#include "skobee_aim.h"


class Cskobee_aimModule : public CAtlDllModuleT< Cskobee_aimModule >
{
public :
	DECLARE_LIBID(LIBID_skobee_aimLib)
	DECLARE_REGISTRY_APPID_RESOURCEID(IDR_SKOBEE_AIM, "{968FD5D3-CADA-41AF-A24B-DAE244103900}")
};

Cskobee_aimModule _AtlModule;

class Cskobee_aimApp : public CWinApp
{
public:

// Overrides
    virtual BOOL InitInstance();
    virtual int ExitInstance();

    DECLARE_MESSAGE_MAP()
};

BEGIN_MESSAGE_MAP(Cskobee_aimApp, CWinApp)
END_MESSAGE_MAP()

Cskobee_aimApp theApp;

BOOL Cskobee_aimApp::InitInstance()
{
    return CWinApp::InitInstance();
}

int Cskobee_aimApp::ExitInstance()
{
    return CWinApp::ExitInstance();
}


// Used to determine whether the DLL can be unloaded by OLE
STDAPI DllCanUnloadNow(void)
{
    AFX_MANAGE_STATE(AfxGetStaticModuleState());
    return (AfxDllCanUnloadNow()==S_OK && _AtlModule.GetLockCount()==0) ? S_OK : S_FALSE;
}


// Returns a class factory to create an object of the requested type
STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, LPVOID* ppv)
{
    return _AtlModule.DllGetClassObject(rclsid, riid, ppv);
}


// DllRegisterServer - Adds entries to the system registry
STDAPI DllRegisterServer(void)
{
    // registers object, typelib and all interfaces in typelib
    HRESULT hr = _AtlModule.DllRegisterServer();
	return hr;
}


// DllUnregisterServer - Removes entries from the system registry
STDAPI DllUnregisterServer(void)
{
	HRESULT hr = _AtlModule.DllUnregisterServer();
	return hr;
}

