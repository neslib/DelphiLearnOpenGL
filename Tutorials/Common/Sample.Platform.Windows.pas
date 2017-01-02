unit Sample.Platform.Windows;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  Winapi.Windows,
  Sample.Platform;

type
  { Implements Windows-specific functionality. }
  TPlatformWindows = class(TPlatformBase)
  {$REGION 'Internal Declarations'}
  private const
    WINDOW_CLASS_NAME = 'SampleWindow';
  private class var
    FWindow: HWND;
    FWindowDC: HDC;
    FContext: HGLRC;
    FInitialized: Boolean;
  private
    class procedure RegisterWindowClass; static;
    class procedure SetupWindow; static;
    class procedure SetupOpenGLContext; static;
    class procedure RunLoop; static;
    class procedure Shutdown; static;
  private
    class function GetKeyShiftState(const ALParam: Integer): TShiftState; static;
    class function GetMouseShiftState(const AWParam: Integer): TShiftState; static;
    class procedure MouseCapture(const AWnd: HWND; const ACapture: Boolean); static;
    class function GetPointFromLParam(const ALParam: LPARAM): TPoint; static;
  private
    class function WndProc(Wnd: HWND; Msg: UINT; WParam: WPARAM;
      LParam: LPARAM): LRESULT; stdcall; static;
  {$ENDREGION 'Internal Declarations'}
  protected
    class procedure DoRun; override;
  end;

implementation

uses
  System.Types,
  System.UITypes,
  System.SysUtils,
  Winapi.OpenGLExt,
  Winapi.Messages;

{ TPlatformWindows }

class procedure TPlatformWindows.DoRun;
{ Main entry point on Windows }
begin
  { Register and create main window and initialize the app }
  FInitialized := False;
  RegisterWindowClass;
  SetupWindow;
  App.Initialize;
  FInitialized := True;

  { Run and update until terminated }
  RunLoop;

  { Cleanup }
  App.Shutdown;
  Shutdown;
end;

class function TPlatformWindows.GetPointFromLParam(
  const ALParam: LPARAM): TPoint;
begin
  { Extracts the X and Y coordinates from a Windows message }
  Result.X := Int16(ALParam and $FFFF);
  Result.Y := Int16(ALParam shr 16);
end;

class function TPlatformWindows.GetKeyShiftState(
  const ALParam: Integer): TShiftState;
const
  ALT_MASK = $20000000;
begin
  Result := [];
  if (GetKeyState(VK_SHIFT) < 0) then
    Include(Result, ssShift);
  if (GetKeyState(VK_CONTROL) < 0) then
    Include(Result, ssCtrl);
  if (ALParam and ALT_MASK <> 0) then
    Include(Result, ssAlt);
end;

class function TPlatformWindows.GetMouseShiftState(
  const AWParam: Integer): TShiftState;
begin
  Result := [];
  if ((AWParam and MK_CONTROL) <> 0) then
    Include(Result, ssCtrl);
  if ((AWParam and MK_SHIFT) <> 0) then
    Include(Result, ssShift);
end;

class procedure TPlatformWindows.MouseCapture(const AWnd: HWND;
  const ACapture: Boolean);
begin
  if (ACapture) then
    SetCapture(AWnd)
  else
    ReleaseCapture;
end;

class procedure TPlatformWindows.RegisterWindowClass;
var
  WindowClass: TWndClassEx;
begin
  { Before we can create a window, we need to register a window class that
    defines the behavior of all instances of this window class.

    The most important field here is lpfnWndProc, which handles all Windows
    messages for windows of this class. We point it to our WndProc method. }

  FillChar(WindowClass, SizeOf(WindowClass), 0);
  WindowClass.cbSize := SizeOf(WindowClass);
  WindowClass.style := CS_HREDRAW or CS_VREDRAW;
  WindowClass.lpfnWndProc := @WndProc;
  WindowClass.hInstance := HInstance;
  WindowClass.hIcon := LoadIcon(0, IDI_APPLICATION);
  WindowClass.hIconSm := LoadIcon(0, IDI_APPLICATION);
  WindowClass.hCursor := LoadCursor(0, IDC_ARROW);
  WindowClass.lpszClassName := WINDOW_CLASS_NAME;
  RegisterClassEx(WindowClass);
end;

class procedure TPlatformWindows.RunLoop;
var
  Msg: TMsg;
begin
  { Run the Windows message pump }
  StartClock;
  while (not Terminated) do
  begin
    while (PeekMessage(Msg, 0, 0, 0, PM_REMOVE)) do
    begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;

    { Update app and render frame to back buffer }
    Update;

    { Swap backbuffer to front to display it }
    SwapBuffers(FWindowDC);
  end;
end;

class procedure TPlatformWindows.SetupOpenGLContext;
var
  PFD: TPixelFormatDescriptor;
  PixelFormat: Integer;
