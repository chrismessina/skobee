// SkobeeAim.cpp : Implementation of CSkobeeAim

#include "stdafx.h"
#include "SkobeeAim.h"


// CSkobeeAim

STDMETHODIMP CSkobeeAim::Init(IAccSession * session, IAccPluginInfo * pluginInfo)
{
	m_spiSession = session;

    m_spTimer.Attach(CTimer::Create());
    m_spTimer->SetCallback(this);
    m_spTimer->Start(m_pollInterval);

#ifdef ADD_CMD_TO_MENU
    CComPtr <IAccCommand> spiLoadCommand;
    pluginInfo->AddCommand(kSetSkobeeAwayMsgCommandId, &spiLoadCommand);
    spiLoadCommand->put_Property(AccCommandProp_Text, CComVariant("Set Skobee Away Message"));
#endif // ADD_CMD_TO_MENU

	return S_OK;
}
STDMETHODIMP CSkobeeAim::Shutdown()
{
    if (m_spTimer)
        m_spTimer->Stop();
    m_spTimer.Free();

	m_spiSession = NULL;
	return S_OK;
}


STDMETHODIMP CSkobeeAim::QueryStatus(int command, VARIANT users, VARIANT_BOOL * enabled)
{
    *enabled = (command == AccCommandId_Preferences || command == kSetSkobeeAwayMsgCommandId) ?
		VARIANT_TRUE : VARIANT_FALSE;
    return S_OK;
}

STDMETHODIMP CSkobeeAim::Exec(int command, VARIANT users)
{
    if (command == AccCommandId_Preferences)
	{
		CString sUsername;
		CString sPass;
		GetSkobeePref(_T("username"), &sUsername);
		GetSkobeePref(_T("password"), &sPass);
		int iShowPlans = FALSE;
		HRESULT hrGetShowPlans = GetSkobeePref(_T("show_plans"), &iShowPlans);
		//MES- If we weren't able to get the setting, default to TRUE
		if (S_OK != hrGetShowPlans)
			iShowPlans = TRUE;


		CSkobeeAimSettingsDlg dlg;
		dlg.m_sUsername = sUsername;
		dlg.m_sPassword = sPass;
		dlg.m_bDisplaySkobeePlans = false;
		if (iShowPlans)
			dlg.m_bDisplaySkobeePlans = true;

		if (IDOK == dlg.DoModal())
		{
			if (FAILED(SetSkobeePref(_T("username"), dlg.m_sUsername)))
				return E_FAIL;
			if (FAILED(SetSkobeePref(_T("password"), dlg.m_sPassword)))
				return E_FAIL;

			iShowPlans = dlg.m_bDisplaySkobeePlans;
			if (FAILED(SetSkobeePref(_T("show_plans"), iShowPlans)))
				return E_FAIL;

		}
	}
    else if (command == kSetSkobeeAwayMsgCommandId) 
	{
		SetAwayFromSkobee();
	}
    return S_OK;
}


//MES- Copied from the LWAway sample from the JAMS project

// When the timer fires, check to see if the workstation is locked, and if so,
// enter away state by setting the away message.
void CSkobeeAim::OnTimer(CTimer*)
{
    bool locked = true;
    // try to get "normal" desktop
    HDESK hDesk = OpenInputDesktop(0, FALSE, 0);
    if (hDesk)
    {   
        TCHAR buf[256];
        GetUserObjectInformation(hDesk, UOI_NAME, buf, _countof(buf), NULL);
        locked = (_tcscmp(buf, _T("Winlogon")) == 0);
        CloseDesktop(hDesk);            
    }

    bool away = false;
    CComVariant vAwayMsg;
    m_spiSession->get_Property(AccSessionProp_AwayMessage, &vAwayMsg);
    if (vAwayMsg.vt == VT_DISPATCH && vAwayMsg.pdispVal)
        away = true;

    if (locked && !away)                   
    {
        if (SUCCEEDED(SetAwayFromSkobee()))
		{
            m_weTriggeredAway = true;
			m_dwLastUpdatedTickCt = GetTickCount();
		}
    }
    else if (!locked && away && m_weTriggeredAway)
    {
        m_spiSession->put_Property(AccSessionProp_AwayMessage,
            CComVariant());        
        m_weTriggeredAway = false;
    }
	else if (locked && away && m_weTriggeredAway)
	{
		//MES- We set the away message, do we need to set it again?
		if( GetTickCount() - m_dwLastUpdatedTickCt >= UPDATE_MSG_MS )
		{
			SetAwayFromSkobee();
			//MES- NOTE: Reset the tick count EVEN IF the set was
			//	unsuccessful (e.g. because the settings aren't there, OR
			//	because we can't get to Skobee.com.)  We still want to wait
			//	a bit before trying again.
			m_dwLastUpdatedTickCt = GetTickCount();
		}
	}
}    


