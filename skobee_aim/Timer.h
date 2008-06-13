///----------------------------------------------------------------------------
///
/// File Name: Timer.h
/// Copyright (c) 2005 America Online, Inc.  All rights reserved.
///
///----------------------------------------------------------------------------

#pragma once
#include "atlcoll.h"

class CTimer;
class CTimerCallback
{
public:
    virtual void OnTimer(CTimer*) = 0;
};

class CTimer
{
public:
    static CTimer* Create();    
    void SetCallback(CTimerCallback*);
    HRESULT Start(int timeout);
    HRESULT Stop();
private:
    CTimer();    
    void OnTimer(CTimer*);
    static void CALLBACK TimerProc(HWND, UINT, UINT_PTR, DWORD);
private:
    UINT m_timer;
    CTimerCallback* m_pCallback;
    static CAtlMap<UINT, CTimer*> s_map;        
};