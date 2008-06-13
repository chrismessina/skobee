///----------------------------------------------------------------------------
///
/// File Name: Timer.cpp
/// Copyright (c) 2005 America Online, Inc.  All rights reserved.
///
///----------------------------------------------------------------------------

#include "stdafx.h"
#include "Timer.h"

CAtlMap<UINT, CTimer*> CTimer::s_map;

CTimer* CTimer::Create()
{
    CTimer* p = new CTimer();
    if (!p)
    {
        delete p;
        p = NULL;
    }
    return p;    
}

CTimer::CTimer() : m_timer(0), m_pCallback(NULL)
{        
}

/*
HRESULT CTimer::Init()
{
}
*/

void CTimer::SetCallback(CTimerCallback* p)
{
    m_pCallback = p;
}

HRESULT CTimer::Start(int timeout)
{
    if (m_timer)
        return E_UNEXPECTED;

    m_timer = (UINT)SetTimer(NULL, 0, timeout, TimerProc);
    if (!m_timer)
        return E_FAIL;

    s_map.SetAt(m_timer, this);
    return S_OK;
}

HRESULT CTimer::Stop()
{
    if (m_timer)
    {
        s_map.RemoveKey(m_timer);
        KillTimer(NULL, m_timer);    
        m_timer = 0;
    }
    return S_OK;
}

void CTimer::OnTimer(CTimer*)
{
    if (m_pCallback)
        m_pCallback->OnTimer(this);
}

void CALLBACK CTimer::TimerProc(HWND, UINT, UINT_PTR id, DWORD)
{   
    CTimer* p;
    if (s_map.Lookup((UINT)id, p))
        p->OnTimer(p);
}
