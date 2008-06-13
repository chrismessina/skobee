// SkobeeAim.h : Declaration of the CSkobeeAim

#pragma once
#include "resource.h"       // main symbols
#include "Timer.h"

#include "skobee_aim.h"
#include "AccSupport.h"
#include "SkobeeAimSettingsDlg.h"


#if defined(_WIN32_WCE) && !defined(_CE_DCOM) && !defined(_CE_ALLOW_SINGLE_THREADED_OBJECTS_IN_MTA)
#error "Single-threaded COM objects are not properly supported on Windows CE platform, such as the Windows Mobile platforms that do not include full DCOM support. Define _CE_ALLOW_SINGLE_THREADED_OBJECTS_IN_MTA to force ATL to support creating single-thread COM object's and allow use of it's single-threaded COM object implementations. The threading model in your rgs file was set to 'Free' as that is the only threading model supported in non DCOM Windows CE platforms."
#endif


_COM_SMARTPTR_TYPEDEF(IAccPreferences, __uuidof(IAccPreferences));
_COM_SMARTPTR_TYPEDEF(IAccIm, __uuidof(IAccIm));

//MES- Once we've set the away message, refresh it every 10 minutes (10 * 60 * 1000 milliseconds)
#define UPDATE_MSG_MS 600000

//MES- Define this to add a command to the Action menu to test the plug-in
//#define ADD_CMD_TO_MENU


// CSkobeeAim

class ATL_NO_VTABLE CSkobeeAim :
	public CComObjectRootEx<CComSingleThreadModel>,
	public CComCoClass<CSkobeeAim, &CLSID_SkobeeAim>,
	public IDispatchImpl<ISkobeeAim, &IID_ISkobeeAim, &LIBID_skobee_aimLib, /*wMajor =*/ 1, /*wMinor =*/ 0>,
	public IAccPlugin,
	public IAccCommandTarget,
    public CTimerCallback
{
public:
	CSkobeeAim() : m_weTriggeredAway(false), m_pollInterval(5000)
	{
	}

	//DECLARE_REGISTRY_RESOURCEID(IDR_SKOBEEAIM)


	BEGIN_COM_MAP(CSkobeeAim)
		COM_INTERFACE_ENTRY(ISkobeeAim)
		COM_INTERFACE_ENTRY(IAccPlugin)
		COM_INTERFACE_ENTRY(IAccCommandTarget)
	END_COM_MAP()



	DECLARE_PROTECT_FINAL_CONSTRUCT()
	ACC_DECLARE_REGISTRY("SkobeeAIM", "Skobee AIM Plug In", "Displays your Skobee plans in your Away message when your computer is locked", "", "", "")


    static const int kSetSkobeeAwayMsgCommandId = 0;

	HRESULT FinalConstruct()
	{
		return S_OK;
	}

	void FinalRelease()
	{
	}


	// IAccPlugin Methods
public:
	STDMETHOD(Init)(IAccSession * session, IAccPluginInfo * pluginInfo);
	STDMETHOD(Shutdown)();

	// IAccCommandTarget Methods
public:
	STDMETHOD(QueryStatus)(int command, VARIANT users, VARIANT_BOOL * enabled);
	STDMETHOD(Exec)(int command, VARIANT users);

private:

	HRESULT SetAwayFromSkobee();
	HRESULT GetPlansDescFromSkobeeDOM(IXMLDOMDocumentPtr spIDOM, CString* psRes);
	CString MakeDescForPlans(CStringArray& saTitles, CStringArray& saLinks);
	HRESULT GetSkobeePref(CString sPrefName, CString* pstrRes);
	HRESULT GetSkobeePref(CString sPrefName, int* piRes);
	HRESULT GetSkobeePref(CString sPrefName, _variant_t* pvarRes);
	HRESULT SetSkobeePref(CString sPrefName, CString sValue);
	HRESULT SetSkobeePref(CString sPrefName, int iValue);
	HRESULT SetSkobeePref(CString sPrefName, _variant_t varValue);
	CString GetFullSkobeePrefname(CString sSuffix);
	HRESULT GetDOMForURL(CString sURL, CString sUser, CString sPass, IXMLDOMDocument** ppIDOM);

	CComPtr<IAccSession> m_spiSession;
	DWORD m_dwCookie;
	DWORD m_dwLastUpdatedTickCt;

	//MES- Stuff copied from the LWAway sample from the JAMS project
	void OnTimer(CTimer*);
    bool m_weTriggeredAway;
    int m_pollInterval;
    CAutoPtr<CTimer> m_spTimer;
};

OBJECT_ENTRY_AUTO(__uuidof(SkobeeAim), CSkobeeAim)
