// SkobeeAimSettingsDlg.h : Declaration of the CSkobeeAimSettingsDlg

#pragma once

#include "resource.h"       // main symbols

#include <atlhost.h>


// CSkobeeAimSettingsDlg

class CSkobeeAimSettingsDlg : 
	public CAxDialogImpl<CSkobeeAimSettingsDlg>
{
public:
	CSkobeeAimSettingsDlg()
	{
	}

	~CSkobeeAimSettingsDlg()
	{
	}

	enum { IDD = IDD_SKOBEEAIMSETTINGSDLG };

BEGIN_MSG_MAP(CSkobeeAimSettingsDlg)
	MESSAGE_HANDLER(WM_INITDIALOG, OnInitDialog)
	COMMAND_HANDLER(IDOK, BN_CLICKED, OnClickedOK)
	COMMAND_HANDLER(IDCANCEL, BN_CLICKED, OnClickedCancel)
	CHAIN_MSG_MAP(CAxDialogImpl<CSkobeeAimSettingsDlg>)
END_MSG_MAP()

	CString m_sUsername;
	CString m_sPassword;
	bool m_bDisplaySkobeePlans;

// Handler prototypes:
//  LRESULT MessageHandler(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
//  LRESULT CommandHandler(WORD wNotifyCode, WORD wID, HWND hWndCtl, BOOL& bHandled);
//  LRESULT NotifyHandler(int idCtrl, LPNMHDR pnmh, BOOL& bHandled);

	LRESULT OnInitDialog(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled)
	{
		CAxDialogImpl<CSkobeeAimSettingsDlg>::OnInitDialog(uMsg, wParam, lParam, bHandled);
		SetDlgItemText(IDC_USERNAME, m_sUsername);
		SetDlgItemText(IDC_PASSWORD, m_sPassword);
		::SendMessage(GetDlgItem(IDC_CHK_DISPLAY_SKOBEE), BM_SETCHECK,
			m_bDisplaySkobeePlans ? BST_CHECKED : BST_UNCHECKED, NULL);

		bHandled = TRUE;
		return 1;  // Let the system set the focus
	}

	LRESULT OnClickedOK(WORD wNotifyCode, WORD wID, HWND hWndCtl, BOOL& bHandled)
	{
		GetDlgItemText(IDC_USERNAME, m_sUsername);
		GetDlgItemText(IDC_PASSWORD, m_sPassword);
		int iChecked = (int)::SendMessage(GetDlgItem(IDC_CHK_DISPLAY_SKOBEE), BM_GETCHECK, NULL, NULL);
		m_bDisplaySkobeePlans = false;
		if (iChecked)
			m_bDisplaySkobeePlans = true;

		EndDialog(wID);
		return 0;
	}

	LRESULT OnClickedCancel(WORD wNotifyCode, WORD wID, HWND hWndCtl, BOOL& bHandled)
	{
		EndDialog(wID);
		return 0;
	}
};