HRESULT CSkobeeAim::SetAwayFromSkobee()
{
	//MES- Are we supposed to set this stuff (according to the prefs)?
	//	OR, is there NOT a pref, in which case we'll assume NOT.
	int iShowPlans = FALSE;
	HRESULT hrGetShowPlans = GetSkobeePref(_T("show_plans"), &iShowPlans);
	if (S_OK != hrGetShowPlans || !iShowPlans)
		return S_OK;

	//MES- Figure out which URL we want to go to
	CString sSkobeeUserName;
	if (FAILED(GetSkobeePref(_T("username"), &sSkobeeUserName)))
		return E_FAIL;

	CString sURL;
	sURL.Format(_T("http://www.skobee.com/feeds/plans/%s"), sSkobeeUserName);

	CString sSkobeePass;
	if (FAILED(GetSkobeePref(_T("password"), &sSkobeePass)))
		return E_FAIL;

	//MES- Get the DOM document
	IXMLDOMDocumentPtr spIDOM;
	if (FAILED(GetDOMForURL(sURL, sSkobeeUserName, sSkobeePass, &spIDOM)))
		return E_FAIL;

	//MES- Get a description based on the DOM
	CString sDesc;
	if (FAILED(GetPlansDescFromSkobeeDOM(spIDOM, &sDesc)))
		return E_FAIL;

	//MES- Set the away message to the string
	m_spiSession->put_Property(AccSessionProp_AwayMessage, CComVariant((LPCTSTR)sDesc));

	return S_OK;
}

HRESULT CSkobeeAim::GetPlansDescFromSkobeeDOM(IXMLDOMDocumentPtr spIDOM, CString* psRes)
{
	IXMLDOMNodeListPtr spINodeList;
	HRESULT hrItems = spIDOM->getElementsByTagName(_T("item"), &spINodeList);
	if (FAILED(hrItems)) return hrItems;

	//MES- Get the item nodes
	HRESULT hrNextNode = S_OK;
	CStringArray saLinks;
	CStringArray saTitles;
	while (S_OK == hrNextNode)
	{
		IXMLDOMNodePtr spIItem;
		hrNextNode = spINodeList->nextNode(&spIItem);
		if (S_OK == hrNextNode)
		{
			//MES- Get the children of the item
			IXMLDOMNodeListPtr spIChildren;
			HRESULT hrChildren = spIItem->get_childNodes(&spIChildren);
			if (FAILED(hrChildren)) return hrChildren;
			
			CString sLink;
			CString sTitle;
			HRESULT hrNextChild = S_OK;
			//MES- Run through the children of the node, getting things like the link and the title
			while (S_OK == hrNextChild)
			{
				IXMLDOMNodePtr spIChildItem;
				hrNextChild = spIChildren->nextNode(&spIChildItem);
				if (S_OK == hrNextChild)
				{
					BSTR bstrName;
					HRESULT hrNodeName = spIChildItem->get_nodeName(&bstrName);
					if (FAILED(hrNodeName)) return hrNodeName;
					BSTR bstrText;
					HRESULT hrNodeText = spIChildItem->get_text(&bstrText);
					if (FAILED(hrNodeText)) return hrNodeText;

					if (0 == _tcscmp(_T("link"), bstrName))
						sLink = (LPCTSTR)(_bstr_t)bstrText;
					else if (0 == _tcscmp(_T("title"), bstrName))
						sTitle = (LPCTSTR)(_bstr_t)bstrText;
					::SysFreeString( bstrName );
					::SysFreeString( bstrText );
				}
			}
			saLinks.Add(sLink);
			saTitles.Add(sTitle);
		}
	}

	*psRes = MakeDescForPlans(saTitles, saLinks);

	return S_OK;
}