begin
  FillChar(PFD, SizeOf(PFD), 0);
  PFD.nSize := SizeOf(PFD);
  PFD.nVersion := 1;
  PFD.dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
  PFD.iPixelType := PFD_TYPE_RGBA;
  PFD.cColorBits := 24;
  PFD.cAlphaBits := 0; // 8;
  PFD.cDepthBits := 16;
  if (TPlatformWindows.App.NeedStencilBuffer) then
    PFD.cStencilBits := 8;
  PFD.iLayerType := PFD_MAIN_PLANE;
  PixelFormat := ChoosePixelFormat(FWindowDC, @PFD);
  SetPixelFormat(FWindowDC, PixelFormat, @PFD);

  FContext := wglCreateContext(FWindowDC);
  if (FContext = 0) then
    raise Exception.Create('Unable to create OpenGL context');

  if (not wglMakeCurrent(FWindowDC, FContext)) then
    raise Exception.Create('Unable to activate OpenGL context');

  InitOpenGLext; // Must be called after wglMakeCurrent
end;

class procedure TPlatformWindows.SetupWindow;
const
  STYLE = WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX;
  STYLE_EX = WS_EX_APPWINDOW or WS_EX_WINDOWEDGE;
var
  R: TRect;
  ScreenX, ScreenY: Integer;
begin
  { Calculate the actual Window size (including borders) we need so the client
    area of the window equals our specifications. }
  R := Rect(0, 0, App.Width, App.Height);
  AdjustWindowRectEx(R, STYLE, False, STYLE_EX);

  { Create main window and use it to create an OpenGL context }
  FWindow := CreateWindowEx(STYLE_EX, WINDOW_CLASS_NAME, PChar(App.Title),
    STYLE, 0, 0, R.Width, R.Height, 0, 0, HInstance, nil);
  if (FWindow = 0) then
    raise Exception.Create('Unable to create main window');

  FWindowDC := GetDC(FWindow);
  if (FWindowDC = 0) then
    raise Exception.Create('Unable to retrieve device context for main window');
  SetupOpenGLContext;

  { Center the window on the main screen }
  GetWindowRect(FWindow, R);
  ScreenX := (GetSystemMetrics(SM_CXSCREEN) - R.Width) div 2;
  ScreenY := (GetSystemMetrics(SM_CYSCREEN) - R.Height) div 2;
  SetWindowPos(FWindow, FWindow, ScreenX, ScreenY, -1, -1,
    SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);

  { Show the window }
  ShowWindow(FWindow, SW_SHOW);
end;

class procedure TPlatformWindows.Shutdown;
begin
  wglMakeCurrent(0, 0);
  if (FContext <> 0) then
    wglDeleteContext(FContext);

  if (FWindow <> 0) then
  begin
    if (FWindowDC <> 0) then
      ReleaseDC(FWindow, FWindowDC);
    DestroyWindow(FWindow);
  end;
end;

class function TPlatformWindows.WndProc(Wnd: HWND; Msg: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT;
var
  P: TPoint;
begin
  { This method gets called for each message for our window.
    For messages we are interested in, we convert these to cross-platform
    events }
  if (FInitialized) then
  begin
    case Msg of
      WM_QUIT,
      WM_CLOSE:
        Terminated := True;

      WM_MOUSEMOVE:
        begin
          P := GetPointFromLParam(LParam);
          App.MouseMove(GetMouseShiftState(WParam), P.X, P.Y);
        end;

      WM_MOUSEWHEEL:
        App.MouseWheel(GetMouseShiftState(WParam), Int16(WParam shr 16) div WHEEL_DELTA);

      WM_LBUTTONDOWN,
      WM_LBUTTONUP,
      WM_LBUTTONDBLCLK:
        begin
          MouseCapture(Wnd, (Msg = WM_LBUTTONDOWN));
          P := GetPointFromLParam(LParam);
          if (Msg = WM_LBUTTONDOWN) then
            App.MouseDown(TMouseButton.mbLeft, GetMouseShiftState(WParam), P.X, P.Y)
          else
            App.MouseUp(TMouseButton.mbLeft, GetMouseShiftState(WParam), P.X, P.Y);
        end;

      WM_MBUTTONDOWN,
      WM_MBUTTONUP,
      WM_MBUTTONDBLCLK:
        begin
          MouseCapture(Wnd, (Msg = WM_MBUTTONDOWN));
          P := GetPointFromLParam(LParam);
          if (Msg = WM_MBUTTONDOWN) then
            App.MouseDown(TMouseButton.mbMiddle, GetMouseShiftState(WParam), P.X, P.Y)
          else
            App.MouseUp(TMouseButton.mbMiddle, GetMouseShiftState(WParam), P.X, P.Y);
        end;

      WM_RBUTTONDOWN,
      WM_RBUTTONUP,
      WM_RBUTTONDBLCLK:
        begin
          MouseCapture(Wnd, (Msg = WM_RBUTTONDOWN));
          P := GetPointFromLParam(LParam);
          if (Msg = WM_RBUTTONDOWN) then
            App.MouseDown(TMouseButton.mbRight, GetMouseShiftState(WParam), P.X, P.Y)
          else
            App.MouseUp(TMouseButton.mbRight, GetMouseShiftState(WParam), P.X, P.Y);
        end;

      WM_KEYDOWN,
      WM_SYSKEYDOWN:
        App.KeyDown(WParam and $FF, GetKeyShiftState(LParam));

      WM_KEYUP,
      WM_SYSKEYUP:
        App.KeyUp(WParam and $FF, GetKeyShiftState(LParam));
    end;
  end;
  Result := DefWindowProc(Wnd, Msg, WParam, LParam);
end;

end.