CString CSkobeeAim::MakeDescForPlans(CStringArray& saTitles, CStringArray& saLinks)
{
	CString sResult = _T("");
	if (0 < saLinks.GetCount())
	{
		for (int i = 0; i < saLinks.GetCount(); ++i)
		{
			CString sItem;
			//sItem.Format(_T("<a href='%s'>%s</a><br/>\r\n"), saLinks.GetAt(i), saTitles.GetAt(i));
			sItem.Format(_T("%s<br/>\r\n"), saTitles.GetAt(i));
			sResult += sItem;
		}
	}

	return sResult;
}

HRESULT CSkobeeAim::GetSkobeePref(CString sPrefName, CString* pstrRes)
{
	_variant_t varRes;
	HRESULT hr = GetSkobeePref(sPrefName, &varRes);
	if (FAILED(hr))
		return hr;

	//MES- Turn it into a string and return it
	*pstrRes = (LPCTSTR)(_bstr_t)varRes;

	return S_OK;
}

HRESULT CSkobeeAim::GetSkobeePref(CString sPrefName, int* piRes)
{
	_variant_t varRes;
	HRESULT hr = GetSkobeePref(sPrefName, &varRes);
	if (FAILED(hr))
		return hr;

	//MES- Turn it into an int and return it
	*piRes = (int)varRes;

	return S_OK;
}

HRESULT CSkobeeAim::GetSkobeePref(CString sPrefName, _variant_t* pvarRes)
{
	//MES- Get a pointer to the prefs
	CComPtr<IAccPreferences> spiPrefs;
	if (FAILED(m_spiSession->get_Prefs(&spiPrefs)))
		return E_FAIL;

	//MES- Read the pref we care about
	if (FAILED(spiPrefs->GetValue((BSTR)(_bstr_t)(LPCTSTR)GetFullSkobeePrefname(sPrefName), pvarRes)))
		return E_FAIL;

	return S_OK;
}

HRESULT CSkobeeAim::SetSkobeePref(CString sPrefName, CString sValue)
{
	_variant_t varValue = sValue;
	return SetSkobeePref(sPrefName, varValue);
}

HRESULT CSkobeeAim::SetSkobeePref(CString sPrefName, int iValue)
{
	_variant_t varValue = iValue;
	return SetSkobeePref(sPrefName, varValue);
}

HRESULT CSkobeeAim::SetSkobeePref(CString sPrefName, _variant_t varValue)
{
	//MES- Get a pointer to the prefs
	CComPtr<IAccPreferences> spiPrefs;
	if (FAILED(m_spiSession->get_Prefs(&spiPrefs)))
		return E_FAIL;

	//MES- Set the value
	if (FAILED(spiPrefs->SetValue((BSTR)(_bstr_t)(LPCTSTR)GetFullSkobeePrefname(sPrefName), varValue)))
		return E_FAIL;

	//MES- OK, good
	return S_OK;
}

CString CSkobeeAim::GetFullSkobeePrefname(CString sSuffix)
{
	CString sRes;
	sRes.Format(_T("skobee.prefs.%s"), sSuffix);
	return sRes;
}

HRESULT CSkobeeAim::GetDOMForURL(CString sURL, CString sUser, CString sPass, IXMLDOMDocument** ppIDOM)
{
	//MES- Make an XMLHttpRequest object
	IXMLHttpRequestPtr pXMLHttpReq=NULL;
	HRESULT hr = pXMLHttpReq.CreateInstance(__uuidof(XMLHTTPRequest));
	_variant_t varAsync = VARIANT_FALSE;
	_variant_t varUser = (LPCTSTR)sUser;
	_variant_t varPass = (LPCTSTR)sPass;
	if (FAILED(pXMLHttpReq->open(_T("GET"), (BSTR)(_bstr_t)sURL, varAsync, varUser, varPass)))
		return E_FAIL;

	//MES- Send a blank body
	_variant_t varBody;
	if (FAILED(pXMLHttpReq->send(varBody)))
		return E_FAIL;

	long lStatus = 0;
	if (FAILED(pXMLHttpReq->get_status(&lStatus)))
		return E_FAIL;

	if (lStatus >= 500)
		return E_FAIL;

	IDispatchPtr spIDisp;
	if (FAILED(pXMLHttpReq->get_responseXML(&spIDisp)))
		return E_FAIL;

	//MES- Copy the result to our output
	spIDisp->QueryInterface(__uuidof(IXMLDOMDocument), (void**)ppIDOM);

	return S_OK;
}
